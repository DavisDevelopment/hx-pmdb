package pmdb.ql.ast;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateOp;
import pmdb.ql.ast.ValueResolver.EResolution;
import pmdb.ql.ast.ValueResolver.Resolution;
import pmdb.core.Error;
import pmdb.core.Object;

import haxe.Constraints.Function;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class ValueBuiltins {
    public static function resolve(name:String, args:Array<ValueExpr>):Resolution<Object<Dynamic>, TypedData> {
        return cast Resolution.const((2).typed());
    }

    var ql_functions: Array<String> = [
        'abs(n: Float)',
        'max(x, y):Any',
        'min(x, y):Any',
        'hex(x):String',
        'length(x):Int',
        'random():Float',
        'rtrim(x):Any',
        'trim(x):Any',
        'ltrim(x):Any',
        'upper(x):String',
        'like(column:Any, pattern:Pattern)',
        'lower(x):String',
        'typeof(x):String',
        'instr(x:String, y:String):Bool',
        'substr(x, y, z)'
    ];
}

