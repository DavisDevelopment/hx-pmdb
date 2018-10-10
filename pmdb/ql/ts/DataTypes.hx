package pmdb.ql.ts;

import tannus.ds.Anon;
import tannus.ds.Dict;
import tannus.ds.Pair;
import tannus.ds.Set;

import haxe.rtti.Rtti;
import haxe.rtti.CType;

import pmdb.core.Check;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Error;
import pmdb.ql.ts.DataType;

import Slambda.fn;
import Std.is as stdIs;
import Type;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.MapTools;
using tannus.ds.DictTools;
using tannus.FunctionTools;

using haxe.rtti.CType.TypeApi;

/**
  mixin module for DataType utility methods
 **/
class DataTypes {
/* === Methods === */

    /**
      generates and returns a lambda that will validate a value against a given type-pattern
     **/
    public static function valueChecker(type: DataType):Dynamic->Bool {
        return switch type {
            case TAny: TypeChecks.is_any;
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

    /**
      check that [value]'s type unifies with [type]
     **/
    public static function checkValue(type:DataType, value:Dynamic):Bool {
        return switch type {
            case TAny: true;
            case TNull(type): (value == null || checkValue(type, value));
            case TArray(type): (stdIs(value, Array) && cast(value, Array<Dynamic>).all(function(item: Dynamic) {
                return checkValue(type, item);
            }));
            case TScalar(stype): switch stype {
                case TBoolean: stdIs(value, Bool);
                case TInteger: stdIs(value, Int);
                case TDouble: stdIs(value, Float);
                case TString|TBytes: stdIs(value, String);
                case TDate: (stdIs(value, Date) || stdIs(value, Float));
            }
            case TAnon(null): Reflect.isObject( value );
            case TAnon(o): Reflect.isObject(value) && checkObjectType(o, value);
            case TUnion(left, right): checkValue(left, value) || checkValue(right, value);
            case TClass(type): type.isInstance( value );
            case TStruct(type): throw 'checkValue(Struct(_), _)) not implemented';
        }
    }

    /**
      validate a given Object against the given Object-type pattern
     **/
    public static function checkObjectType(type:CObjectType, value:Anon<Dynamic>):Bool {
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
    public static function checkObjectProperty(property:Property, value:Anon<Dynamic>):Bool {
        if (!value.exists(property.name))
            return false;
        return checkValue(property.type, value.get(property.name));
    }

    /**
      given a DataType value [type], produce a Comparator<Dynamic> object that will compare two values of the given type
     **/
    public static function getTypedComparator(type:DataType, guard:Bool=false):Comparator<Dynamic> {
        return switch type {
            case TAny: Comparator.cany();
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
        }
    }

    public static function typed(v: Dynamic):TypedData {
        return switch Type.typeof( v ) {
            case TNull: DNull;
            case TUnknown|ValueType.TFunction: DAny(v);
            case TInt: DInteger(cast(v, Int));
            case TFloat: DDouble(cast(v, Float));
            case TBool: DBoolean(cast(v, Bool));
            case TClass(Array): DArray(cast(v, Array<Dynamic>).map( typed ));
            case TClass(Date): DDate(cast(v, Date));
            case TClass(haxe.io.Bytes): DBytes(cast(v, haxe.io.Bytes));
            case TClass(cl): TypedData.DClass(cl, cast v);
            case TEnum(e): TypedData.DEnum(e, cast v);
            case TObject: DObject([for (k in Reflect.fields(v)) {name:k, value:typed(Reflect.field(v, k))}]);
    
        }
    }

/* === Variables === */
}

class ValueTypes {
    static var v2dCache:Dict<ValueType, DataType> = new Dict();

    /**
      convert the given ValueType into a DataType value
     **/
    public static function toDataType(type: ValueType):DataType {
        if (v2dCache.exists( type ))
            return v2dCache[type];
        return v2dCache[type] = _toDataType(type);
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

class Anons {
    public static inline function dataTypeOf(value: Dynamic):DataType {
        return ValueTypes.toDataType(Type.typeof( value ));
    }
}

/**
  simple-static methods for type-checking
 **/
@:noUsing
private class TypeChecks {
    public static inline function is_any(v: Dynamic):Bool {
        return true;
    }

    public static inline function is_primitive(v: Dynamic):Bool {
        return (is_boolean(v) || is_number(v) || is_string(v) || is_date(v));
    }

    public static inline function is_boolean(v: Dynamic):Bool {
        return (v is Bool);
    }

    public static inline function is_number(v: Dynamic):Bool {
        return (v is Float) || (v is Int);
    }

    public static inline function is_double(v: Dynamic):Bool {
        return (v is Float);
    }

    public static inline function is_integer(v: Dynamic):Bool {
        return (v is Int);
    }

    public static inline function is_string(v: Dynamic):Bool {
        return (v is String);
    }

    public static inline function is_date(v: Dynamic):Bool {
        return (v is Date);
    }

    public static inline function is_nullable(v:Dynamic, check_type:Dynamic->Bool):Bool {
        return (v == null || check_type( v ));
    }

    public static inline function is_union(v:Dynamic, check_left:Dynamic->Bool, check_right:Dynamic->Bool):Bool {
        return (check_left( v ) || check_right( v ));
    }

    public static inline function is_anon(v: Dynamic):Bool {
        return Reflect.isObject( v );
    }

    public static inline function is_struct(v:Dynamic, o:CObjectType):Bool {
        return (is_anon(v) && (o.fields.length == 0 || checkStruct(v, o.fields.iterator())));
    }

    private static function checkStruct(v:Dynamic, props:Iterator<Property>):Bool {
        if (!props.hasNext()) return true;
        return DataTypes.checkObjectProperty(props.next(), v) && checkStruct(v, props);
    }

    public static inline function is_uarray(v: Dynamic):Bool {
        return stdIs(v, Array);
    }

    public static function is_array(v:Dynamic, check_type:Dynamic->Bool):Bool {
        return (is_uarray(v) && checkArray(cast(v, Array<Dynamic>), check_type, 0));
    }

    static function checkArray(array:Array<Dynamic>, check:Dynamic->Bool, index:Int):Bool {
        if (array.length == 0) return true;
        if (index < 0 || index >= array.length)
            throw new Error('index outside range(0, ${array.length - 1})');
        return check(array[index]) && checkArray(array, check, ++index);
    }
}
