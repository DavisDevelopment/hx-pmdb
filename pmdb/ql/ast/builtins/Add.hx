package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ts.TypedData;
import pmdb.ql.ast.BuiltinFunction;
import pmdb.core.Error;
import pmdb.ql.ts.TypeSystemError;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Add extends BuiltinFunction {
    public function new() {
        super('__add__');
        //super('__add__', [
            //'Float->Float->Float' => _num_num,
            //'Float->Any->Float' => _num,
            //'Array->Any->Array' => _list,
            //'String->Any->String' => _string,
            //'Date->Date->Date' => _date_date,
            //'Date->Float->Date' => _date_num
        //]);
    }

/* === Methods === */

    override function apply(args: Array<TypedData>):TypedData {
        switch ( args ) {
            case [DNull, _], [_, DNull]:
                throw new InvalidOperation(operation(args, 'addition with Null operands not supported'));

            case [DInt(x), DInt(y)]:
                return DInt(x + y);

            case [DFloat(x), DFloat(y)|DInt((_:Float) => y)]:
                return DFloat(x + y);

            case [DInt((_:Float)=>x), DFloat(y)]:
                return DFloat(x + y);

            case [DArray(t, list), x]:
                return DArray(t, list.withAppend(x.getUnderlyingValue()));

            case [DClass(String, (_:String)=>x), _.getUnderlyingValue()=>y]:
                return DClass(String, Std.string(x + y));

            case [DClass(Date, (_:Date).getTime()=>x), DFloat(y)|DInt(y)|DClass(Date, (_:Date).getTime()=>y)]:
                return DClass(Date, Date.fromTime(x + y));

            case [x, y]:
                //throw 'TypeError: Invalid operation $x + $y';
                throw new InvalidOperation(operation(args, '$x + $y'));

            case many:
                return many.reduceInit(function(a:TypedData, b:TypedData) {
                    return #if macro apply([a, b]); #else call(a, b); #end
                });
        }
    }

    static inline function operation(operands:Array<TypedData>, ?reason:String) {
        return {
            op: '+',
            operands: operands,
            reason: reason
        };
    }

    static inline function _num_num(x:Float, y:Float):Float {
        return x + y;
    }

    static inline function _num(x:Float, y:Dynamic):Float {
        if ((y is Float)) {
            return _num_num(x, cast(y, Float));
        }
        else return Math.NaN;
    }

    static inline function _list(x:Array<Dynamic>, y:Dynamic):Array<Dynamic> {
        if ((y is Array<Dynamic>))
            return x.concat(cast y);
        else return x.withAppend( y );
    }

    static inline function _string(x:String, y:Dynamic):String return x + y;

    static inline function _date_date(x:Date, y:Date):Date {
        return Date.fromTime(x.getTime() + y.getTime());
    }

    static inline function _date_num(x:Date, y:Float):Date {
        return _date_date(x, Date.fromTime( y ));
    }
}
