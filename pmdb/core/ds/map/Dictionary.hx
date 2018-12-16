package pmdb.core.ds.map;

import haxe.Constraints.IMap;

using tannus.ds.IteratorTools;

/**
 * In this implementation, Dictionary is like a StringMap,
 * but the order of keys is maintained in insertion order.
 * Alternatively, the keys can be sorted.
 * 
 * You can use array access with either Int or String, and it'll
 * use the underlying getByIndex or getByKey respectively.
 *
 * Usage:
 *      var d:Dictionary<String> = new Dictionary<String>();
 *      d["b"] = "bbb";
 *      d["d"] = "ddd";
 *      d["a"] = "aaa";
 *      d["c"] = "ccc";
 *      
 *      // appears in insertion order
 *      trace(d);
 *      
 *      // these 2 lines modify the same entry
 *      d[2] = "zzz";
 *      d["a"] = "yyy";
 * 
 * @author Munir Hussin
 */
@:forward 
abstract Dictionary<V>(DictionaryType<V>) to DictionaryType<V> from DictionaryType<V> {
    public inline function new() {
        this = new DictionaryType();
    }
    
    @:arrayAccess 
    public inline function getByIndex(i: Int):V {
        return this.getByIndex( i );
    }
    
    @:arrayAccess 
    public inline function get(s: String):V {
        return this.get( s );
    }
    
    @:arrayAccess 
    public inline function setByIndex(i:Int, value:V):V {
        this.setByIndex(i, value);
        return value;
    }
    
    @:arrayAccess 
    public inline function set(s:String, value:V):V {
        this.set(s, value);
        return value;
    }
    
    @:to 
    public inline function toString():String {
        return this.toString();
    }

    /**
     * Usage: Std.is(anymap, AnyMap.type);
     */
    public static var type(default, null) = DictionaryType;
}


private class DictionaryType<V> {
    public function new() {
        arr = [];
        map = new Map<String, V>();
    }
    
/* === Methods === */

    public function copy():DictionaryType<V> {
        var d = new DictionaryType();
        d.arr = arr.copy();
        d.map = map.copy();
        return d;
    }
    
    /**
     * Sort the entries. If `cmp` is not given, the entries are sorted
     */
    public function sort(?fn: {key:String, value:V}->{key:String, value:V}->Int):Void {
        throw 'Not Implemented';
    }
    
    public inline function get(key: String):V {
        return map.get( key );
    }
    
    public function set(key:String, value:V):Void {
        // if it's a new key, add it to the ordered keys
        if (!map.exists( key ))
            arr.push( key );
        map.set(key, value);
    }
    
    public inline function getByIndex(i: Int):V {
        return map.get(arr[i]);
    }
    
    public function setByIndex(i:Int, value:V):Void {
        if (i < 0 || i >= arr.length)
            throw "Index out of bounds exception.";
        map.set(arr[i], value);
    }

    public function keyOf(value: V):Null<String> {
        for (key in keys()) {
            if (get( key ) == value) {
                return key;
            }
        }
        return null;
    }

    public function indexOf(value: V):Int {
        for (i in 0...arr.length) {
            if (get(arr[i]) == value) {
                return i;
            }
        }
        return -1;
    }
    
    public function remove(key: String):Bool {
        if (map.exists( key )) {
            arr.remove(key);
            return map.remove(key);
        }
        
        return false;
    }
    
    public inline function exists(key: String):Bool {
        return map.exists( key );
    }
    
    public function iterator():Iterator<V> {
        return new DictionaryIterator<V>(this);
    }

    public function keyValueIterator() {
        return keys().map(x -> {key:x, value:get(x)});
    }
    
    public inline function keys():Iterator<String> {
        return arr.iterator();
    }
    
    public inline function values():Iterator<V> {
        return iterator();
    }

    public inline function keyArray():Array<String> {
        return arr.copy();
    }
    
    public function toString():String {
        return Std.string(map);
        var b = new StringBuf();
        b.add('Dictionary({\n');
        inline function add<T>(x: T) {
            b.add('  ');
            b.add( x );
        }

        for (index in 0...arr.length) {
            add('$index => "${arr[index]}",\n');
        }
        for (i in 0...arr.length) {
            add('"${arr[i]}" => ${get(arr[i])}');
            if (i < arr.length - 1)
                b.add(',');
            b.add('\n');
        }
        b.add('})');
        return b.toString();
    }

/* === Properties === */

    public var length(get, never):Int;
    private inline function get_length():Int return arr.length;

/* === Fields === */
    private var arr:Array<String>;
    private var map:Map<String,V>;
}

private class DictionaryIterator<V> {
    public var obj:Dictionary<V>;
    public var it:Iterator<String>;
    
    public inline function new(obj: Dictionary<V>) {
        this.obj = obj;
        this.it = obj.keys();
    }
    
    public inline function hasNext():Bool {
        return it.hasNext();
    }
    
    public inline function next():V {
        return obj.get(it.next());
    }
}


//private class DictionaryPairIterator<V> {
    //public var obj:Dictionary<V>;
    //public var it:Iterator<String>;
    
    //public inline function new(obj:Dictionary<V>) {
        //this.obj = obj;
        //this.it = obj.keys();
    //}
    
    //public inline function hasNext():Bool
    //{
        //return it.hasNext();
    //}
    
    //public inline function next():Pair<String,V>
    //{
        //var k:String = it.next();
        //return Pair.of(k, obj.get(k));
    //}
//}

