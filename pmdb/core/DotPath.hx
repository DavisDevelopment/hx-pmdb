package pmdb.core;

import pmdb.core.Object;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

@:forward
abstract DotPath (DotPathObject) from DotPathObject to DotPathObject {
    public inline function new(path: String) {
        this = DotPathObject.make( path );
    }

/* === Methods === */

    @:from
    public static inline function fromString(path: String):DotPath {
        return new DotPath( path );
    }
}

class DotPathObject {
    function new(path: String) {
        this.path = path;
    }

/* === Methods === */

    public inline function get(o:Object<Dynamic>, ?defaulValue:Dynamic):Dynamic {
        return switch o.get( path ) {
            case null: defaulValue;
            case v: v;
        }
    }

    public inline function del(o: Object<Dynamic>):Bool {
        return o.remove( path );
    }

    public inline function set(o:Object<Dynamic>, value:Dynamic):Dynamic {
        return o.set(path, value);
    }

    public inline function has(o: Object<Dynamic>):Bool {
        return o.exists( path );
    }

    public static function make(path: String):DotPathObject {
        if (!cache.exists( path )) {
            cache[path] = new DotPathObject( path );
        }
        return cache[path];
    }
    static var cache:Map<String, DotPathObject> = new Map();

/* === Fields === */

    private var path(default, null): String;
}
