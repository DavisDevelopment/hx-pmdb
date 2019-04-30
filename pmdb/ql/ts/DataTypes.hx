package pmdb.ql.ts;

import haxe.rtti.Rtti;
import haxe.rtti.CType;
import haxe.io.Bytes;
import haxe.io.*;

import pmdb.core.TypedValue;
import pmdb.core.Check;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.ql.ts.DataType;

import Slambda.fn;
import Std.is as stdIs;
import Type;

using StringTools;
using pm.Strings;
using pm.Arrays;
using tannus.ds.DictTools;
using pm.Functions;
using pmdb.ql.ts.TypeChecks;

using haxe.rtti.CType.TypeApi;

/**
  mixin module for DataType utility methods
 **/
class DataTypes {
/* === Methods === */

    /**
      checks whether the two given DataTypes unify
     **/
    public static function unifyLeft(left:DataType, right:DataType):Bool {
        return switch ([left, right]) {
            case [TAny|TUnknown|TMono(null), _]: true;
            case [TMono(left), right]: unify(left, right);
            case [TNull(left), right]: left.unifyLeft(right);
            case [TScalar(TString), TClass(String)]: true;
            case [TScalar(TBytes), TClass(bt=haxe.io.Bytes)]: true;
            case [TScalar(TDate), TClass(Date)]: true;
            case [TUnion(left_a, left_b), _]: unifyLeft(left_a, right) || unifyLeft(left_b, right);
            case _: left.equals( right );
        }
    }

    /**
      commutative unification
     **/
    public static inline function unify(a:DataType, b:DataType):Bool {
        return (a == b || a.equals(b) || unifyLeft(a, b) || unifyRight(a, b));
    }

    /**
      right-biased unification
     **/
    public static inline function unifyRight(left:DataType, right:DataType):Bool {
        return unifyLeft(right, left);
    }

    /**
      like [unifyLeft], but returns 'unified' type
     **/
    public static function mergeLeft(left:DataType, right:DataType):DataType {
        return switch ([left, right]) {
            // [Int, String] merges [Int | String]
            case [TTuple([la, lb]), TArray(TUnion(ra, rb))] if (unifyLeft(la, ra) && unifyLeft(lb, rb)): TTuple([la, lb]);
            default: left;
        }
    }

    /**
      DataType normalize/simplify function
     **/
    public static function simplify(type: DataType):DataType {
        return switch type {
            /* Special Cases */
            case TClass(Array): TArray(TUnknown);
            case TClass(String): TScalar(TString);
            case TClass(Date): TScalar(TDate);
            case TClass(haxe.io.Bytes): TScalar(TBytes);
            case TNull(TNull(t)): TNull(simplify(t));
            case TUnion(simplify(_)=>a, simplify(_)=>b) if (unify(a, b)): throw 'Unsupported: simplify (A | B) where (A |= B)';
            case TUnion(TUnknown, type), TUnion(type, TUnknown): TMono(simplify( type ));
            case TUnion(TAny, TNull(_)), TUnion(TNull(_), TAny): TNull(TAny);

            /* Compound-Type Simplification */
            case TAnon(o):
                TAnon(new CObjectType(
                    o.fields.map(function(field) {
                        return new Property(field.name,
                            simplify( field.type ),
                            field.opt
                        );
                    }),
                    o.params != null ? o.params.copy() : null
                ));

            case _: type;
        }
    }

    /**
      generates and returns a lambda that will validate a value against a given type-pattern
     **/
    public static function valueChecker(type: DataType):Dynamic->Bool {
        return switch type {
            case TAny: TypeChecks.is_any;
            case TMono(null): TypeChecks.is_any;
            case TMono(type): valueChecker(type);
            case TUnknown: affirmative;
            case TNull(type) if (type != null): TypeChecks.is_nullable.bind(_, valueChecker(type));
            case TArray(type): TypeChecks.is_array.bind(_, valueChecker(type));
            case TScalar(prim): switch prim {
                case TBoolean: TypeChecks.is_boolean;
                case TInteger: TypeChecks.is_integer;
                case TDouble: TypeChecks.is_double;
                case TString|TBytes: TypeChecks.is_string;
                case TDate: TypeChecks.is_date;
            }
            case _: throw new Error("nope");
        }
    }

