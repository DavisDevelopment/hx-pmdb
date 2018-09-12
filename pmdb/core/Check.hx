package pmdb.core;

import tannus.ds.*;
import tannus.io.*;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
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
using pmdb.ql.types.DataTypes;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

@:forward
abstract Check (CheckObject) from CheckObject to CheckObject {
    @:from
    public static function checker(cm: Dynamic->Bool):Check return FCheck.make( cm );

    @:from
    public static function typeCheck(type: DataType):Check return new DataTypeCheck( type );

    public static function and(left:Check, right:Check):Check return new AndCheck(left, right);
    public static function or(left:Check, right:Check):Check return new OrCheck(left, right);
    public static function build(f: BagOfChecks -> Void):Check {
        var bag = new BagOfChecks();
        f( bag );
        return bag;
    }
}

/**
  NOT for type-checking!
  Is the root interface for entire Check module, and is typed
 **/
interface TypedCheckObject<CType> {
    function check(context: CType):Bool;
    //function copy():Check;
    function optimize():Null<Check>;
    function compile():CType->Bool;
    function toString():String;
}

interface CheckObject extends TypedCheckObject<Dynamic> {}
typedef TypedSubject<T> = T;
typedef Subject = TypedSubject<Dynamic>;

class BagOfChecks extends CheckBase {
    /* Constructor Function */
    public function new(?init: Array<Check>) {
        checks = new Array();
        if (init != null)
            checks.append( init );
        _compiled_ops = null;
        _compiled = null;
        _locked_ = false;
    }

/* === Methods === */

    public function append(c: Check):BagOfChecks {
        if ( _locked_ )
            return this;
        checks.push( c );
        return this;
    }

    public function prepend(c: Check):BagOfChecks {
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

    public function lock():BagOfChecks {
        if ( _locked_ ) 
            return this;

        var res = _inPlaceCompile();
        _locked_ = true;
        return res;
    }

    /**
      [= NEEDS PERFORMANCE TESTING =]
     **/
    function _inPlaceCompile():BagOfChecks {
        if ( _locked_ )
            return this;

        if (checks.empty()) {
            _compiled_ops = [];
            _compiled = (x -> true);
        }

        _compiled_ops = checks.map(function(ch: Check) {
            return ch.compile();
        });

        // TODO test this:
        _compiled = (function() {
            _compiled_ops.compose(function(left:Dynamic->Bool, right:Dynamic->Bool) {
                return (o -> left(o) && right(o));
            }, FunctionTools.identity);
            return _compiled;
        }());
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

    var checks(default, null): Array<Check>;
    var _compiled_ops(default, null): Null<Array<Dynamic -> Bool>>;
    var _compiled(default, null): Null<Dynamic -> Bool>;

    var _locked_(default, null): Bool;
}

/**
  perform a type-check using DataType
 **/
class DataTypeCheck extends FCheck {
    public function new(type: DataType) {
        //NOTE: this is structured this way to minimize overhead from scope lookups
        super((function(t: DataType) {
            return t.valueChecker();
        }(type)));
    }
}

/* OR (||) Check */
class OrCheck extends FJoinCheck {
    public function new(l, r) {
        super(l, r, function(o, a, b) {
            return a.check(o) || b.check(o);
        });
    }
}

/* AND (&&) Check */
class AndCheck extends FJoinCheck {
    public function new(l, r) {
        super(l, r, function(o, a, b) {
            return a.check(o) && b.check(o);
        });
    }
}

class FJoinCheck extends JoinCheck {
    var f(default, null): Dynamic->Check->Check->Bool;
    /* Constructor Function */
    public function new(l, r, f) {
        super(l, r);
        this.f = f;
    }
    override function join_check(o:Dynamic, l:Check, r:Check):Bool return f(o, l, r);
}

class JoinCheck extends CheckBase {
    public function new(l:Check, r:Check) {
        cp = new Pair(l, r);
    }
    override function check(o: Dynamic):Bool {
        return join_check(o, cp.left, cp.right);
    }
    override function compile():Dynamic->Bool {
        return join_compile(cp.left, cp.right);
    }
    override function optimize() return join_optimize(cp.left, cp.right);

    function join_check(ctx:Dynamic, left:Check, right:Check):Bool {
        throw new NotImplementedError();
    }
    function join_optimize(l:Check, r:Check):Null<Check> {
        return null;
    }
    function join_compile(l:Check, r:Check):Dynamic->Bool {
        throw new NotImplementedError();
    }

    var cp(default, null): Pair<Check, Check>;
}

class FCheck extends CheckBase {
    public function new(f: Dynamic->Bool) {
       this.f = f; 
    }

    override function check(o: Dynamic):Bool return f( o );
    override function compile() return f;
    override function optimize() return null;
    override function toString():String return 'Check($f)';
    public static function make(f: Dynamic->Bool):FCheck return new FCheck( f );

    var f(default, null): Dynamic->Bool;
}

class CheckBase implements CheckObject {
    public function check(o: Dynamic):Bool throw new NotImplementedError();
    public function optimize():Null<Check> return null;
    public function compile():Dynamic->Bool { return check.bind(_); }
    public function toString():String return 'CheckBase';
}
