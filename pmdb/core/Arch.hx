package pmdb.core;

import tannus.ds.*;
import tannus.io.*;
import tannus.math.TMath as M;

import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Check;

import haxe.DynamicAccess;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.CallStack;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

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
      resolve the given dot-path
     **/
    public static function getDotValue(o:DynamicAccess<Dynamic>, field:String):Dynamic {
        // not yet its own implementation
        return pmdb.nedb.NModel.getDotValue(o, field);
    }

    /**
      Tells whether a value is an "atomic" (true primitive) value
     **/
    public static inline function isAtomic(x: Dynamic):Bool {
        return (x == null || isType(x, String) || isType(x, Bool) || isType(x, Float));
    }

    /**
      Tells if an object is a primitive type or a "real" object
      Arrays are considered primitive
     **/
    public static function isPrimitiveType(x: Dynamic):Bool {
        return (
            isType(x, Bool)
            || isType(x, Float)
            || isType(x, String)
            || x == null
            || isType(x, Array)
            || isType(x, Date)
        );
    }

    public static inline function isArray(x: Dynamic):Bool {
        return isType(x, Array);
    }

    public static inline function isObject(x: Dynamic):Bool {
        return Reflect.isObject( x );
    }

    public static inline function isRegExp(x: Dynamic):Bool {
        #if hre
        return isType(x, EReg) || isType(x, hre.RegExp);
        #else
        return isType(x, EReg);
        #end
    }

    public static inline function isDate(x: Dynamic):Bool {
        return isType(x, Date);
    }
}
