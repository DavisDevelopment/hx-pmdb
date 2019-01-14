package pmdb.core;

import pmdb.ql.ts.DataType;

import haxe.PosInfos;

using pmdb.ql.ts.DataTypes;

@:forward
abstract TypedValue (TypedValueImpl) from TypedValueImpl to TypedValueImpl {
    public static var type(default, null): TypedValueImpl;
    public inline function new(value:Dynamic, type:DataType, ?safe:Bool, ?pos:PosInfos):Void {
        this = new TypedValueImpl(value, type, safe, pos);
    }

    @:from
    public static inline function of(x: Dynamic):TypedValue {
        return new TypedValue(x, x.dataTypeOf());
    }
}

class TypedValueImpl {
    public final type : DataType;
    public final value : Dynamic;

    private var createdAt(default, null):Null<PosInfos> = null;

    public function new(value:Dynamic, type:DataType, safe=true, ?pos:PosInfos):Void {
        this.type = type;
        this.value = value;

        #if debug
        this.createdAt = pos;
        #end

        if ( safe ) {
            assert(type.checkValue(value), new TypeError(value, type, null, pos));
        }
    }

/* === Methods === */

    public function retype(newType:DataType, safe=true, ?pos:PosInfos):TypedValue {
        return new TypedValue(value, newType, safe, pos);
    }
}
