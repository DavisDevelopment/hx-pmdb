package pmdb.ql.ast;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSignature;
import pmdb.ql.ts.TypedData;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.ql.ast.nodes.*;

import haxe.macro.Expr;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;

import pmdb.ql.ts.DataTypes.typed as type;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class BuiltinFunction {
    public function new(name) {
        this.name = name;
        this.signature = null;
    }

/* === Methods === */

    public macro function call(self:ExprOf<BuiltinFunction>, args:Array<Expr>):ExprOf<TypedData> {
        return macro $self.safeApply([$a{args}]);
    }

    public function safeApply(args: Array<Dynamic>):TypedData {
        var ret:Dynamic = apply(
          args.map(x -> (x is TypedData) ? cast(x, TypedData) : type(x))
        );
        if (!(ret is TypedData))
            ret = type(ret);
        return ret;
    }

    public function apply(parameters: Array<TypedData>):TypedData {
        throw new NotImplementedError();
    }

    public inline function toVarArgFunction():Function {
        return Reflect.makeVarArgs(function(args: Array<Dynamic>):Dynamic {
            return this.apply(args.map(x -> type( x ))).getUnderlyingValue();
        });
    }

/* === Statics === */

    public static inline function wrap<Fn:Function>(name:String, fn:Fn):NativeFunction<Fn> {
        return new NativeFunction(name, fn);
    }

    public static inline function make(name:String, fn:Array<TypedData>->TypedData):UnboundBuiltinFunction {
        return new UnboundBuiltinFunction(name, fn);
    }

/* === Fields === */

    public var name(default, null): String;
    public var signature(default, null): Null<TypeSignature>;
    //public var fn(default, null): TypedFunction;
}

class UnboundBuiltinFunction extends BuiltinFunction {
    /* Constructor Function */
    public function new(name, apply) {
        super(name);

        dapply = apply;
    }

    dynamic function dapply(args: Array<TypedData>):TypedData {
        throw new NotImplementedError();
    }

    override function apply(args: Array<TypedData>):TypedData {
        return dapply( args );
    }
}

class NativeFunction<T:Function> extends UnboundBuiltinFunction {
    /* Constructor Function */
    public function new(name, nativeFn):Void {
        super(name, function(args: Array<TypedData>):TypedData {
            return Reflect.callMethod(null, nativeFn, args.map(x -> x.getUnderlyingValue())).typed();
        });
        nfn = nativeFn;
    }

    var nfn(default, null): Function;
}
