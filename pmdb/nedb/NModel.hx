package pmdb.nedb;

import haxe.DynamicAccess;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import Std.is as isType;

import pmdb.core.Error;

using Slambda;
using StringTools;

/**
  direct, one-to-one port of nedb's "lib/model.js" module without any type-safety 
  or changes to code's structure that aren't necessary to make it compile
 **/
class NModel {
    /**
      Tell if a given document matches a query
      @param {Object} obj Document to check
      @param {Object} query
     **/
    public static function match(obj:Dynamic, query:Dynamic):Bool {
        //var queryKeys, queryKey, queryValue, i;
        var queryKeys: Array<String>,
            queryKey: String,
            queryValue: Dynamic,
            i: Int;

        // Primitive query against a primitive type
        // This is a bit of a hack since we construct an object with an arbitrary key only to dereference it later
        // But I don't have time for a cleaner implementation now
        if (isPrimitiveType(obj) || isPrimitiveType(query)) {
            return matchQueryPart({needAKey: obj}, 'needAKey', query);
        }

        // Normal query
        queryKeys = Reflect.fields( query );
        //for (i = 0; i < queryKeys.length; i += 1) {
        for (i in 0...queryKeys.length) {
            queryKey = queryKeys[i];
            queryValue = Reflect.field(query, queryKey);

            //if (queryKey[0] === '$') {
            if (isDollarKey( queryKey )) {
                //if (!logicalOperators[queryKey]) { throw new Error("Unknown logical operator " + queryKey); }
                if (!logicalOps.exists(queryKey)) {
                    throw new Error('Unknown logical operator $queryKey');
                }
                //if (!logicalOperators[queryKey](obj, queryValue)) { return false; }
                if (!logicalOps.get(queryKey)(obj, queryValue)) {
                    return false;
                }
            } 
            else {
                if (!matchQueryPart(obj, queryKey, queryValue)) {
                    return false; 
                }
            }
        }

        return true;
    }

    //function matchQueryPart (obj, queryKey, queryValue, treatObjAsValue) {
    public static function matchQueryPart(obj:DynamicAccess<Dynamic>, queryKey:String, queryValue:Dynamic, treatObjAsValue:Bool=false):Bool {
        //var objValue = getDotValue(obj, queryKey)
            //, i, keys, firstChars, dollarFirstChars;
        var objValue = getDotValue(obj, queryKey),
            i: Int,
            keys: Array<String>,
            firstChars: Array<String>,
            dollarFirstChars: Array<String>;

        /* Check if the value is an array if we don't force a treatment as value */
        //if (util.isArray(objValue) && !treatObjAsValue) {
        if (isType(objValue, Array) && !treatObjAsValue) {
            // If the queryValue is an array, try to perform an exact match
            /*if (util.isArray(queryValue)) {
                return matchQueryPart(obj, queryKey, queryValue, true);
            }*/
            if (isType(queryValue, Array)) {
                return matchQueryPart(obj, queryKey, queryValue, true);
            }

            // Check if we are using an array-specific comparison function
            //if (queryValue !== null && typeof queryValue === 'object' && !util.isRegExp(queryValue)) {
            if (queryValue != null && isObject(queryValue) && !isRegExp(queryValue)) {
                //keys = Object.keys(queryValue);
                keys = Reflect.fields( queryValue );
                //for (i = 0; i < keys.length; i += 1) {
                for (i in 0...keys.length) {
                    //if (arrayComparisonFunctions[keys[i]]) {
                    if (arrayComparisonOps.exists(keys[i])) {
                        return matchQueryPart(obj, queryKey, queryValue, true);
                    }
                }
            }

            // If not, treat it as an array of { obj, query } where there needs to be at least one match
            var objValue:Array<Dynamic> = cast objValue;
            for (i in 0...objValue.length) {
                if (matchQueryPart({k: objValue[i]}, 'k', queryValue)) {   // k here could be any string
                    return true; 
                }
            }

            return false;
        }

        // queryValue is an actual object. Determine whether it contains comparison operators
        // or only normal fields. Mixed objects are not allowed
        /*if (queryValue !== null && typeof queryValue === 'object' && !util.isRegExp(queryValue) && !util.isArray(queryValue)) {
            keys = Object.keys(queryValue);
            firstChars = _.map(keys, function (item) { return item[0]; });
            dollarFirstChars = _.filter(firstChars, function (c) { return c === '$'; });*/
        if (queryValue != null && isObject(queryValue) && !isRegExp(queryValue) && isType(queryValue, Array)) {
            keys = Reflect.fields( queryValue );
            firstChars = keys.map.fn(_.charAt(0));
            dollarFirstChars = firstChars.filter.fn("$" == _);

            /*if (dollarFirstChars.length !== 0 && dollarFirstChars.length !== firstChars.length) {
                throw new Error("You cannot mix operators and normal fields");
            }*/
            if (dollarFirstChars.length != 0 && dollarFirstChars.length != firstChars.length) {
                throw new pmdb.core.Error("You cannot mix operators and normal fields");
            }

            // queryValue is an object of this form: { $comparisonOperator1: value1, ... }
            if (dollarFirstChars.length > 0) {
                //for (i = 0; i < keys.length; i += 1) {
                for (i in 0...keys.length) {
                    //if (!comparisonFunctions[keys[i]]) { throw new Error("Unknown comparison function " + keys[i]); }
                    if (!comparisonOps.exists(keys[i])) {
                        throw new Error('Unknown comparison function ${keys[i]}');
                    }

                    //if (!comparisonFunctions[keys[i]](objValue, queryValue[keys[i]])) { return false; }
                    if (!comparisonOps[keys[i]](objValue, (queryValue : DynamicAccess<Dynamic>)[keys[i]])) {
                        return false;
                    }
                }
                return true;
            }
        }

        // Using regular expressions with basic querying
        //if (util.isRegExp(queryValue)) { return comparisonFunctions.$regex(objValue, queryValue); }
        if (isRegExp(queryValue)) {
            return comparisonOps["$regex"](objValue, queryValue);
        }

        // queryValue is either a native value or a normal object
        // Basic matching is possible
        if (!areThingsEqual(objValue, queryValue)) {
            return false;
        }

        return true;
    }

