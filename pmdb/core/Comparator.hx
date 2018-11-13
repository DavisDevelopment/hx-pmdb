package pmdb.core;

import tannus.io.ByteArray;
import tannus.ds.Dict;

import tannus.math.TMath as Math;

import haxe.io.Bytes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.TypeChecks;
import pmdb.ql.ts.TypeCasts;
import pmdb.ql.ts.TypeSystemError;

import pmdb.ql.ts.TypeChecks.*;

using tannus.ds.SortingTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

@:forward(compare)
abstract Comparator<T> (IComparator<T>) from IComparator<T> to IComparator<T> {
/* === Instance Methods === */

    /**
      create and return a Comparator for comparing arrays of the same value that [this] Comparator compares
     **/
    public inline function toArrayComparator():Comparator<Array<T>> {
        return arrayComparator(this);
    }

    /**
      make [this] Comparator nullable
     **/
    public inline function toNullable():Comparator<Null<T>> {
        return makeNullable( this );
    }

    /**
      'map' [this] Comparator
     **/
    public inline function map<O>(f: T->O):Comparator<O> {
        return cast new MappedComparator(cast this, f);
    }

/* === Static Instances === */

/* === Factories === */

    /**
      Boolean comparison
     **/
    @:noUsing public static inline function cboolean():Comparator<Bool> {
        return BooleanComparator.make();
    }

    /**
      Int comparison
     **/
    @:noUsing public static inline function cint():Comparator<Int> {
        return IntComparator.make();
    }

    /**
      Float comparison
     **/
    @:noUsing public static inline function cfloat():Comparator<Float> {
        return FloatComparator.make();
    }

    /**
      String comparison
     **/
    @:noUsing public static inline function cstring():Comparator<String> {
        return StringComparator.make();
    }

    /**
      ByteArray comparison
     **/
    @:noUsing public static inline function cbytes():Comparator<ByteArray> {
        return BytesComparator.make(); 
    }

    /**
      Date comparison
     **/
    public static inline function cdate():Comparator<Date> return new DateComparator();

    /**
      Dynamic comparison
     **/
    public static inline function cany<T>():Comparator<T> return cast AnyComparator.make();
    
    /**
      <T> comparison
     **/
    @:from
    @:noUsing
    public static function create<T>(compare: T->T->Int):Comparator<T> {
        return new FComparator( compare );
    }

    /**
      Array<T> comparison
     **/
    @:noUsing
    public static function arrayComparator<T>(itemComparator: Comparator<T>):Comparator<Array<T>> {
        return new ArrayComparator( itemComparator );
    }

    @:noUsing
    public static function makeNullable<T>(c: Comparator<T>):Comparator<Null<T>> {
        return new NullableComparator( c );
    }
}

/**
  the interface which defines comparisons
 **/
interface IComparator<T> {
    function compare(a:T, b:T):Int;
}

private class ReflectComparator<T> implements IComparator<T> {
    /* Constructor Function */
    public function new() {}
    public function compare(x:T, y:T):Int {
        return Reflect.compare(x, y);
    }
}

class NumComparator<T:Float> extends ReflectComparator<T> {}
class FloatComparator extends NumComparator<Float> {
    static var i:FloatComparator = new FloatComparator();
    public static inline function make():FloatComparator return i;
}
class IntComparator extends NumComparator<Int> {
    static var i:IntComparator = new IntComparator();
    public static inline function make():IntComparator return i;
}

class StringComparator extends ReflectComparator<String> {
    static var i:StringComparator = new StringComparator();
    public static inline function make():StringComparator return i;
}

class BooleanComparator implements IComparator<Bool> {
    public function new() {}
    public function compare(x:Bool, y:Bool):Int {
        #if js
        return Reflect.compare(x, y);
        #else
        return Reflect.compare(x?1:0, y?1:0);
        #end
    }

    static var i:BooleanComparator = new BooleanComparator();
    public static inline function make():BooleanComparator return i;
}

class DateComparator implements IComparator<Date> {
    public function new() {}
    public function compare(x:Date, y:Date):Int {
        return Reflect.compare(x.getTime(), y.getTime());
    }
}

