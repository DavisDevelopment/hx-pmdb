package pmdb.ql.ast;

import tannus.ds.Lazy;

import pmdb.ql.ts.DataType;

using StringTools;
using tannus.ds.StringUtils;
using tannus.ds.ArrayTools;

enum TypeExpr {
    TEPath(path: TypePath);
    TEAnon(fields: Array<{name:String, t:TypeExpr}>);

    /**
      TEResolved(...) values represent "expressions" of the concrete type which some other TypeExpr value has been resolved to,
      and need not be resolved again
     **/
    TEResolved(type: DataType);
}

@:structInit
class TypePath {
    /* Constructor Function */
    public inline function new(pack, name, ?params) {
        this.pack = pack;
        this.name = name;
        this.params = params;
    }

    public function toString():String {
        return pack.withAppend(name).join('.').append(
            if (!params.empty()) '<ERROR(type-params not printable yet)>'
            else ''
        );
    }

    public static inline function of(pack:Array<String>, name:String, ?params:Array<TypeExpr>):TypePath {
        return new TypePath(pack, name, params);
    }

    public static function ofArray(path: Array<String>):TypePath {
        var name = path.pop();
        return of(path, name);
    }

    public static inline function ofString(path: String):TypePath {
        return ofArray(path.split('.'));
    }

    public var pack: Array<String>;
    public var name: String;
    public var params: Null<Array<TypeExpr>>;
}