    //function getDotValue (obj, field) {
    public static function getDotValue(obj:DynamicAccess<Dynamic>, field:EitherType<String, Array<String>>):Dynamic {
        //var fieldParts = typeof field === 'string' ? field.split('.') : field
            //, i, objs;
        var fieldParts:Array<String> = isType(field, String) ? (field : String).split('.') : cast (field : Array<Dynamic>);
        var i: Int,
        objs : Array<Dynamic>;
            
        // field cannot be empty so that means we should return undefined so that nothing can match
        //if (!obj) { return undefined; }   
        if (obj == null)
            return null;

        //if (fieldParts.length === 0) { return obj; }
        if (fieldParts.length == 0)
            return obj;

        //if (fieldParts.length === 1) { return obj[fieldParts[0]]; }
        if (fieldParts.length == 1)
            return obj.get(fieldParts[0]);

        // if the value at the given dot-path is an array
        //if (util.isArray(obj[fieldParts[0]])) {
        if (isType(obj[fieldParts[0]], Array)) {
            inline function av():Array<Dynamic> return cast(obj[fieldParts[0]], Array<Dynamic>);
            // If the next field is an integer, return only this item of the array
            //i = parseInt(fieldParts[1], 10);
            i = Std.parseInt(fieldParts[1]);
            /*
            if (typeof i === 'number' && !isNaN(i)) {
                return getDotValue(obj[fieldParts[0]][i], fieldParts.slice(2))
            } */
            if (isType(i, Int) && !Math.isNaN( i ))
                return getDotValue(cast(obj[fieldParts[0]], Array<Dynamic>)[i], fieldParts.slice(2));


            // Return the array of values
            objs = new Array();
            /*
            for (i = 0; i < obj[fieldParts[0]].length; i += 1) {
                //[= Broken Up For Clarity =]
                objs.push(
                   getDotValue(
                      obj[fieldParts[0]][i],
                      fieldParts.slice(1)
                   )
                );
            }
            */
            i = 0;
            while (i < cast(obj[fieldParts[0]], Array<Dynamic>).length) {
                objs.push(getDotValue(av()[i], fieldParts.slice(1)));
                ++i;
            }
            return objs;
        } 
        else {
            return getDotValue(obj[fieldParts[0]], fieldParts.slice(1));
        }
    }

