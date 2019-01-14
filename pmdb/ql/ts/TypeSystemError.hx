package pmdb.ql.ts;

import pmdb.core.ds.Lazy;

import haxe.ds.Option;

import pmdb.core.Error;
import pmdb.core.ValType;
import pmdb.ql.ts.TypeSignature;

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
    inline function get_type():TType return _type.get();

    var _type(default, null): Lazy<TType>;
}

class TypeError<T> extends TypeErrorLike<T, DataType> {
    /* Constructor Function */
    public function new(value, type:ValType, ?msg, ?pos) {
        super(value, type, msg, pos);
        _vtype = _value.map(function(value: T):DataType {
            return value.dataTypeOf();
        });
    }

    override function defaultMessage():String {
        return '$vtype should be $type';
    }

    public var vtype(get, never): DataType;
    inline function get_vtype():DataType return _vtype.get();

    var _vtype(default, null): Lazy<DataType>;
}

class NullCheckError<T> extends TypeSystemError<T> {

}

class Invalid<A, B> extends Error {
    /* Constructor Function */
    public function new(got:Lazy<A>, ?expected:Lazy<B>, ?msg, ?pos):Void {
        super(msg, pos);
        name = 'Error';

        this._a = got;
        this._b = switch ( expected ) {
            case null: Option.None;
            case _: Option.Some( expected );
        }
    }

    override function defaultMessage() {
        switch ( _b ) {
            case Some( e ):
                return '$a should be ${e.get()}';

            case None:
                return '$a is invalid';
        }
    }

/* === Properties === */

    public var a(get, never): A;
    inline function get_a():A return _a.get();

    public var b(get, never): Null<B>;
    inline function get_b():Null<B> {
        return switch ( _b ) {
            case Some(e): e.get();
            case None: null;
        }
    }

/* === Vars === */

    var _a(default, null): Lazy<A>;
    var _b(default, null): Option<Lazy<B>>;
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
