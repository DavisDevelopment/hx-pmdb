package pmdb.core.ds;

import tannus.ds.dict.DictKey;
import tannus.ds.Dict;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using tannus.async.OptionTools;

class Cache<T> {
    var d:Map<Int, T>;
    var i:Incrementer;

    public function new(?src:Array<T>, ?eq:T->T->Bool) {
        d = new Map();
        i = new Incrementer();
        if (eq != null)
            same = eq;
    }

    dynamic function same(x:T, y:T):Bool {
        return FunctionTools.equality(x, y);
    }

    public function put(x: T):Int {
        for (id in d.keys()) {
            if (same(x, d[id])) {
                return id;
            }
        }
        var id = i.next();
        d[id] = x;
        return id;
    }

    public inline function get(id: Int):T {
        return d[id];
    }

    public function map():Map<Int, T> {
        return [for (key in d.keys()) key=>d[key]];
    }
}
