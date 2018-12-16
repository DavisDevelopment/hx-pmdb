package pmdb.core;

import tannus.io.Char;
import tannus.ds.Lazy;

import pmdb.core.Arch;
import pmdb.core.Object;

import haxe.PosInfos;
import haxe.ds.Option;

import pmdb.core.Assert.assert;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

@:forward
abstract DotPath (DotPathObject) from DotPathObject to DotPathObject {
    public inline function new(path, pathName) {
        this = DotPathObject.make(path, pathName);
    }

/* === Methods === */

    @:from
    public static inline function fromPathName(path: String):DotPath {
        return new DotPath(path.split('.'), path);
    }
    @:from
    public static inline function fromPath(path: Array<String>):DotPath {
        return new DotPath(path, path.join('.'));
    }
}

class DotPathObject {
    /* Constructor Function */
    public function new(path, pathName) {
        this.path = path;
        this.pathName = pathName;
    }

/* === Methods === */

    /**
      assign
     **/
    public function set(o:Doc, value:Dynamic, doNotReplace=false, ?notFound:Array<String>->Dynamic):Dynamic {
        if (path.length == 0)
            throw new Error('Cannot assign value at empty key');

        return _set(o,
            path.copy(), 0,
            value,
            doNotReplace,
            notFound
        );
    }

    static function _set(o:Doc, path:Array<String>, pathIdx:Int, value:Dynamic, doNotReplace:Bool, ?noFound:Array<String>->Dynamic):Dynamic {
        assert(pathIdx >= 0 && pathIdx < path.length, 'Index($pathIdx) is Outside Bounds(0:${path.length})');

        if (noFound == null) {
            noFound = function(_) {
                return null;
            }
        }

        // get reference to the current path component
        var currentPath = path[pathIdx];

        // get reference to the current value along the path
        var currentValue:Option<Dynamic> = _getDefined(o, currentPath);

        // actually perform the assignment
        if (pathIdx == path.length - 1) {
            return _setShallow(o, currentPath, value);
        }
        else {
            switch (currentValue) {
                case Some(null), None:
                    var nv = noFound(path.slice(0, pathIdx));
                    if (nv == null)
                        throw new Error('null has no (${path.slice(0, pathIdx)}) property');
                    return _set(o = _setShallow(o, currentPath, nv), path, ++pathIdx, value, doNotReplace, noFound);

                case Some(val):
                    return _set(o = cast val, path, ++pathIdx, value, doNotReplace, noFound);
            }
        }
    }

    public function get(o:Doc, ?defaultValue:Dynamic):Dynamic {
        return _get(o, path.copy(), defaultValue);
    }

    static function _get(o:Doc, path:Array<String>, ?defaultValue:Dynamic):Dynamic {
        var currentPath = path.shift();
        //trace({
            //o: o,
            //path: path,
            //currentPath: currentPath
        //});

        var next: Dynamic = _getShallow(o, currentPath, path.length == 0 ? defaultValue : null);
        if (next == null || path.length == 0) {
            return next;
        }
        if (Arch.isArray( next )) {
            var array:Array<Dynamic> = cast next;
            return array.map(x -> _get(x, path.copy(), defaultValue));
        }
        return _get(next, path, defaultValue);
    }

    public function del(o:Doc, ?trueDeletion:Bool):Bool {
        return _del(o, path.copy(), trueDeletion);
    }

    static function _del(o:Doc, path:Array<String>, ?trueDeletion:Bool):Bool {
        var currentPath = path.shift();
        if (_hasShallow(o, currentPath)) {
            if (path.length == 0) {
                return _delShallow(o, currentPath, trueDeletion);
            }
            else {
                return _del(cast o[currentPath], path, trueDeletion);
            }
        }
        else {
            return false;
        }
    }

    public function has(o:Doc, ?allowInherited:Bool):Bool {
        if (path.length == 0)
            return false;
        return _has(o,
          path.copy(),
          allowInherited
        );
    }

    static function _has(o:Doc, path:Array<String>, ?allowInherited:Bool):Bool {
        if (o == null) return false;
        if (path.length > 1)
            return _has(o[path.shift()], path, allowInherited);
        else if (path.length == 1)
            return _hasShallow(o, path[0], allowInherited);
        return false;
    }

/* === Internal Implementation Methods === */

    static function _getDefined(o:Doc, name:String, ?defaultValue:Option<Dynamic>):Option<Dynamic> {
        assert(name != null, "[name] must be a non-NULL String");
        if (_hasShallow(o, name)) {
            return Some(o.get(name));
        }
        return defaultValue != null ? defaultValue : None;
    }

    static function _setShallow(o:Doc, name:String, value:Dynamic):Dynamic {
        return o[name] = value;
    }

    static function _hasShallow(o:Doc, name:String, allowInherited=true):Bool {
        return allowInherited ? o[name] != null : o.exists( name );
    }

    static function _delShallow(o:Doc, name:String, trueDeletion=false):Bool {
        return trueDeletion ? o.remove( name ) : {
            var had = _hasShallow(o, name, !trueDeletion);
            o[name] = null;
            had;
        };
            
    }

    static function _getShallow(o:Doc, name:String, ?defaultValue:Dynamic, ?allowInherited:Bool):Dynamic {
        assert(name != null, "[name] must be a non-NUL String");
        if (_hasShallow(o, name, allowInherited)) {
            return o[name];
        }
        return defaultValue;
    }

    public static function make(path, pathName):DotPathObject {
        if (!cache.exists( pathName )) {
            cache[pathName] = new DotPathObject(path, pathName);
        }
        return cache[pathName];
    }

    static var cache:Map<String, DotPathObject> = new Map();

/* === Fields === */

    public var pathName(default, null): String;
    public var path(default, null): Array<String>;
}

private typedef Doc = Object<Dynamic>;

enum DotPathToken {
    Attr(field: String);
    Item(index: Int);
    Slice(start:Int, ?end:Int);

    Decorated(tk:DotPathToken, decorator:DotPathDecorator);
}

enum DotPathDecorator {
    ItemWise;
}

class DotPathParser {
    public function new() {
        //
    }

    public function parse(path: String) {
        input = path;
        cursor = 0;
        tokens = [];
        char = null;
    }

    function readChar():Null<Char> {
        if (char != null) {
            var res = this.char;
            char = null;
            return res;
        }
        else if (cursor < input.length - 1) {
            return input.characterAt( cursor++ );
        }
        else {
            return null;
        }
    }

    var char: Null<Char> = null;
    var tokens:Array<DotPathToken>;

    var input: String;
    var cursor: Int = 0;
}
