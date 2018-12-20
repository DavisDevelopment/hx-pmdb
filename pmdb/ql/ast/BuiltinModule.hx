package pmdb.ql.ast;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSignature;
import pmdb.ql.ts.TypedData;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.ql.ast.nodes.*;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.DynamicAccess;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

@:access( pmdb.ql.ast.BuiltinFunction )
class BuiltinModule {
    /* Constructor Function */
    public function new(name, ?def:Iterable<BuiltinFunction>):Void {
        this.exports = new Map();
        this.name = name;

        if (def != null) {
            for (fn in def)
                addBuiltinMethod( fn );
        }
    }

/* === Methods === */

    public inline function addBuiltinMethod(method: BuiltinFunction):BuiltinFunction {
        return exports[method.name] = method;
    }

    public inline function addMethod(name:String, method:TypedFn):BuiltinFunction {
        return addBuiltinMethod(BuiltinFunction.make(name, method));
    }

    public inline function addNative(name:String, method:Function):BuiltinFunction {
        return addBuiltinMethod(BuiltinFunction.wrap(name, method));
    }

    public inline function addModule(m: BuiltinModule) {
        for (x in m.exports) {
            addBuiltinMethod( x );
        }
    }

    public inline function get(name: String):Null<BuiltinFunction> {
        return exports[name];
    }

    public inline function call(name:String, args:Array<Dynamic>):Dynamic {
        return get(name).safeApply(args).getUnderlyingValue();
    }

    public inline function importInto(context: QueryInterp) {
        for (method in exports) {
            context.builtins[method.name] = method;
        }
    }

/* === Fields === */

    public var name(default, null): String;
    public var exports(default, null): Map<String, BuiltinFunction>;
}

@:forward
abstract MidFunc (Function) from Function to Function {}

@:forward
@:callable
abstract TypedFn (Array<TypedData>->TypedData) from Array<TypedData>->TypedData to Array<TypedData>->TypedData {

}