    private static function affirmative(x: Dynamic):Bool {
        return true;
    }

    /**
      check that [value]'s type unifies with [type]
     **/
    public static function checkValue(type:DataType, value:Dynamic):Bool {
        return switch type {
            case TVoid|TUndefined: value == null;
            case TAny|TMono(null)|TUnknown: true;
            case TMono(type): checkValue(type, value);
            case TNull(type): (checkValue(type, value) || value == null);
            case TArray(type): value.is_array(x -> checkValue(type, x));
            case TScalar(stype): ScalarDataTypes.checkValue(stype, value);
            case TAnon(null): value.is_anon();
            case TAnon(o): value.is_anon() && checkObjectType(o, value);
            case TUnion(left, right): checkValue(left, value) || checkValue(right, value);
            case TClass(type): stdIs(value, type);
            case TStruct(ss): value.is_anon() && ss.validateStruct( value );
            case TTuple(items): value.is_uarray() && checkTupleType(items, value);
        }
    }

    public static function checkTupleType(items:Array<DataType>, values:Array<Dynamic>):Bool {
        if (items.length != values.length)
            return false;
        for (index in 0...items.length) {
            if (!checkValue(items[index], values[index])) {
                return false;
            }
        }
        return true;
    }

    public static inline function makeNullable(type: DataType):DataType {
        return switch type {
            case TNull(_): type;
            case _: TNull(type);
        }
    }

    /**
      validate a given Object against the given Object-type pattern
     **/
    public static function checkObjectType(type:CObjectType, value:Object<Dynamic>):Bool {
        for (prop in type.fields) {
            if (!checkObjectProperty(prop, value)) {
                return false;
            }
        }
        return true;
    }

    /**
      check a given property of an object
     **/
    public static function checkObjectProperty(property:Property, value:Object<Dynamic>):Bool {
        if (!value.exists(property.name))
            return false;
        return checkValue(property.type, value.get(property.name));
    }

    /**
      given a DataType value [type], produce a Comparator<Dynamic> object that will compare two values of the given type
     **/
    public static function getTypedComparator(type:DataType, guard:Bool=false):Comparator<Dynamic> {
        return switch type {
            case TVoid|TUndefined: throw new Error('Y u want that?');
            case TAny|TMono(_)|TUnknown: Comparator.cany();
            case TScalar(stype): switch stype {
                case TBoolean: Comparator.cboolean();
                case TInteger: Comparator.cint();
                case TDouble: Comparator.cfloat();
                case TString: Comparator.cstring();
                case TDate: Comparator.cdate();
                case TBytes: Comparator.cbytes();
            }
            case TArray(item): Comparator.arrayComparator(getTypedComparator(item));
            case TNull(utype): Comparator.makeNullable(getTypedComparator( utype ));
            case TAnon(otype): Comparator.cany();
            case TClass(ctype): Comparator.cany();
            case TStruct(type): throw 'getTypedComparator(Struct(_), _)) not implemented';
            case TUnion(_, _): throw 'Betty';
            case TTuple(_): throw new Error('ass');
        }
    }

    /**
      get an Equator<Dynamic> for the given DataType
     **/
    public static function getTypedEquator(type: DataType):Equator<Dynamic> {
        //throw 'Unimpl';
        return switch type {
            case TUnknown|TMono(null)|TAny: Equator.anyEq();
            case TScalar(stype): switch stype {
                case TBoolean: Equator.boolEq();
                case TInteger: Equator.intEq();
                case TDouble: Equator.floatEq();
                case TString: Equator.stringEq();
                case TBytes: Equator.bytesEq();
                case TDate: Equator.dateEq();
            }
            case TNull(t): getTypedEquator(t);
            case TArray(et): Equator.typedArrayEquator(getTypedEquator(et));
            default: Equator.anyEq();
        }
    }

