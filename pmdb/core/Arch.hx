package pmdb.core;

import tannus.ds.*;
import tannus.io.*;
import tannus.math.TMath as M;

import pmdb.core.Error;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Check;
import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.TypeCasts;
import pmdb.ql.ts.TypeChecks;
import pmdb.core.Object;

import haxe.DynamicAccess;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.CallStack;
import haxe.PosInfos;
import haxe.io.Bytes;

import haxe.macro.Expr;
import haxe.macro.Context;

import Type.ValueType;
import pmdb.ql.ts.DataTypes.typed;
import pmdb.ql.ts.DataTypes.TypedDatas.getUnderlyingValue;

import Slambda.fn;
import Std.is as isType;
import Reflect.*;
import tannus.math.TMath.min;
import tannus.ds.AnonTools.deepCopy as copy;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using pmdb.ql.ts.TypeChecks;
using tannus.math.TMath;

/**
  collection of methods that lay out the foundation for the overall architecture of the rest of the system
 **/
class Arch {

    /**
      generate a unique identifier string
     **/
    public static inline function createNewIdString():String {
        return Uuid.create();
    }

    /**
      get a DotPath object for the given fieldName
     **/
    public static function getDotPath(fieldName: String):DotPath {
        if (!dotPathCache.exists( fieldName )) {
            dotPathCache[fieldName] = DotPath.fromPathName( fieldName );
        }
        return dotPathCache[fieldName];
    }

    /**
      resolve the given dot-path
     **/
    public static function getDotValue(o:DynamicAccess<Dynamic>, field:String):Dynamic {
        // not yet its own implementation
        //return pmdb.nedb.NModel.getDotValue(o, field);
        if (field.has('.'))
            return getDotPath(field).get(o, null);
        return o[field];
    }

    public static function setDotValue(o:DynamicAccess<Dynamic>, field:String, value:Dynamic):Void {
        //return pmdb.nedb.NModel.setDotValue(o, field, value);
        if (field.has('.'))
            getDotPath(field).set(o, value);
        else
            o[field] = value;
    }

    public static function hasDotValue(o:DynamicAccess<Dynamic>, field:String):Bool {
        if (field.has('.'))
            return getDotPath(field).has(o, false);
        return o.exists( field );
    }

    public static function delDotValue(o:DynamicAccess<Dynamic>, field:String) {
        if (field.has('.'))
            return getDotPath(field).del(o, false);
        return o.remove( field );
    }

    /**
      check whether the two given values can be considered equivalent
     **/
    public static inline function areThingsEqual(left:Dynamic, right:Dynamic, ?strict:Bool):Bool {
        return areTypedThingsEqual(typed(left), typed(right), strict);
    }

