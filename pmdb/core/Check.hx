package pmdb.core;

import tannus.ds.*;
import tannus.io.*;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Error;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.CallStack;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

using pmdb.core.Utils;
using pmdb.ql.ts.DataTypes;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

@:forward
abstract Constraint (ConstraintObject) from ConstraintObject to ConstraintObject {
    @:from
    public static inline function checkerUntyped(cm: Dynamic->Bool):Constraint {
        return FConstraint.make( cm );
    }

    @:from
    public static inline function checkerTyped<T>(fn: T -> Bool):Constraint {
        return TypedFunctionalConstraint.make( fn );
    }

    @:from
    public static function typeConstraint(type: ValType):Constraint {
        return new DataTypeConstraint( type );
    }

    @:op(A & B)
    public static function and(left:Constraint, right:Constraint):Constraint {
        return new AndConstraint(left, right);
    }

    @:op(A | B)
    public static function or(left:Constraint, right:Constraint):Constraint {
        return new OrConstraint(left, right);
    }

    public static function build(f: BagOfConstraints -> Void):Constraint {
        var bag = new BagOfConstraints();
        f( bag );
        return bag;
    }
}

/**
  NOT for type-checking!
  Is the root interface for entire Constraint module, and is typed
 **/
interface TypedConstraintObject<CType> {
    function check(context: CType):Bool;
    //function copy():Constraint;
    function optimize():Null<Constraint>;
    function compile():CType->Bool;
    function toString():String;
}

interface ConstraintObject extends TypedConstraintObject<Dynamic> {}
typedef TypedSubject<T> = T;
typedef Subject = TypedSubject<Dynamic>;

class BagOfConstraints extends ConstraintBase {
    /* Constructor Function */
    public function new(?init: Array<Constraint>) {
        checks = new Array();
        if (init != null)
            checks.append( init );
        _compiled_ops = null;
        _compiled = null;
        _locked_ = false;
    }

/* === Methods === */

    public function append(c: Constraint):BagOfConstraints {
        if ( _locked_ )
            return this;
        checks.push( c );
        return this;
    }

    public function prepend(c: Constraint):BagOfConstraints {
        if ( _locked_ )
            return this;
        checks.unshift( c );
        return this;
    }

    override function check(o: Dynamic):Bool {
        if (_compiled == null && _compiled_ops == null && (checks == null || checks.length == 0))
            return true;

        if (_compiled != null) {
            return _compiled( o );
        }

        if (_compiled_ops != null) {
            for (step in _compiled_ops) {
                if (!step( o ))
                    return false;
            }
            return true;
        }

        for (child in checks) {
            if (!child.check( o ))
                return false;
        }
        return true;
    }

    public function lock():BagOfConstraints {
        if ( _locked_ ) 
            return this;

        var res = _inPlaceCompile();
        _locked_ = true;
        return res;
    }

    /**
      [= NEEDS PERFORMANCE TESTING =]
     **/
    function _inPlaceCompile():BagOfConstraints {
        if ( _locked_ )
            return this;

        if (checks.empty()) {
            _compiled_ops = [];
            _compiled = (x -> true);
        }

        _compiled_ops = checks.map(function(ch: Constraint) {
            return ch.compile();
        });

        // TODO test this:
        _compiled = (function() {
            _compiled_ops.compose(function(left:Dynamic->Bool, right:Dynamic->Bool) {
                return (o -> left(o) && right(o));
            }, FunctionTools.identity);
            return _compiled;
        })();
        return this;

        // ... versus this:
        /*
        _compiled = (function() {
            return (function(item: Dynamic) {
                for (o in ops)
                   if (!o(item))
                      return false;
                return true;
            });
        }());
        */
    }

    public inline function isCompiled():Bool {
        return (_compiled_ops != null && _compiled != null);
    }

/* === Fields === */

    var checks(default, null): Array<Constraint>;
    var _compiled_ops(default, null): Null<Array<Dynamic -> Bool>>;
    var _compiled(default, null): Null<Dynamic -> Bool>;

    var _locked_(default, null): Bool;
}

/**
  perform a type-check using DataType
 **/
class DataTypeConstraint extends FConstraint {
    public function new(type: DataType) {
        //NOTE: this is structured this way to minimize overhead from scope lookups
        super((function(t: DataType) {
            return t.valueChecker();
        })(type));
    }
}

/* OR (||) Constraint */
class OrConstraint extends FJoinConstraint {
    public function new(l, r) {
        super(l, r, function(o, a, b) {
            return a.check(o) || b.check(o);
        });
    }
}

/* AND (&&) Constraint */
class AndConstraint extends FJoinConstraint {
    public function new(l, r) {
        super(l, r, function(o, a, b) {
            return a.check(o) && b.check(o);
        });
    }
}

class FJoinConstraint extends JoinConstraint {
    var f(default, null): Dynamic->Constraint->Constraint->Bool;
    /* Constructor Function */
    public function new(l, r, f) {
        super(l, r);
        this.f = f;
    }
    override function join_check(o:Dynamic, l:Constraint, r:Constraint):Bool return f(o, l, r);
}

class JoinConstraint extends ConstraintBase {
    public function new(l:Constraint, r:Constraint) {
        cp = new Pair(l, r);
    }
    override function check(o: Dynamic):Bool {
        return join_check(o, cp.left, cp.right);
    }
    override function compile():Dynamic->Bool {
        return join_compile(cp.left, cp.right);
    }
    override function optimize() return join_optimize(cp.left, cp.right);

    function join_check(ctx:Dynamic, left:Constraint, right:Constraint):Bool {
        throw new NotImplementedError();
    }
    function join_optimize(l:Constraint, r:Constraint):Null<Constraint> {
        return null;
    }
    function join_compile(l:Constraint, r:Constraint):Dynamic->Bool {
        throw new NotImplementedError();
    }

    var cp(default, null): Pair<Constraint, Constraint>;
}

class FConstraint extends ConstraintBase {
    public function new(f: Dynamic->Bool) {
       this.f = f; 
    }

    override function check(o: Dynamic):Bool return f( o );
    override function compile() return f;
    override function optimize() return null;
    override function toString():String return 'Constraint($f)';
    public static function make(f: Dynamic->Bool):FConstraint return new FConstraint( f );

    var f(default, null): Dynamic->Bool;
}

class TypedFunctionalConstraint<T> extends ConstraintBase {
    public function new(fn: T -> Bool, ?tfn:Dynamic->Bool) {
        this.f = fn;
        if (tfn != null)
            this.check_type = tfn;
    }

    dynamic function check_type(ctx: Dynamic):Bool {
        return true;
    }

    override function check(o: Dynamic):Bool {
        return check_type( o ) && f( o );
    }

    override function compile() return check.bind(_);
    override function optimize() return null;
    public static function make<T>(fn: T -> Bool, ?verifyType:Dynamic->Bool):TypedFunctionalConstraint<T> return new TypedFunctionalConstraint(fn, verifyType);

    private var f(default, null): T -> Bool;
}

class ConstraintBase implements ConstraintObject {
    public function check(o: Dynamic):Bool throw new NotImplementedError();
    public function optimize():Null<Constraint> return null;
    public function compile():Dynamic->Bool { return check.bind(_); }
    public function toString():String return 'ConstraintBase';
}
