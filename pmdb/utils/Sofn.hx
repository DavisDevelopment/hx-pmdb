package pmdb.utils;

import haxe.ds.Option;
import haxe.ds.Vector;
import haxe.ds.GenericStack as Stack;
import haxe.Constraints.Function;

//use this for macros or other classes
class Sofn<In, Out> {
  public var r(default, null):Ref<SofnMethod<In, Out>>;
  var _lockfn_(default, null):Null<In -> Out>;
  
  //var stack(default, null): Stack<SofnMethod<In, Out>>;
  
  public function new(fn: SofnMethod<In, Out>) {
    this.r = Ref.to( fn );
    this._lockfn_ = null;
    //this.stack = new Stack();
  }
  
  public function invoke(input: In):Out {
    if (_lockfn_ != null)
      return _lockfn_(input);
    
    trace('unoptimized invoke()');
    var cfn = r.get();
    return callStep(cfn, input);
  }
  
  public function compile():In -> Out {
    final c:Ref<In->Out> = Ref.to(null);
    function unopt(i: In):Out {
      if (this._lockfn_ != null) {
        c.assign(_lockfn_);
      }
      return this.invoke( i );
    }
    c.assign(unopt);
    //
    return (i -> c.get()(i));
  }
  
  function callStep(f:SofnMethod<In, Out>, i:In):Out {
    var cs:Stack<{f:SofnMethod<In,Out>,i:In}> = new Stack();
    var res:Ref<Out> = Ref.to( null );
    
    var step = f(i);
    evalStep(step, cs, res);
    if (!cs.isEmpty()) {
      var nxt = cs.pop();
      return callStep(nxt.f, nxt.i);
    }
    else {
      return res.get();
    }
  }
  
  function evalStep(step:SmStep<In, Out>, callStack:Stack<{f:SofnMethod<In,Out>,i:In}>, result:Ref<Out>) {
    switch step {
    	case Fail(err):
        throw err;
        
      case Tail(next, input):
        callStack.add({
          f: next,
          i: input
        });
        
      case Link(value, next):
        result.assign( value );
        //stack.add( next );
        this.r.assign( next );
        
      case Lock(opt):
        this._lockfn_ = opt;
        //throw 'penis';
    }
  }
}

typedef SofnMethod<In, Out> = In -> SmStep<In, Out>;

enum SmStep<I, O> {
  Tail(next:SofnMethod<I, O>, input:I);
  Link(value:O, next:SofnMethod<I, O>);
  Lock(optimized: I -> O);
  Fail(error: Dynamic);
}

@:forward(get, set, assign)
abstract Ref<T> (TRef<T>) from TRef<T> to TRef<T> {
  @:from public static inline function to<T>(value: T):Ref<T> {
    return new TRef<T>( value );
  }
  
  public var value(get, set): T;
  inline function get_value() return this.get();
  inline function set_value(x) return this.set(x);
}

@:generic
class TRef<T> {
  public var _value_(default, null): T;
  public inline function new(x : T) {
    assign( x );
  }
  public function assign(x: T) {
    _value_ = x;
  }
  public function get():T {
    return _value_;
  }
  public function set(x: T):T {
    assign( x );
    return x;
  }
}