    /**
      returns a human-readable representation of the given DataType
     **/
    public static function print(type: DataType):String {
        return switch type {
            case TVoid: 'Void';
            case TUndefined|TUnknown|TMono(null): 'Unknown<?>';
            case TAny: 'Any';
            case TScalar(stype): switch stype {
                case TBoolean: 'Bool';
                case TInteger: 'Int';
                case TDouble: 'Float';
                case TString: 'String';
                case TBytes: 'Bytes';
                case TDate: 'Date';
            }
            case TNull(type): 'Null<${print(type)}>';
            case TArray(type): 'Array<${print(type)}>';
            case TUnion(a, b): 'Either<${print(a)}, ${print(b)}>';
            case TTuple(types): 'Tuple<' + types.map(t -> print(t)).join(', ') + '>';
            case other: throw new Error('print($type) not implemented');
        }
    }

    /**
      convert [v] a TypedData value
     **/
    public static function typed(v: Dynamic):TypedValue {
        return type( v );
    }

    /**
      obtain a TypedValue for [value]
     **/
    public static function type(value: Dynamic):TypedValue {
        if (value.is_instance(TypedValueImpl))
            return cast(value, TypedValueImpl);
        return TypedValue.of( value );
    }

    /**
      check whether [type] is a 'concrete' type
     **/
    public static function isConcrete(type: DataType):Bool {
        return switch type {
            case TUnknown, TMono(_), TUnion(_, _): false;
            case TAnon(null): false;
            case TArray(e): e.isConcrete();
            case TTuple(vals): vals.every(t -> t.isConcrete());
            case TAnon(type): type.fields.every(f -> f.type.isConcrete());
            case TNull(type): type.isConcrete();
            default: true;
        }
    }

/* === Variables === */
}

class ValueTypes {
    /**
      convert the given ValueType into a DataType value
     **/
    public static inline function toDataType(type: ValueType):DataType {
        //if (v2dCache.exists( type ))
            //return v2dCache[type];
        //return v2dCache[type] = _toDataType(type);
        return _toDataType( type );
    }
    
    /**
      
     **/
    static function _toDataType(type: ValueType):DataType {
        switch (type) {
            case TUnknown|TNull|TFunction:
                return TAny;

            case TBool:
                return TScalar(TBoolean);

            case TInt:
                return TScalar(TInteger);

            case TFloat:
                return TScalar(TDouble);

            case TObject:
                return TAnon(null);

            case TClass(String):
                return TScalar(TString);

            case TClass(Date):
                return TScalar(TDate);

            case TClass(Array):
                return TArray(TAny);

            case TClass(type):
                return TAnon(null);

            case _:
                return TAny;
        }
    }
}

class ScalarDataTypes {
    public static function getTypedComparator(type: ScalarDataType):Comparator<Dynamic> {
        return switch type {
            case TBoolean: Comparator.cboolean();
            case TInteger: Comparator.cint();
            case TDouble: Comparator.cfloat();
            case TDate: Comparator.cdate();
            case TString: Comparator.cstring();
            case TBytes: Comparator.cbytes();
        }
    }

    public static function checkValue(type:ScalarDataType, value:Dynamic):Bool {
        return switch type {
            case TBoolean: value.is_boolean();
            case TInteger: value.is_integer();
            case TDouble: value.is_double();
            case TString: value.is_string();
            case TBytes: stdIs(value, Bytes);
            case TDate: value.is_date();
        }
    }
}

class Anons {
    /**
      obtain the DataType that seems to be associated with [value]
     **/
    public static function dataTypeOf(value: Dynamic):DataType {
        return ValueTypes.toDataType(Type.typeof( value ));
    }
}

class ComplexTypes {

}
