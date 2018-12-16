package pmdb.ql.ts;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;
import tannus.ds.Dict;
import tannus.ds.Make;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSignature;
import pmdb.core.Error;
import pmdb.core.Object;

import haxe.macro.Expr;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;


using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

using haxe.macro.ExprTools;

class TypedFunction {
    /* Constructor Function */
    public function new(?map: Map<String, Function>):Void {
        implementations = new Array();

        processMetadata();
        if (map != null) {
            for (key in map.keys()) {
                addImpl(stringSignature( key ), map[key]);
            }
        }
    }

/* === Methods === */

    /**
      process the current class's metadata
     **/
    private function processMetadata(?meta: Object<Dynamic<Array<Dynamic>>>) {
        if (meta == null) {
            meta = Object.of(Meta.getFields(Type.getClass(this)));
        }

        var field:Dynamic<Array<Dynamic>>;
        for (name in meta.keys()) {
            field = meta[name];
            if (field.fn != null) {
                var descs:Array<String> = cast field.fn;
                addImpl(listSignature(descs.map(x -> TypeDesc.parseString(x))), cast Reflect.field(this, name));
            }
        }
    }

    /**
      convenience macro
     **/
    public macro function apply(self:haxe.macro.Expr, args:Array<haxe.macro.Expr>) {
        args = args.map(x -> macro ($x));
        var eargs = macro $a{args};
        return macro $self.call(($eargs));
    }

    /**
      invoke [this] TypedFunction
     **/
    public function call(args: Array<Dynamic>):Dynamic {
        var res: Dynamic;
        var llargs: Array<Dynamic> = margs( args );
        trace( llargs );

        switch findImpl( llargs ) {
            case null:
                throw new Error('Invalid argument types provided', null);

            case i:
                res = cast Reflect.callMethod(null, i.fn, llargs);
                i.cc = switch i.cc {
                    case null: 1;
                    case cc: cc + 1;
                }
        }

        prioritySort();
        return res;
    }

    /**
      create a native Haxe function from [this]
     **/
    public function toFunction():Array<Dynamic>->Dynamic {
        if (implementations.length == 1) {
            return comp(implementations[0].fn, implementations[0].id).wrap(function(_, a:Array<Dynamic>) {
                return _(margs( a ));
            });
        }
        else {
            return call.bind();
        }
    }

    /**
      
     **/
    public function toVarArgFunction():Function {
        return cast Reflect.makeVarArgs(toFunction());
    }

    private static function comp(fn:Function, ?t:TypeSignature):Array<Dynamic>->Dynamic {
        var cfn:Array<Dynamic>->Dynamic = a -> Reflect.callMethod(null, fn, a);
        if (t != null) {
            cfn = cfn.wrap(function(_, a:Array<Dynamic>) {
                if (!t.accepts( a )) {
                    throw new Error('Invalid argument types provided', null);
                }
                return _( a );
            });
        }
        return cfn;
    }

    /**
      modify the given argument-list
     **/
    private dynamic function margs(a: Array<Dynamic>):Array<Dynamic> {
        return a;
    }

    /**
      create and return a copy of [this]
     **/
    public function copy(?target: TypedFunction):TypedFunction {
        if (target == null)
            target = new TypedFunction();
        for (i in implementations) {
            target.implementations.push(makeImpl(i.id, i.fn, i.cc));
        }
        target.margs = margs;
        return target;
    }

    /**
      bind [this] TypedFunction
     **/
    public function bind(args: Array<Option<Dynamic>>):TypedFunction {
        var bound = copy();
        for (i in 0...args.length) {
            switch args[i] {
                case Some(value):
                    bound.implementations = bound.implementations.filter(function(impl) {
                        return impl.id.input[i].test(value);
                    });

                case _:
                    continue;
            }
        }

        //var sm = bound.margs;
        var nm = argumentModifier( args );
        bound.margs = bound.margs.wrap(function(_, nargs:Array<Dynamic>):Array<Dynamic> {
            return _(nm(nargs));
        });
        return bound;
    }

    /**
      build a function that will modify arguments
     **/
    private function argumentModifier(pattern: Array<Option<Dynamic>>):Array<Dynamic>->Array<Dynamic> {
        var steps = [];
        for (i in 0...pattern.length) {
            steps.push(argModStep(pattern[i], i == pattern.length - 1));
        }
        return (function(steps:Array<Array<Dynamic>->Array<Dynamic>->Void>, args:Array<Dynamic>):Array<Dynamic> {
            var ll:Array<Dynamic> = new Array();
            for (step in steps) {
                step(args, ll);
            }
            return ll;
        }).bind(steps, _);
    }

    private static function argModStep(node:Option<Dynamic>, last:Bool):Array<Dynamic>->Array<Dynamic>->Void {
        return switch node {
            case Some( value ): ams_insert.bind(_, _, value);
            case None: ams_fwd.bind(_, _, last);
        }
    }

    private static function ams_fwd(args:Array<Dynamic>, llargs:Array<Dynamic>, rest:Bool):Void {
        if ( rest ) {
            for (x in args) {
                llargs.push( x );
            }
        }
        else {
            llargs.push(args.shift());
        }
    }

    private static inline function ams_insert(args:Array<Dynamic>, llargs:Array<Dynamic>, value:Dynamic):Void {
        llargs.push( value );
    }

    /**
      sort implementations by the number of times each one has been the one that was used
     **/
    private inline function prioritySort() {
        implementations.sort(function(x, y) {
            return Reflect.compare(x.cc, y.cc);
        });
    }

    /**
      find and return an implementation that is compatible with the given input values
     **/
    public function findImpl(values: Array<Dynamic>):Null<Impl> {
        var impls = implementations.copy();
        for (i in 0...values.length) {
            impls = impls.filter(impl -> impl.id.input[i].test(values[i]));
            if (impls.empty())
                return null;
        }
        return impls[0];
    }

    /**
      add an implementation function
     **/
    public function addImpl(ts:TypeSignature, impl:Function):TypedFunction {
        implementations.push(makeImpl(ts, impl));
        return this;
    }

/* === Fields === */

    public var implementations(default, null): Array<Impl>;

/* === Statics === */

    /**
      parse a String to a TypeSignature
     **/
    static function stringSignature(s: String):TypeSignature {
        return
            try TypeSignature.parseString( s )
            catch (e: Dynamic) listSignature(s.split('->').map(x -> TypeDesc.parseString(x)));
    }

    /**
      build a TypeSignature from a list
     **/
    static function listSignature(dl: Array<TypeDesc>):TypeSignature {
        if (dl.length == 0) {
            throw new Error('TypeDesc list cannot be empty', null);
        }
        else if (dl.length == 1) {
            dl = [TypeDesc.voidType, dl[0]];
            return listSignature( dl );
        }
        else {
            return new TypeSignature(dl.slice(0, -1), dl.pop());
        }
    }

    /**
      create and return a new Impl object
     **/
    static inline function makeImpl(id:TypeSignature, fn:Function, cc:Int=0):Impl {
        return {id:id, fn:fn, cc:cc};
    }
}

private typedef Impl = {
    id: TypeSignature,
    fn: Function,
    ?cc: Int
};
