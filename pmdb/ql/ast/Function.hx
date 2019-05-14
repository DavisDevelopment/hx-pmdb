package pmdb.ql.ast;

import pmdb.core.ValType;
import pmdb.core.TypedValue;

//TODO (Function => LeafFunction)
class Function implements FunctionObject {
    public function new(fn:NativeFnProxy, signature:Sig) {
        this.r = fn;
        //this.isBuiltin = false;
        //this.isLeaf = true;
    }

    /**
      invoke [this] Function
    **/
    public function __call__(params: Array<Dynamic>):Dynamic {
        var a = params;
        return switch r {
            case Fn0(fn): fn();
            case Fn1(fn):
                assert(params.length == 1, new pm.Error('', 'InvalidArguments'));
                return fn(params[0]);

            case Fn2(fn):
                return fn(a[0], a[1]);

            case Fn3(fn):
                return fn(a[0], a[1], a[2]);

            case FnVar(fn):
                return fn(a.copy());
        }
    }

    var r(default, null): NativeFnProxy;
    //public var isBuiltin(default, null): Bool;
    //public var isLeaf(default, null): Bool;
}

interface FunctionObject extends Callable {
    //function __call__(args: Array<Dynamic>):Dynamic;

    // whether `this` function is built-in with the PmDb runtime
    //var isBuiltin(default, null): Bool;

    // whether `this` function is a 'leaf' (has no overload-branches)
    //var isLeaf(default, null): Bool;
}

interface Callable {
    //var signature(get, never): Sig;

    function __call__(args: Array<Dynamic>):Dynamic;
}

typedef Sig = Dynamic;

enum NativeFnProxy {
    Fn0(f: Void -> Dynamic);
    Fn1(f: Dynamic -> Dynamic);
    Fn2(f: Dynamic -> Dynamic -> Dynamic);
    Fn3(f: Dynamic -> Dynamic -> Dynamic -> Dynamic);

    FnVar(f: Array<Dynamic> -> Dynamic);
}