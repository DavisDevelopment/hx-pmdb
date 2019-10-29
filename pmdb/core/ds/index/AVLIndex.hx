package pmdb.core.ds.index;

import pm.AVLTree.BoundingValue;
import pmdb.core.ds.TreeModel.OptTreeModel;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.schema.Types;
import pmdb.core.ds.index.IIndex;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.Itr;
import pmdb.core.StructSchema;
import pm.Error;

using pm.Strings;
using pm.Iterators;
using pm.Arrays;
using pm.Functions;

class AVLIndex<Key, Item> extends AbstractIndex<Key, Item> {
    public var keyComparator:Comparator<Key>;
    public var itemEquator:Equator<Item>;
    public var schema:Null<StructSchema> = null;

    public var tree:AVLTree<Key, Item>;

    public function new(o:IndexOptions<Key, Item> & {?schema:StructSchema}) {
        super(o);
        this.keyType = nor(o.keyType, this.keyType);
        this.sparse = nor(o.sparse, this.sparse);
        this.unique = nor(o.unique, this.unique);
        this.indexType = switch o {
            case {type:IndexType.Simple(path)}: Simple(path);
            case {fieldName: fieldName} if (!fieldName.empty()): Simple(DotPath.fromPathName(fieldName));
            case {type: other}: other;
        };
        this.itemEquator = switch options.itemEquator {
            case null: Equator.anyEq();
            case eq: eq;
        }
        if (nn(options.keyOrdering)) {
            this._compareKeys = (a:Key, b:Key) -> options.keyOrdering.intComparison(a, b);
        }
        else {
            this.keyComparator = options.keyComparator;
        }

        this.tree = new AVLTree({
            unique: unique,
            model: new OptTreeModel({
                compareKeys: (a, b) -> this.compareKeys(a, b),
                checkValueEquality: (a, b) -> this.itemsEq(a, b)
            })
        });
    }

/* === [Dynamic Methods] === */

    private dynamic function _compareKeys(a:Key, b:Key):Int {
        // return Reflect.compare(a, b);
        if (keyComparator != null)
            return keyComparator.compare(a, b);
        else
            return Reflect.compare(a, b);
    }

    private dynamic function _itemsEq(a:Item, b:Item):Bool {
        if (itemEquator != null) {
            return itemEquator.equals(a, b);
        }
        else {
            return a == b;
        }
    }

/* === [Methods] === */

    override function getItemKey(item: Item):Key {
        if (nn(options.getItemKey)) {
            return options.getItemKey(item);
        }

        return switch indexType {
            case Simple(path): cast path.get(cast item);
            case Expression(e):
                throw new NotImplementedError('Expression(_) indexType');
        };
    }

    override function compareKeys(a:Key, b:Key):Int {
        return this._compareKeys(a, b);
    }

    override function compareItems(a:Item, b:Item) {
        return pmdb.core.Arch.compareThings(a, b);
    }

    private inline function missingKey(item: Item):IndexError<Key, Item> {
		var field:String = if (options.fieldName != null) options.fieldName else switch indexType {
			case Simple(path): path.pathName;
			case Expression(e): e.print();
		};

		return new IndexError(MissingProperty(field), '$item is missing "$field" property');
    }

    override function insertOne(item: Item) {
        var key:Key = getItemKey(item);
        if (key == null && !sparse) {
            throw missingKey(item);
        }

        tree.insert(key, item);
    }

    override function removeOne(item: Item):Bool {
        var key = getItemKey(item);
        if (key == null) {
            if (sparse) return false;
            throw missingKey(item);
        }
        if (unique)
            return tree.delete(key);
        else
            return tree.delete(key, item);
    }

    override function updateOne(oldItem:Item, newItem:Item) {
        removeOne(oldItem);
        try {
            insertOne(newItem);
        }
        catch (e: Dynamic) {
            insertOne(oldItem);
            throw e;
        }
    }

	override function getByKey(key:Key):Null<Array<Item>> {
		return tree.get(key);
	}

    override function getByKeys(keys: Array<Key>):Array<Item> {
        var res:Array<Item> = new Array();
        for (key in keys) {
            switch getByKey(key) {
                case null:
                    continue;
                case items:
                    res = res.concat(items);
            }
        }
        return res;
    }

    override function getBetweenBounds(?min:KeyBoundary<Key>, ?max:KeyBoundary<Key>):Array<Item> {
        //TODO fix this hack
        var min:Null<BoundingValue<Key>> = switch min {
            case null: null;
            case bound: bound.inclusive ? BoundingValue.Inclusive(bound.key) : Edge(bound.key);
        };
		var max:Null<BoundingValue<Key>> = switch max {
			case null: null;
			case bound: bound.inclusive ? BoundingValue.Inclusive(bound.key) : Edge(bound.key);
		};
        return tree.betweenBounds(min, max);
    }

    override function getAll():Array<Item> {
        var ret = [];
        tree.executeOnEveryNode(node -> Utils.Arrays.append(ret, node.data));
        return ret;
    }

    override function size():Int {
        return tree.size();
    }
}