private class NullableComparator<T> implements IComparator<Null<T>> {
    /* Constructor Function */
    public function new(c) {
        this.c = c;
    }

    public function compare(a:Null<T>, b:Null<T>):Int {
        if (a == b) return 0;
        return switch [a, b] {
            case [null, _]: -1;
            case [_, null]: 1;
            case _: c.compare(a, b);
        }
    }

    var c(default, null): Comparator<T>;
}

private class ArrayComparator<T> implements IComparator<Array<T>> {
    var c(default, null): Comparator<T>;
    /* Constructor Function */
    public function new(c) {
        this.c = c;
    }

    public function compare(a:Array<T>, b:Array<T>):Int {
        var comp;
        for (i in 0...Math.min(a.length, b.length)) {
            comp = c.compare(a[i], b[i]);
            switch comp {
                case 0:
                case _:
                    return comp;
            }
        }
        return Reflect.compare(a.length, b.length);
    }
}

class ByteArrayComparator implements IComparator<ByteArray> {
    /* Constructor Function */
    public function new() {
        c = IntComparator.make();
    }

/* === Instance Methods === */

    public function compare(a:ByteArray, b:ByteArray):Int {
        var comp: Int;

        for (i in 0...Math.min(a.length, b.length)) {
            comp = c.compare(a[i], b[i]);
            switch comp {
                case 0:
                    //
                case _:
                    return comp;
            }
        }

        return c.compare(a.length, b.length);
    }

/* === Instance Fields === */

    var c(default, null): Comparator<Int>;

/* === Statics === */

    private static var i(default, null): ByteArrayComparator = new ByteArrayComparator();

    public static function make():ByteArrayComparator return i;
}

class BytesComparator implements IComparator<ByteArray> {
    /* Constructor Function */
    public function new() {
        c = IntComparator.make();
    }

/* === Instance Methods === */

    public function compare(a:ByteArray, b:ByteArray):Int {
        var comp: Int;

        for (i in 0...Math.min(a.length, b.length)) {
            comp = c.compare(a[i], b[i]);
            switch comp {
                case 0:
                    //
                case _:
                    return comp;
            }
        }

        return c.compare(a.length, b.length);
    }

/* === Instance Fields === */

    var c(default, null): Comparator<Int>;

/* === Statics === */

    private static var i(default, null): ByteArrayComparator = new ByteArrayComparator();

    public static function make():ByteArrayComparator return i;
}

/**
  [= FIXME:Performance =]
  this class should be adaptive, checking the first argument's type and then assuming:
   - that the second argument will be of a compatible type
   - that subsequent invokations will involve values of the same type as the first invokation
---

  [= Comparison Precedence =]
  - Null
  - Bool (true > false)
  - Int (1 > 0)
  - Float (1.1 > 1.0)
  - String (lexicographical order)
  (compound values)
  - EnumValue
  - Array<Any>
  - Object<Any>
  - ClassInstance
 **/
class AnyComparator<T> implements IComparator<T> {
    /* Constructor Function */
    function new() {
        /*
        subs = new Map();
        var scalars = ScalarDataType.createAll();
        for (type in scalars) {
            var tcomp = subs[hashType(TScalar(type))] = type.getTypedComparator();
            subs[hashType(TNull(TScalar(type)))] = tcomp.toNullable();
        }
        */
    }

    var subs:Map<String, Comparator<Dynamic>>;

    function comparatorFor(type: DataType):Comparator<Dynamic> {
        var key = hashType(type);
        if (subs.exists( key ))
            return subs[key];
        makeCompFor(type, key);
        return subs[key];
    }

    function makeCompFor(type:DataType, ?key:String) {
        if (key == null)
            key = hashType(type);
        switch type {
            //
            default:
                throw new Error('No Comparator for $type');
        }
    }

    function hashType(type: DataType):String {
        return switch ( type ) {
            case TAny: 'TAny';
            case TScalar(type): Std.string(type);
            case TAnon(null): 'TObject';
            case TAnon(anon): hashAnon(anon);
            case TArray(type): '[${hashType(type)}]';
            case TClass(cl): Type.getClassName(cl);
            case TNull(type): '?${hashType(type)}';
            case TUnion(a, b): '${hashType(a)}|${hashType(b)}';
            case TStruct(_): throw new Error('TStruct(_) not supported');
        }
    }