    /**
      (TODO) split the logic used in this method into the Equality module
     **/
    public static function areTypedThingsEqual(left:TypedData, right:TypedData, strictMode:Bool=false):Bool {
        /* begin with the check that should catch the majority of calls */
        if (left == right || left.equals(right)) {
            return true;
        }

        /* for simple data, values known to have the type-code that reach this check can be known to be unequal */
        else if (_isSimple( left ) && right.getIndex() == left.getIndex()) {
            //trace('Warning: Inequality determined for ($left, $right)');
            return false;
        } 

        // time to handle the patterns that make it this far
        switch [left, right] {
            // of course Null == Null
            case [DNull, DNull]:
                return true;

            // Null only equals Null, and that case is handled above
            case [DNull, _]:
                return false;

            case [_, DNull]: return switch left {
                /**
                  Measurable<?>'s with a length of 0 (empty) will report equality with NULL
                 **/
                case DArray(_, _.length => 0)
                    |DClass(String, (_:String) => _.length => 0)
                    |DClass(Bytes, (_ : Bytes) => _.length => 0): true;
                default: false;
            }

            /*
               Float == Int | Int == Float 
               should just work
             */
            case [DInt(i), DFloat(n)], [DFloat(n), DInt(i)]:
                return (0.0 + i) == n;

            /**
              [=NOTE=]
              this class-instance check may need to account for inheritence in the future(?)
             **/
            case [DClass(leftType, left), DClass(rightType, right)]:
                if (leftType == rightType) {
                    if (left == right)
                        return true;

                    switch (leftType) {
                        case Bytes:
                            throw new NotImplementedError('Arch.areTypedThingsEqual(haxe.io.Bytes, haxe.io.Bytes)');

                        case Date:
                            return cast(left, Date).getTime() == cast(right, Date).getTime();

                        // I'm reasonably sure this case is never reached, but fuck it
                        case String:
                            return left == right;

                        case _:
                            var className = Type.getClassName(leftType);
                            //trace('Warning: Inequality determined for ($className, $className)');
                            return false;
                    }
                }
                /*
                else if ({check whether leftType is an ancestor to rightType}) {
                    //... check equality treating [right] as instance of [leftType]
                }
                */
                else {
                    return false;
                }

            /* TypedData of a TypedData (recursive) */
            case [DEnum(TypedData, (_:TypedData)=>left), DEnum(TypedData, (_:TypedData)=>right)]:
                return areTypedThingsEqual(left, right);

            /* EnumValues */
            case [DEnum(le, (_:EnumValue)=>lev), DEnum(re, (_:EnumValue)=>rev)]:
                return (
                    le == re &&
                    lev.getIndex() == rev.getIndex() &&
                    areTypedThingsEqual(DArray(TAny, lev.getParameters()), DArray(TAny, rev.getParameters()))
                );

            /**
              Equatable<?> objects can test for equality with another object
             **/
            case [DClass(_, (_:Dynamic)=>o)|DObject(_, (_:Dynamic)=>o), other], [other, DClass(_, (_:Dynamic)=>o)|DObject(_, (_:Dynamic)=>o)] if (o.has_method('equals')):
                /**
                  this <code>try...catch</code> here ESPECIALLY needs to be moved away into a (non-inline) module function, as it will
                  inhibit optimization of <code>areTypedThingsEqual</code> in V8
                  see: https://floitsch.blogspot.com/search/label/V8-optimizations?m=1
                 **/
                return try o.equals(getUnderlyingValue(other)) != false catch(e: Dynamic) false;

            /**
              Objects not implementing the Equatable interface are compared, per-attribute, right to left
             **/
            //case [DClass(_, (_ : Dynamic) => left)|DObject(_, (_ : Dynamic) => left), DClass(_, (_ : Dynamic) => right)|DObject(_, (_ : Dynamic) => right)]:
            case [DObject(_, (_:Dynamic)=>left), DObject(_, (_:Dynamic)=>right)|DClass(_, (_:Dynamic)=>right)],
                 [DClass(_, (_:Dynamic)=>left), DClass(_, (_:Dynamic)=>right)|DObject(_, (_:Dynamic)=>right)]:
                //
                var attrs = fields( right );
                for (attr in attrs) {
                    if (!areThingsEqual(field(right, attr), field(left, attr))) {
                        return false;
                    }
                }
                return true;

            /* Arrays */
            case [DArray(_, left), DArray(_, right)], [DTuple(_, left), DTuple(_, right)]:
                if (left.length != right.length) 
                    return false;
                for (i in 0...left.length) {
                    if (!areThingsEqual(left[i], right[i])) {
                        return false;
                    }
                }
                return true;

            case [_, _]:
                //
        }

        return false;
    }

    public static inline function boolEquality(a:Bool, b:Bool):Bool {
        return a ? b : !b;
    }

    public static inline function intEquality(a:Int, b:Int):Bool {
        return a == b;
    }

    public static inline function floatEquality(a:Float, b:Float, epsilon:Float=0.0):Bool {
        return (Math.abs(a - b) <= epsilon);
    }

    public static inline function stringEquality(a:String, b:String):Bool {
        return a == b;
    }

    public static inline function dateEquality(a:Date, b:Date):Bool {
        return a.getTime() == b.getTime();
    }

