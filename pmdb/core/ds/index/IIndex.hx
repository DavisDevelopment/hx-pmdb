package pmdb.core.index;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;

interface IIndex<Key, Item> {
/* === Fields === */
    var options(default, null): IndexOptions<Key, Item>;
    var name(default, null): String;
    var sparse(default, null): Bool;
    var unique(default, null): Bool;
    var keyType(default, null): DataType;
    var itemType(default, null): DataType;
    var keyComparator(default, null): Comparator<Key>;
    var itemComparator(default, null): Comparator<Item>;
    var keyEquator(default, null): Equator<Key>;
    var itemEquator(default, null): Equator<Item>;

/* === Methods === */

    function insertOne(doc: Item):Void;
    function insertMany(docs: Array<Item>):Void;

    function removeOne(doc: Item):Void;
    function removeMany(docs: Array<Item>):Void;

    function updateOne(oldDoc:Item, newDoc:Item):Void;
    function updateMany(updates: Array<{oldDoc:Item, newDoc:Item}>):Void;

    function revertUpdate(oldDoc:Item, newDoc:Item):Void;
    function revertAllUpdates(updates: Array<{oldDoc:Item, newDoc:Item}>):Void;

    function getByKey(key: Key):Null<Array<Item>>;
    function getByKeys(keys: Array<Key>):Array<Item>;
    function getBetweenBounds(?min:BoundingValue<Key>, ?max:BoundingValue<Key>):Array<Item>;
    function getAll():Array<Item>;

    function itrByKey(key: Key):Itr<Item>;
    function itrByKeys(keys: Array<Key>):Itr<Item>;
    function itrBetweenBounds(?min:BoundingValue<Key>, ?max:BoundingValue<Key>):Itr<Item>;
    function itrAll():Itr<Item>;
    function iterator():Itr<Item>;

    function allKeys():Array<Key>;
    function keys():Iterator<Key>;
    function keyValueIterator():Iterator<IdxKvPair<Key, Item>>;

    function getDocKey(doc: Item):Key;

    function compareKeys(a:Key, b:Key):Int;
    function compareItems(a:Item, b:Item):Int;

    function keysEq(a:Key, b:Key):Bool;
    function itemsEq(a:Item, b:Item):Bool;
}

typedef IndexOptions<Key, Item> = {
    fieldName: String,
    ?fieldType: DataType,
    ?keyComparator: Comparator<Key>,
    ?itemEquator: Equator<Item>,
    ?getItemKey: Item -> Key,
    ?unique: Bool,
    ?sparse: Bool
};

@:structInit
class IdxKvPair<K, V> {
    public final key: K;
    public final value: V;

    public function new(k:K, v:V) {
        key = k;
        value = v;
    }
}
