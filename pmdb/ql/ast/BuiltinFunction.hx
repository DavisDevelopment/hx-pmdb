package pmdb.ql.ast;

import pmdb.core.ds.Lazy;
import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSignature;
import pmdb.core.TypedValue;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.ds.tools.ArrayTools;
import pmdb.ql.ast.nodes.*;

import haxe.macro.Expr;
import haxe.ds.ReadOnlyArray;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;
import haxe.DynamicAccess;
import haxe.DynamicAccess as Da;

import pmdb.ql.ts.DataTypes.typed as type;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.core.ds.tools.Options;


class BuiltinFunction {
    public function new(name) {
        this.name = name;
        this.signature = null;
        this.d = new FunctionData([]);

        parseMetadata(this, d);
    }

/* === Methods === */

    public macro function call(self:ExprOf<BuiltinFunction>, args:Array<Expr>):ExprOf<TypedValue> {
        return macro $self.safeApply([$a{args}]);
    }

    public function safeApply(args: Array<Dynamic>):TypedValue {
        var ret:Dynamic = apply(
          args.map(x -> Std.is(x, TypedValue.type) ? (x : TypedValue) : type(x))
        );
        if (!(Std.is(ret, TypedValue.type)))
            ret = type(ret);
        return ret;
    }

    @:deprecated('BuiltinFunction.apply will be reimplemented soon')
    public function apply(parameters: Array<TypedValue>):TypedValue {
        throw new NotImplementedError();
    }

    public inline function toVarArgFunction():Function {
        return Reflect.makeVarArgs(function(args: Array<Dynamic>):Dynamic {
            return this.apply(args.map(x -> type( x ))).value;
        });
    }

    /**
      parse out useful data from a BuiltinFunction's metadata, write that data onto a given FunctionData object
     **/
    public static function parseMetadata(pmFn:BuiltinFunction, fnd:FunctionData) {
        final parser = pmdb.core.query.StoreQueryInterface.globalParser;

        var pmFnCtor:Class<BuiltinFunction> = Type.getClass( pmFn );
        var fn:DynamicAccess<Dynamic> = cast pmFn;
        var mi = haxe.rtti.Meta.getFields( pmFnCtor );//.asObject();
        var ms = haxe.rtti.Meta.getStatics( pmFnCtor );
        var mt = haxe.rtti.Meta.getType( pmFnCtor );//.asObject();

        final meta:{i:Dynamic<Dynamic<Array<Dynamic>>>, s:Dynamic<Dynamic<Array<Dynamic>>>, t:Dynamic<Array<Dynamic>>} = {
            i: mi,
            s: ms,
            t: mt
        };

        var ls:Array<String>, mf:Object<Dynamic<Array<Dynamic>>> = meta.i;
        for (field in mf.keys()) {
            final fData:Object<Array<Dynamic>> = mf[field];

            if (fData.exists( 'fn' )) {
                var iotypes = fData.get('fn').map(x -> parser.parseDataType(cast(x, String)));
                //final signature:FnSig = {accepts:iotypes, returns:iotypes.pop()};
                final signature = new FnSig(cast iotypes, cast iotypes.pop());
                final fid:FnId<Dynamic, Function> = new FnId(pmFn, field);
                final ole:OverloadEntry = new OverloadEntry(signature, fid);

                fnd.overloads.push( ole );
            }
        }
    }



/* === Statics === */

    public static inline function wrap<Fn:Function>(name:String, fn:Fn):NativeFunction<Fn> {
        return new NativeFunction(name, fn);
    }

    public static inline function make(name:String, fn:Array<TypedValue>->TypedValue):UnboundBuiltinFunction {
        return new UnboundBuiltinFunction(name, fn);
    }

/* === Fields === */

    public var name(default, null): String;
    public var signature(default, null): Null<TypeSignature>;
    //public var fn(default, null): TypedFunction;
    public var d(default, null): Null<FunctionData>;
}

/**
  container for data (type information, arity, etc) used by native functions exposed to the Query VM
 **/
@:structInit
class FunctionData {
    public function new(ol) {
        overloads = ol;
        isConstructorFor = None;
        isMacro = false;
    }

    //public var arity(default, null): Int;
    public var overloads(default, null): Null<Array<OverloadEntry>>;
    public var isConstructorFor(default, null): Option<DataType>;
    public var isMacro(default, null): Bool;
}

@:structInit
class OverloadEntry {
    final signature: FnSig;
    final method: FnId<Dynamic, Function>;

    public function new(sign, fn) {
        signature = sign;
        method = fn;
    }
}

@:structInit
class FnSig {
    public final accepts: ReadOnlyArray<DataType>;
    public final returns: DataType;

    public function new(accepts, returns) {
        this.accepts = accepts;
        this.returns = returns;
    }
}

@:structInit
class FnId<Ctx, Fn:Function> {
    public final instance: Ctx;
    final instClass: Class<Ctx>; //= Type.getClass( instances );
    public final fieldName: String;

    public function new(instance, fieldName) {
        this.instance = instance;
        instClass = Type.getClass(instance);
        this.fieldName = fieldName;
    }
}

class UnboundBuiltinFunction extends BuiltinFunction {
    /* Constructor Function */
    public function new(name, apply) {
        super(name);

        dapply = apply;
    }

    dynamic function dapply(args: Array<TypedValue>):TypedValue {
        throw new NotImplementedError();
    }

    override function apply(args: Array<TypedValue>):TypedValue {
        return dapply( args );
    }
}

class NativeFunction<T:Function> extends UnboundBuiltinFunction {
    /* Constructor Function */
    public function new(name, nativeFn):Void {
        super(name, function(args: Array<TypedValue>):TypedValue {
            return Reflect.callMethod(null, nativeFn, args.map(x -> x.value)).typed();
        });
        nfn = nativeFn;
    }

    var nfn(default, null): Function;
}
