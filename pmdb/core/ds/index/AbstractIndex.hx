package pmdb.core.ds.index;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.schema.Types;
import pmdb.core.ds.index.IIndex;
import pm.Error;

class AbstractIndex<Key, Item> implements IIndex<Key, Item> {
    public function new(o) {
        this.options = Arch.clone(o, Shallow);
        this.sparse = false;
        this.unique = false;
        this.keyType = DataType.TUnknown;
        this.itemType = DataType.TUnknown;
    }

/* === Fields === */

	public var sparse(default, null):Bool;
	public var unique(default, null):Bool;
	public var keyType(default, null):DataType;
	public var itemType(default, null):DataType;
	public var indexType(default, null):IndexType;
	public var options(default, null):IndexOptions<Key, Item>;

/* === Methods === */

    private function compareKeys(a:Key, b:Key):Int {
        throw new NotImplementedError('IIndex.compareKeys');
    }
    
    private function compareItems(a:Item, b:Item):Int {
        throw new NotImplementedError('IIndex.compareItems');
    }

    private function getItemKey(item: Item):Key {
        throw new NotImplementedError('IIndex.getItemKey');
    }

    private function itemsEq(a:Item, b:Item):Bool {
        return a == b;
    }

    public function insertOne(item: Item) {
        throw new NotImplementedError('IIndex.insertOne');
    }

    public function removeOne(item: Item):Bool {
        throw new NotImplementedError('IIndex.removeOne');
    }

    public function updateOne(oldDoc:Item, newDoc:Item) {
        throw new NotImplementedError('IIndex.updateOne');
    }

    public function insertMany(items: Array<Item>) {
		try {
			for (i in 0...items.length) {
				try {
					this.insertOne(items[i]);
				} 
                catch (e: Dynamic) {
					throw new IndexRollback(e, i);
				}
			}
		} 
        catch (rollback: IndexRollback<Dynamic>) {
			for (i in 0...rollback.failingIndex) {
				this.removeOne(items[i]);
			}
			throw rollback.error;
		} 
        catch (error:Dynamic) {
			throw error;
		}
    }

    public function removeMany(items: Array<Item>) {
        for (item in items) {
            removeOne(item);
        }
    }

	public function updateMany(updates:Array<{oldDoc:Item, newDoc:Item}>) {
		var revert:Array<{oldDoc:Item, newDoc:Item}> = new Array();
		for (update in updates) {
			try {
				updateOne(update.oldDoc, update.newDoc);
				revert.push(update);
			} 
            catch (e:Dynamic) {
				revertAllUpdates(revert);
				throw e;
			}
		}
		revert = [];
	}

    public function revertUpdate(oldDoc:Item, newDoc:Item) {
        updateOne(newDoc, oldDoc);
    }

	/**
		reverse (undo) a given list of updates
	**/
	public function revertAllUpdates(updates:Array<{oldDoc:Item, newDoc:Item}>) {
		updates = updates.map(u -> {oldDoc: u.newDoc, newDoc: u.oldDoc});
		updateMany(updates);
	}

    public function getByKey(key: Key):Null<Array<Item>> {
        throw new NotImplementedError('IIndex.getByKey');
    }

    public function getByKeys(keys: Array<Key>):Array<Item> {
        throw new NotImplementedError('IIndex.getByKeys');
    }

    public function getBetweenBounds(?min:KeyBoundary<Key>, ?max:KeyBoundary<Key>):Array<Item> {
        throw new NotImplementedError('IIndex.getBetweenBounds');
    }

    public function getAll():Array<Item> {
        throw new NotImplementedError('IIndex.getAll');
    }

    public function itrByKey(key: Key):Itr<Item> {
        throw new NotImplementedError('IIndex.itrByKey');
    }

    public function itrByKeys(keys: Array<Key>):Itr<Item> {
        throw new NotImplementedError('IIndex.itrByKeys');
    }

    public function itrBetweenBounds(?min:KeyBoundary<Key>, ?max:KeyBoundary<Key>):Itr<Item> {
        throw new NotImplementedError('IIndex.itrBetweenBounds');
    }

    public function itrAll():Itr<Item> {
        throw new NotImplementedError('IIndex.itrAll');
    }

    public function iterator():Iterator<Item> {
        return cast itrAll();
    }

    public function allKeys():Array<Key> {
        throw new NotImplementedError('IIndex.allKeys');
    }

    public function keys():Iterator<Key> {
        return allKeys().iterator();
    }

    public function keyValueIterator():Iterator<IdxKvPair<Key, Item>> {
        throw new NotImplementedError('IIndex.keyValueIterator');
    }

    public function size():Int {
        return 0;
    }
}