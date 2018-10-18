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
import tannus.ds.AnonTools.deepCopy as copy;
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

    public static function setDotValue(o:DynamicAccess<Dynamic>, field:String, value:Dynamic):Void {
        return pmdb.nedb.NModel.setDotValue(o, field, value);
    }

    /**
      check whether the two given values can be considered equivalent
     **/
    public static inline function areThingsEqual(left:Dynamic, right:Dynamic):Bool {
        return pmdb.nedb.NModel.areThingsEqual(left, right);
    }

    /**
      numerically compare the two given values
     **/
    public static inline function compareThings(left:Dynamic, right:Dynamic):Int {
        return SortingTools.compareAny(left, right);
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
        return (x == null || isType(x, String) || isType(x, Bool) || isType(x, Float));
    }

    /**
      check whether the given value is iterable
     **/
    public static function isIterable(x: Dynamic):Bool {
        return (
            isObject( x )
            && isFunction( x.iterator )
        );
    }

    /**
      check whether the given value is an iterator
     **/
    public static function isIterator(x: Dynamic):Bool {
        return (
            isObject( x ) &&
            (Reflect.hasField(x, 'hasNext') && Reflect.hasField(x, 'next')) &&
            (isFunction(x.hasNext) && isFunction(x.next))
        );
    }

    public static function isBool(x: Dynamic):Bool {
        return isType(x, Bool);
    }

    public static function isString(x: Dynamic):Bool {
        return isType(x, String);
    }

    public static function isBinary(x: Dynamic):Bool {
        return isType(x, haxe.io.Bytes);
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

    /**
      check whether the given value is an Array value
     **/
    public static inline function isArray(x: Dynamic):Bool {
        return isType(x, Array);
    }

    /**
      check whether the given value is an Object
     **/
    public static inline function isObject(x: Dynamic):Bool {
        return Reflect.isObject( x );
    }

    /**
      check whether the given value is a regular expression
     **/
    public static inline function isRegExp(x: Dynamic):Bool {
        #if hre
        return isType(x, EReg) || isType(x, hre.RegExp);
        #else
        return isType(x, EReg);
        #end
    }

    /**
      check whether the given value is a Date
     **/
    public static inline function isDate(x: Dynamic):Bool {
        return isType(x, Date);
    }

    /**
      check whether the given value is a function 
     **/
    public static inline function isFunction(x: Dynamic):Bool {
        return Reflect.isFunction( x );
    }

    /**
      create and return a deep copy of the given value
     **/
    public static function deepCopy<T>(value:T, ?target:T, structs:Bool=true):T {
        return copy(value, target, structs);
    }
}
