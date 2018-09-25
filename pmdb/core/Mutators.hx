package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Cursor;
import pmdb.core.QueryFilter;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
//using pmdb.ql.types.DataTypes;

class Mutators {}

class MOps {
    /**
      property assignment
     **/
    public static function ls_op_set(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        obj[field] = value;
    }

    /**
      property deletion
     **/
    public static function ls_op_unset(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        obj.remove( field );
    }

    private static inline function _listop(obj:Anon<Dynamic>, field:String, fn:Array<Dynamic>->Void) {
        if (!obj.exists( field ))
            obj[field] = new Array();

        if (!Arch.isArray(obj[field]))
            throw new Error('"$field" property is a non-array');

        var arr:Array<Dynamic> = cast obj[field];
        return fn( arr );
    }

    /**
      appending of value(s) to array field
     **/
    public static function ls_op_push(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        _listop(obj, field, function(arr) {
            arr.push( value );
        });
    }

    public static function ls_op_addToSet(o:Anon<Dynamic>, field:String, value:Dynamic) {
        _listop(o, field, function(arr) {
            var add = true;
            for (v in arr) {
                if (Arch.compareThings(v, value) == 0) {
                    add = false;
                }
            }
            if ( add ) {
                arr.push( value );
            }
        });
    }

    public static function ls_op_pop(o:Anon<Dynamic>, field:String, value:Dynamic) {
        _listop(o, field, function(arr) {
            if (!isType(value, Float))
                throw new Error(value + " isn't an integer. Integers must be used with $pop");
            
            switch Std.int(cast(value, Float)) {
                case 0:
                    return ;

                case v:
                    if (v > 0) {
                        o[field] = arr.slice(0, arr.length - 1);
                    }
                    else {
                        o[field] = arr.slice(1);
                    }
            }
        });
    }

    public static function ls_op_pull(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        //
    }

    public static function ls_op_inc(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        //
    }

    public static function ls_op_max(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        //
    }

    public static function ls_op_min(obj:Anon<Dynamic>, field:String, value:Dynamic) {
        //
    }

    /**
      
     **/
    public static function mutOpFunc(mod: String):Anon<Dynamic>->EitherType<Array<String>, String>->Dynamic->Void {
        return (function(obj:Anon<Dynamic>, field:EitherType<Array<String>, String>, value:Dynamic):Void {
            var fieldParts:Array<String> = (isType(field, String) ? cast(field, String).split('.') : cast field);
            if (fieldParts.length == 1) {
                lastStepModifierFuncs[mod](obj, cast field, value);
            }
            else {
                if (!obj.exists(fieldParts[0])) {
                    if (mod == 'unset')
                        return ;
                    obj[fieldParts[0]] = {};
                }
                modifierFuncs[mod](obj[fieldParts[0]], fieldParts.slice(1), value);
            }
        });
    }

    static function __init__() {
        lastStepModifierFuncs = [
            "set" => ls_op_set,
            'unset' => ls_op_unset,
            'push' => ls_op_push
        ];

        modifierFuncs = [for (key in lastStepModifierFuncs.keys()) key => mutOpFunc( key )];
    }

    static var modifierFuncs(default, null): Map<String, Anon<Dynamic>->EitherType<Array<String>,String>->Dynamic->Void>;
    static var lastStepModifierFuncs(default, null): Map<String, Anon<Dynamic>->String->Dynamic->Void>;
}