    public static function bytesEquality(a:Bytes, b:Bytes):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (a.get( i ) != b.get( i )) {
                return false;
            }
        }
        return true;
    }

    public static inline function typedArrayEquality<T>(a:Array<T>, b:Array<T>, eq:T -> T -> Bool):Bool {
        var equivalent:Bool = true;
        if (a.length != b.length)
            equivalent = false;
        if ( equivalent ) {
            for (i in 0...a.length) {
                if (!eq(a[i], b[i])) {
                    equivalent = false;
                    break;
                }
            }
        }
        return equivalent;
    }

    /**
      check for deep equality between the two given Arrays
     **/
    public static function arrayEquality<T>(a:Array<T>, b:Array<T>):Bool {
        return typedArrayEquality(a, b, (a, b) -> areThingsEqual(a, b));
    }

    public static function enumValueEquality<T:EnumValue>(a:T, b:T):Bool {
        if (a.getIndex() != b.getIndex())
            return false;
        return arrayEquality(a.getParameters(), b.getParameters());
    }

    /**
      check for deep equality between the two given Objects
     **/
    public static function objectEquality(a:Object<Dynamic>, b:Object<Dynamic>, ?vEq:Dynamic->Dynamic->Bool):Bool {
        var aKeys = a.keys();
        var bKeys = b.keys();
        if (vEq == null) 
            vEq = ((x, y) -> areThingsEqual(x, y));

        var strCmp = (x, y) -> compareStrings(x, y);
        aKeys.sort( strCmp );
        bKeys.sort( strCmp );

        for (i in 0...min(aKeys.length, bKeys.length)) {
            if (!(stringEquality(aKeys[i], bKeys[i]) && vEq(a[aKeys[i]], b[bKeys[i]]))) {
                return false;
            }
        }

        return intEquality(aKeys.length, bKeys.length);
    }

    /**
      determine if the given TypedData can be equality-checked by EnumValue.equals()
     **/
    static function _isSimple(v: TypedData):Bool {
        return switch ( v ) {
            /* 'simple' includes all atomic value types */
            case DNull|DBool(_)|DInt(_)|DFloat(_): true;
            /* I'm not completely sure that DAny should be here, as it's for explicitly untyped values */
            case DAny(_): true;

            default: false;
        }
    }

    /**
      numerically compare the two given values
      [= this is gonna get ugly.. =]
     **/
    public static function compareThings(a:Dynamic, b:Dynamic):Int {
        // null
        if (a == null) return b == null ? 0 : -1;
        if (b == null) return a == null ? 0 :  1;

        // numbers
        if (a.is_number()) return b.is_number() ? compareNumbers(a, b) : -1;
        if (b.is_number()) return a.is_number() ? compareNumbers(a, b) :  1;

        // strings
        if (a.is_string()) return b.is_string() ? compareStrings(a, b) : -1;
        if (b.is_string()) return a.is_string() ? compareStrings(a, b) :  1;

        // booleans
        if (a.is_boolean()) return b.is_boolean() ? compareBooleans(a, b) : -1;
        if (b.is_boolean()) return a.is_boolean() ? compareBooleans(a, b) :  1;

        // dates
        if (a.is_date()) return b.is_date() ? compareDates(a, b) : -1;
        if (b.is_date()) return a.is_date() ? compareDates(a, b) :  1;

        // arrays
        if (a.is_uarray()) return b.is_uarray() ? compareArrays(a, b) : -1;
        if (b.is_uarray()) return a.is_uarray() ? compareArrays(a, b) :  1;

        // objects (with some interfaces)
        if ((a is IComparable<Dynamic>))
            return b.sametypeas( a ) ? (cast a : IComparable<Dynamic>).compareTo(cast b) : -1;
        
        // anonymous objects
        if (a.is_anon()) return b.is_anon() ? compareObjects(a, b) : -1;
        if (b.is_anon()) return a.is_anon() ? compareObjects(a, b) :  1;

        // should never be reached
        return compareObjects(a, b);
    }

    public static function compareObjects(a:Dynamic, b:Dynamic, ?vCmp:Dynamic->Dynamic->Int):Int {
        var comp: Int;
        var aKeys = fields( a );
        var bKeys = fields( b ); 
        var strCmp = ((x, y) -> compareStrings(x, y));
        //trace(aKeys.concat(bKeys).unique().isort(strCmp));
        if (vCmp == null) 
            vCmp = ((x, y) -> compareThings(x, y));

        // here is where the difference in attribute-lists between [a] and [b] affects the comparison
        aKeys.sort( strCmp );
        bKeys.sort( strCmp );

        for (i in 0...min(aKeys.length, bKeys.length)) {
            comp = vCmp(field(a, aKeys[i]), field(b, bKeys[i]));
            if (comp != 0) {
                trace('cmp(${field(a, aKeys[i])}, ${field(b, bKeys[i])}) == $comp');
                return comp;
            }
        }

        return compareNumbers(aKeys.length, bKeys.length);
    }

    public static inline function compareTypedArrays<T>(a:Array<T>, b:Array<T>, fn:(a:T, b:T)->Int):Int {
        var comp: Int = 0;
        for (i in 0...min(a.length, b.length)) {
            comp = fn(a[i], b[i]);
            if (comp != 0)
                break;
        }
        return comp == 0 ? compareNumbers(a.length, b.length) : comp;
    }

    public static function compareArrays(a:Array<Dynamic>, b:Array<Dynamic>):Int {
        return compareTypedArrays(a, b, function(a:Dynamic, b:Dynamic) {
            return compareThings(a, b);
        });
    }

    /**
      compare two EnumValue values
     **/
    public static function compareEnumValues<E:EnumValue>(a:E, b:E):Int {
        var comp:Int = compareNumbers(a.getIndex(), b.getIndex());
        if (comp != 0) return comp;
        return compareArrays(a.getParameters(), b.getParameters());
    }

    /**
      compare two Date instances
     **/
    public static inline function compareDates(a:Date, b:Date):Int {
        return compareNumbers(a.getTime(), b.getTime());
    }

    /**
      compare two Booleans
     **/
    public static inline function compareBooleans(a:Bool, b:Bool):Int {
        return compareNumbers(a ? 1 : 0, b ? 1 : 0);
    }

    /**
      compare two numbers
     **/
    public static inline function compareNumbers(a:Float, b:Float):Int {
        return
            if (a < b) -1
            else if (a > b) 1
            else 0;
    }

    /**
      compare two String instances
     **/
    public static inline function compareStrings(a:String, b:String):Int {
        return Reflect.compare(a, b);
    }

    /**
      compare two Bytes objects
     **/
    public static function compareBytes(a:Bytes, b:Bytes):Int {
        var comp: Int;

        for (i in 0...a.length.min(b.length)) {
            comp = compareNumbers(a.get(i), b.get(i));
            if (comp != 0)
                return comp;
        }

        return compareNumbers(a.length, b.length);
    }

    /**
      do dat type-checking
     **/
    public static macro function isType(value, type) {
        return macro Std.is($value, ${type});
    }

    /**
      Tells whether a value is an "atomic" (true primitive) value
     **/
    public static inline function isAtomic(x: Dynamic):Bool {
        return (
            x.is_null() ||
            x.is_string() ||
            x.is_boolean()||
            x.is_number()
        );
    }

    /**
      check whether the given value is iterable
     **/
    public static inline function isIterable(x: Dynamic):Bool {
        return x.is_iterable();
    }

    /**
      check whether the given value is an iterator
     **/
    public static function isIterator(x: Dynamic):Bool {
        return x.is_iterator();
    }

    public static inline function isBool(x: Dynamic):Bool {
        return x.is_boolean();
    }

    public static inline function isString(x: Dynamic):Bool {
        return x.is_string();
    }

    public static inline function isBinary(x: Dynamic):Bool {
        return x.is_direct_instance( x );
    }

    /**
      Tells if an object is a primitive type or a "real" object
      Arrays are considered primitive
     **/
    public static inline function isPrimitiveType(x: Dynamic):Bool {
        return (
            isBool( x )
            || x.is_number()
            || isString( x )
            || x == null
            || x.is_uarray()
            || x.is_date()
        );
    }

    /**
      check whether the given value is an Array value
     **/
    public static inline function isArray(x: Dynamic):Bool {
        return x.is_uarray();
    }

    /**
      check whether the given value is an Object
     **/
    public static inline function isObject(x: Dynamic):Bool {
        return x.is_anon();
    }

    /**
      check whether the given object is a class instance or a struct
     **/
    public static function getObjectKind(o: Dynamic):ObjectKind {
        return switch (Type.typeof( o )) {
            case TObject: ObjectKind.KAnonymous;
            case TClass(c): ObjectKind.KInstanceof(c);
            default: throw new ValueError(o, 'Not an Object');
        }
    }

    /**
      check whether the given value is a regular expression
     **/
    public static function isRegExp(x: Dynamic):Bool {
        return isType(x, EReg);
    }

    /**
      check whether the given value is a Date
     **/
    public static function isDate(x: Dynamic):Bool {
        return x.is_date();
    }

    /**
      check whether the given value is a function 
     **/
    public static function isFunction(x: Dynamic):Bool {
        return x.is_callable();
    }

    /**
      create and return a deep copy of the given value
     **/
    @:deprecated('use .clone() instead')
    public static function deepCopy<T>(value:T, ?target:T, structs:Bool=true):T {
        return copy(value, target, structs);
    }

    public static function emptyCopy<T>(value: T):T {
        return emptyUntypedCopy( value );
    }

    /**
      create a new value of the same type as [value], but with no data yet attached
     **/
    public static function emptyUntypedCopy(value: Dynamic):Dynamic {
        final vClass:Null<Class<Dynamic>> = Type.getClass( value );
        if (vClass != null) {
            return Type.createEmptyInstance( vClass );
        }
        else {
            return {};
        }
    }

    public static function clone<T>(value:T, ?method:CloneMethod, ensureObjects:Bool=false):T {
        return dclone(value, method);
    }

    public static function dclone(value:Dynamic, ?method:CloneMethod):Dynamic {
        if (method == null)
            method = Shallow;

        if (isAtomic( value ))
            return value;

        if (isDate( value )) {
            final date:Date = cast(value, Date);
            return Date.fromTime(date.getTime());
        }

        if (isObject( value ))
            return clone_object(value, method);

        if (isArray( value ))
            return clone_uarray(cast(value, Array<Dynamic>), method);

        return value;
    }

    public static function clone_object<T>(o:T, ?method:CloneMethod, allObjects:Bool=false):T {
        if (method == null) method = Shallow;

        var cloned: Dynamic;
        final oClass:Null<Class<Dynamic>> = Type.getClass( o );
        switch ( method ) {
            case Shallow:
                if (oClass == null) {
                    cloned = Reflect.copy( o );
                }
                else {
                    cloned = Type.createEmptyInstance(oClass);
                    for (k in Reflect.fields(o)) {
                        Reflect.setField(cloned, k, Reflect.field(o, k));
                    }
                }

            case ShallowRecurse:
                cloned = clone_object(o, Shallow);
                for (k in Reflect.fields(cloned)) {
                    final prop = Reflect.field(cloned, k);
                    Reflect.setField(cloned, k, clone(prop, method));
                }

            case JsonReparse:
                cloned = haxe.Json.parse(haxe.Json.stringify( o ));

            case HxSerialize:
                cloned = haxe.Unserializer.run(haxe.Serializer.run( o ));

            case Custom(cp):
                cloned = cp( o );

            case Deep(meth):
                cloned = clone_object(o, Shallow);
                //for (k in Reflect.fields(cloned)) {
                    //Reflect.setField(cloned, k, clone(Reflect.getField(cloned, k), method));
                //}
                trace('Warning: Not an actual deep-copy');
        }
        return cloned;
    }

    public static function clone_object_onto(src:Object<Dynamic>, dest:Object<Dynamic>, ?fields:Array<String>):Void {
        if (fields == null)
            fields = src.keys();

        for (k in fields) {
            dest[k] = src[k];
        }
    }

    public static function clone_uarray(array:Array<Dynamic>, ?method:CloneMethod):Array<Dynamic> {
        if (method == null) method = Shallow;
        var cloned:Array<Dynamic>;
        switch ( method ) {
            case Shallow:
                cloned = array.copy();

            case ShallowRecurse:
                cloned = array.map(function(x: Dynamic) {
                    return clone(x, ShallowRecurse);
                });

            case JsonReparse:
                cloned = array.map(x -> haxe.Json.parse(haxe.Json.stringify( x )));

            case HxSerialize:
                cloned = array.map(x -> haxe.Unserializer.run(haxe.Serializer.run( x )));

            case Custom(cp):
                cloned = array.map(x -> cp( x ));

            case Deep(meth):
                cloned = array.map(x -> clone(x, meth));
        }
        return cloned;
    }



    /**
      compiles a Regular Expression from a String
     **/
    public static function compileRegexp(pattern:String, ?flags:String):EReg {
        return switch [pattern, flags] {
            case [pattern, null]:
                var literal = ~/~?\/(.+?)\/([igm]+)?/g;
                if (literal.match( pattern )) {
                    switch (literal.matched(2)) {
                        case null|'':
                            flags = '';

                        case x:
                            flags = x;
                    }
                    pattern = literal.matched(1);
                }
                else {
                    flags = '';
                }

                return compileRegexp(pattern, flags);

            case [_, _]:
                return new EReg(pattern, flags);
        }
    }

    #if python
    @:keep 
    @:native('_foo_')
    private static function ensureCloneMethodGeneration(?cm: CloneMethod):CloneMethod {
        if (cm == null) {
            cm = CloneMethod.Custom(function(value) {
                return value;
            });
        }
        return CloneMethod.Deep( cm );
    }
    #end

/* === Variables === */

    private static var dotPathCache:Map<String, DotPath> = new Map();
}

/**
  algorithm used to create copies of values
 **/
@:keep
enum CloneMethod {
    Shallow;
    ShallowRecurse;

    JsonReparse;
    HxSerialize;

    /**
      Custom(fn) allows a custom cloning lambda to be specified. 
      Cloning lambdas are validated by testing:
      <pre><code>
        Arch.areThingsEqual(o, fn(o))
      </code></pre>
     **/
    Custom(fn: Dynamic -> Dynamic);
    Deep(recursionMethod: CloneMethod);
}
