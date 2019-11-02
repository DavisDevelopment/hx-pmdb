package pmdb.ql.ts;

import pm.Lazy;

import haxe.ds.Option;

import pmdb.core.Error;
import pmdb.core.ValType;

using pmdb.ql.ts.DataTypes;

class TypeSystemError<T> extends ValueError<T> {
    //
}

class TypeErrorLike<TValue, TType> extends TypeSystemError<TValue> {
    /* Constructor Function */
    public function new(value, type, ?msg, ?pos) {
        super(value, msg, pos);

        this._type = type;
        this.name = 'TypeError';
    }

    public var type(get, never): TType;
    inline function get_type():TType return _type != null ? _type.get() : null;

    var _type(default, null): Lazy<TType>;
}

class TypeError<T> extends TypeErrorLike<T, DataType> {
    /* Constructor Function */
    public function new(value, type:ValType, ?msg, ?pos) {
        super(value, type, msg, pos);
        if (value == null) {
            _vtype = DataType.TUnknown;
        }
        else {
            _vtype = value.dataTypeOf();
        }
    }

    override function defaultMessage():String {
        return '$vtype should be ${type!=null?""+type:"Unknown"}';
    }

    public var vtype(get, never): DataType;
    inline function get_vtype():DataType return _vtype;

    var _vtype(default, null): DataType;
}

class NullCheckError<T> extends TypeSystemError<T> {

}

class Invalid<A, B> extends Error {
    /* Constructor Function */
    public function new(got:A, expected:B, ?msg, ?pos):Void {
        super(msg, pos);
        name = 'Error';

        a = got;
        b = expected;
    }

    override function defaultMessage() {
        return '$a should be $b';
    }

/* === Vars === */

    var a: A;
    //var _b(default, null): Option<Lazy<B>>;
    var b: B;
}

class InvalidOperation<Op> extends ValueError<Op> {
    public function new(operation:Lazy<Op>, ?msg, ?pos) {
        super(operation, msg, pos);
        name = 'InvalidOperation';
    }
    override function defaultMessage() {
        return Std.string( value );
    }
}
