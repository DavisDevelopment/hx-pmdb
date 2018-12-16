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

class TypeChecks {
    #if !no_inline_typechecks inline #end
    public static function is_null(v: Dynamic):Bool {
        return (v == null);
    }

    #if !no_inline_typechecks inline #end
    public static function is_any(v: Dynamic):Bool {
        return !is_null( v );
    }

    #if !no_inline_typechecks inline #end
    public static function is_primitive(v: Dynamic):Bool {
        return (is_boolean(v) || is_number(v) || is_string(v) || is_date(v));
    }

    #if !no_inline_typechecks inline #end
    public static function is_boolean(v: Dynamic):Bool {
        return (v is Bool);
    }

    #if !no_inline_typechecks inline #end
    public static function is_number(v: Dynamic):Bool {
        return (v is Float) || (v is Int);
    }

    #if !no_inline_typechecks inline #end
    public static function is_double(v: Dynamic):Bool {
        return (v is Float);
    }

    #if !no_inline_typechecks inline #end
    public static function is_integer(v: Dynamic):Bool {
        return (v is Int);
    }

    #if !no_inline_typechecks inline #end
    public static function is_instance(v:Dynamic, type:Class<Dynamic>):Bool {
        return Std.is(v, type);
    }

    #if !no_inline_typechecks inline #end
    public static function is_direct_instance(v:Dynamic, type:Class<Dynamic>):Bool {
        return (Type.getClass( v ) == type);
    }

    #if !no_inline_typechecks inline #end
    public static function is_enumvalue(v:Dynamic, type:Enum<EnumValue>):Bool {
        return Std.is(v, type);
    }

    #if !no_inline_typechecks inline #end
    public static function is_string(v: Dynamic):Bool {
        return (v is String);
    }

    #if !no_inline_typechecks inline #end
    public static function is_date(v: Dynamic):Bool {
        return (v is Date);
    }

    #if !no_inline_typechecks inline #end
    public static function is_nullable(v:Dynamic, check_type:Dynamic->Bool):Bool {
        return (v == null || check_type( v ));
    }

    #if !no_inline_typechecks inline #end
    public static function is_union(v:Dynamic, check_left:Dynamic->Bool, check_right:Dynamic->Bool):Bool {
        return (check_left( v ) || check_right( v ));
    }

    #if !no_inline_typechecks inline #end
    public static function is_anon(v: Dynamic):Bool {
        return Reflect.isObject( v );
    }

    public static function is_struct(v:Dynamic, o:CObjectType):Bool {
        if (!is_anon( v ))
            return false;
        for (field in o.fields) {
            if (!DataTypes.checkObjectProperty(field, v)) {
                return false;
            }
        }
        return true;
    }

    #if !no_inline_typechecks inline #end
    public static function is_uarray(v: Dynamic):Bool {
        return stdIs(v, Array);
    }

    public static function is_array(v:Dynamic, check_type:Dynamic->Bool):Bool {
        //return (is_uarray(v) && checkArray(cast(v, Array<Dynamic>), check_type, 0));
        if (!is_uarray( v ))
            return false;
        var v:Array<Dynamic> = cast v;
        for (elem in v) {
            if (!check_type( elem )) {
                return false;
            }
        }
        return true;
    }

    #if !no_inline_typechecks inline #end
    public static function is_callable(v: Dynamic):Bool {
        return Reflect.isFunction( v );
    }

    #if !no_inline_typechecks inline #end
    public static function has_method(o:Dynamic, m:String):Bool {
        return is_callable(Reflect.field(o, m));
    }

    #if !no_inline_typechecks inline #end
    public static function is_iterable(o: Dynamic):Bool {
        return is_anon(o) && has_method(o, 'iterator');
    }

    #if !no_inline_typechecks inline #end
    public static function is_iterator(o: Dynamic):Bool {
        return (
            is_anon( o ) &&
            has_method(o, 'hasNext') &&
            has_method(o, 'next')
        );
    }

    public static inline function valuetype(v: Dynamic):ValueType {
        return Type.typeof( v );
    }

    //#if !no_inline_typechecks inline #end
    public static function classof<T>(instance: T):Null<Class<T>> {
        var type = valuetype( instance );
        return switch (type) {
            case TClass(classType): (cast classType : Class<T>);
            default: null;
        }
    }

    public static function sametypeas(b:Dynamic, a:Dynamic):Bool {
        /*TODO make this method work for any type */
        var aClass:Class<Dynamic>, bClass:Class<Dynamic>;
        aClass = classof( a );
        
        if (aClass == null) return classof( b ) == null;
        bClass = classof( b );
        if (bClass == null) return (aClass == null);
        return stdIs(b, aClass);
    }
}