    /**
      Check whether 'things' are equal
      Things are defined as any native types (string, number, boolean, null, date) and objects
      In the case of object, we check deep equality
      Returns true if they are, false otherwise
     **/
    //function areThingsEqual (a, b) {
    public static function areThingsEqual(a:Dynamic, b:Dynamic):Bool {
        //var aKeys , bKeys , i;
        var i: Int,
            aKeys: Array<String>,
            bKeys: Array<String>;

        // Strings, booleans, numbers, null
        /*if (a === null || typeof a === 'string' || typeof a === 'boolean' || typeof a === 'number' ||
            b === null || typeof b === 'string' || typeof b === 'boolean' || typeof b === 'number') { return a === b; }*/
        if (isAtomic( a ) || isAtomic( b )) {
            return (a == b);
        }

        // Dates
        //if (util.isDate(a) || util.isDate(b)) { return util.isDate(a) && util.isDate(b) && a.getTime() === b.getTime(); }
        if (isDate( a ) || isDate( b )) {
            return (isDate( a ) && isDate( b )) && (a.getTime() == b.getTime()); 
        }

        // Arrays (no match since arrays are used as a $in)
        // undefined (no match since they mean field doesn't exist and can't be serialized)
        //if ((!(util.isArray(a) && util.isArray(b)) && (util.isArray(a) || util.isArray(b))) || a === undefined || b === undefined) { return false; }
        if ((!(isType(a, Array) && isType(b, Array)) && (isType(a, Array) || isType(b, Array))) || a == null || b == null) {
            return false;
        }

        // General objects (check for deep equality)
        // a and b should be objects at this point
        /*try {
            aKeys = Object.keys(a);
            bKeys = Object.keys(b);
        } catch (e) {
            return false;
        }*/
        aKeys = bKeys = [];
        try {
            aKeys = Reflect.fields( a );
            bKeys = Reflect.fields( b );
            if (aKeys == null || bKeys == null)
                throw new Error("assert");
        }
        catch (e: Dynamic) {
            return false;
        }

        if (aKeys.length != bKeys.length) {
            return false; 
        }
        //for (i = 0; i < aKeys.length; i += 1) {
        for (i in 0...aKeys.length) {
            //if (bKeys.indexOf(aKeys[i]) === -1) { return false; }
            if (bKeys.indexOf(aKeys[i]) == -1) {
                return false;
            }

            if (!areThingsEqual(Reflect.field(a, aKeys[i]), Reflect.field(b, aKeys[i]))) {
                return false;
            }
        }

        return true;
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

    /**
      check whether the given value is an Object
     **/
    public static inline function isObject(x: Dynamic):Bool {
        return Reflect.isObject( x );
    }

    /**
      check whether the given value is a RegExp (Regular Expression)
     **/
    public static inline function isRegExp(x: Dynamic):Bool {
        #if hre
        return isType(x, EReg) || isType(x, hre.RegExp) #if js || isType(x, js.RegExp) #end;
        #else
        return isType(x, EReg) #if js || isType(x, js.RegExp) #end;
        #end
    }

    /**
      check whether the given value is a Date/Datetime
     **/
    public static inline function isDate(x: Dynamic):Bool {
        return isType(x, Date);
    }

    /**
      check whether the given String starts with a dollar-sign ($)
     **/
    public static inline function isDollarKey(k: String):Bool {
        return (k.charAt(0) == "$");
    }

/* === Operator Methods === */

    /**
      add an operator function to the given Map under the given key
     **/
    static function _op_<T>(m:Map<String, T>, n:String, f:T) {
        m.set(n, f);
    }

    /**
      add a logical operator to the registry
     **/
    inline static function logop(n:String, f:Function) {
        _op_(logicalOps, n, f);
    }

    /**
      add a binary operator to the registry
     **/
    inline static function binop(n:String, f:Function) {
        _op_(comparisonOps, n, f);
    }

    /**
      define the implementations for all the operators
     **/
    private static function ops() {
        _logic_();
        _comparisons_();
    }

    /**
      define implementations for logical operators
     **/
    private static function _logic_() {
        logop("$and", logop_and);
        logop("$or", logop_or);
        logop("$not", logop_not);
        //logop("$where", logop_where);
    }

    /**
      define implementations for comparison operators
     **/
    private static function _comparisons_() {
        //TODO
    }

    static function __init__() {
        logicalOps = new Map();
        comparisonOps = new Map();
        arrayComparisonOps = new Map();

        ops();
    }

    /**
      AND (&&) Operator
     **/
    private static function logop_and(o:Dynamic, query:Array<Dynamic>):Bool {
        if (!isType(query, Array)) {
            throw new Error("$and operator used without an array");
        }
        if (query.length == 0) {
            return false;
        }
        if (query.length == 1) {
            return match(o, query[0]);
        }
        else {
            //var res = match(o, query[0]);
            if (!match(o, query[0])) {
                return false;
            }
            return logop_and(o, query.slice(1));
        }
    }

    /**
      OR (||) Operator
     **/
    private static function logop_or(o:Dynamic, query:Array<Dynamic>):Bool {
        if (!isType(query, Array)) {
            throw new Error("$and operator used without an array");
        }
        if (query.length == 0) {
            return false;
        }
        if (query.length == 1) {
            return match(o, query[0]);
        }
        else {
            if (match(o, query[0])) {
                return true;
            }
            return logop_or(o, query.slice(1));
        }
    }

    /**
      NOT (!) Operator
     **/
    private static function logop_not(o:Dynamic, query:Dynamic):Bool {
        return !match(o, query);
    }

    public static var logicalOps: Map<String, Function>;
    public static var comparisonOps: Map<String, Function>;
    public static var arrayComparisonOps: Map<String, Dynamic>;
}