    function hashAnon(anon: CObjectType):String {
        var b = new StringBuf();
        b.add('TAnon');
        if (anon.params != null) {
            b.add('<' + anon.params.join(',') + '>');
        }
        b.add('({');
        for (i in 0...anon.fields.length) {
            var field = anon.fields[i];
            if ( field.opt )
                b.add('?');
            b.add('${field.name}: ');
            b.add(hashType( field.type ));
            if (i < anon.fields.length - 1)
                b.add(',');
        }
        return b.toString();
    }

    public function compare(x:T, y:T):Int {
        if (x == y)
            return 0;
        else return switch [x, y] {
            case [null, _]: -1;
            case [_, null]:  1;
            default: Arch.compareThings(x, y);
        }
        //return Arch.compareThings(x, y);
    }

    function typedCompare(x:TypedData, y:TypedData):Int {
        return 0;
        //return switch [x, y] {
            //case [TypedData.DNull, TypedData.DNull]: 0;
            //case [TypedData.DNull, _]: -1;
            //case [_, TypedData.DNull]:  1;
            //case [DAny(x), y], [y, DAny(x)]: Arch.compareThings(x, y.getUnderlyingValue());
            //case [DBool(x), DBool(y)]: 
            //case [DArray(xtype, xa), DArray(ytype, ya)]:
                //if (xtype.unify( ytype )) {
                    //array.compare(xa, ya);
                //}
                //else {
                    //throw new Error('$xtype and $ytype do not unify');
                //}
            //case [TypedData.DNull]
        //}
    }

/* === Props === */

    //var cb(get, never): BooleanComparator;
    //var ci(get, never): IntComparator;
    //var cf(get, never): FloatComparator;
    //var cs(get, never): StringComparator;
    //var cba(get, never): BytesComparator;
    //var array(get, never): ArrayComparator<Dynamic>;

    //var _cb: BooleanComparator = null;
    //var _ci: IntComparator = null;
    //var _cf: FloatComparator = null;
    //var _cs: StringComparator = null;
    //var _cba: BytesComparator = null;
    //var _array: ArrayComparator<Dynamic> = null;

    //inline function get_cb() {
        //return _cb == null ? _cb = BooleanComparator.make() : _cb;
    //}

    //inline function get_ci() {
        //return _ci == null ? _ci = IntComparator.make() : _ci;
    //}

    //inline function get_cf() {
        //return _cf == null ? _cf = FloatComparator.make() : _cf;
    //}

    //inline function get_cs() {
        //return _cs == null ? _cs = StringComparator.make() : _cs;
    //}

    //inline function get_cba() {
        //return _cba == null ? _cba = BytesComparator.make() : _cba;
    //}

    //inline function get_array() {
        //return _array == null ? _array = new ArrayComparator(this) : _array;
    //}

/* === Fields === */
    static var i:AnyComparator<Any> = new AnyComparator();
    public static inline function make():AnyComparator<Any> return i;
}

class MappedComparator<TFrom, TTo> implements IComparator<TFrom> {
    /* Constructor Function */
    public function new(c, f) {
        this.c = c;
        value = f;
    }

    public function compare(x:TFrom, y:TFrom):Int {
        return c.compare(value(x), value(y));
    }

    var c(default, null): Comparator<TTo>;
    var value(default, null): TFrom -> TTo;
}

class FComparator<T> implements IComparator<T> {
    var f(default, null): T->T->Int;
    /* Constructor Function */
    public function new(f) {
        this.f = f;
    }
    public function compare(a:T, b:T):Int return f(a, b);
}

class InvertedComparator<T> implements IComparator<T> {
    /* Constructor Function */
    public function new(c) {
        this.c = c;
    }

    public function compare(a:T, b:T):Int {
        return -c.compare(a, b);
    }

    var c(default, null): Comparator<T>;
}
