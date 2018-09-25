package pmdb.core;

import tannus.ds.*;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.Comparator;
import pmdb.core.Equator;

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
using pmdb.ql.ts.DataTypes;
using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

/**
  abstract type for value-validation, arrangeable in a tree-like layout
 **/
@:forward
abstract Matcher<Item, Pattern> (IMatcher<Item, Pattern>) from IMatcher<Item, Pattern> to IMatcher<Item, Pattern> {
/* === Instance Methods === */

    /**
      create and return a new Matcher that is derived from [this]
     **/
    public function wrap<Wrap:TMatcherWrap1<Item, Pattern>>(mw: Wrap):Matcher<Item, Pattern> {
        return new WrappedMatcher(this, mw);
    }

    /**
      perform the value-matching
     **/
    public function match<O>(value:Item, pattern:Lazy<Pattern>):Bool {
        return 
        if (this.qualify( value )) this.unify(value, pattern)
        else false;
    }

    @:to
    public inline function toString():String {
        return this.toString();
    }

/* === Factory Methods === */

    @:from
    public static inline function ofStruct<V,U,S:TMatcher<V,U>>(anon: S):Matcher<V, U> {
        return cast FwdMatcher.fwd( anon );
    }

    public static inline function create<V, U>(unify: V->U->Bool, qualify:V->Bool):Matcher<V, U> {
        return FwdMatcher.make(unify, qualify);
    }

    @:from
    public static inline function unifier<V, U>(unify: V -> U -> Bool):Matcher<V, U> {
        return create(unify, x -> true);
    }
}

interface IMatcher<Value, Pattern> {

    function qualify(v: Value):Bool;
    function unify(value:Value, pattern:Pattern):Bool;

    function toString():String;
}

/**
  models the outcome of a 'match'
 **/
//enum MatchResult<Value, Pattern, Result> {
    //MUnified<SubValue, SubPattern>(next: Null<NextMatcher<Value, SubValue, Pattern, SubPattern>>): MatchResult<Value, Pattern, NextMatcher<Value, SubValue, Pattern, SubPattern>>;
    //MUnmatched(failingMatch:Matcher<Value, Pattern>, reason:Null<String>): MatchResult<Value, Pattern, Null<String>>;
    //MError(error:Dynamic, ?pos:PosInfos): MatchResult<Value, Pattern, Error>;
//}

/**
  models a sub-Matcher applied as a response to the successful completion of its parent-Matcher
 **/
typedef NextMatcher<Parent, Child, Pattern1, Pattern2> = {
    next: Matcher<Child, Pattern2>,
    derive: {item:Parent->Child, pattern:Pattern1->Pattern2}
}

typedef TMatcher<X,Y> = {
    function qualify(v: X):Bool;
    function unify(v:X, re:Y):Bool;
}

class MatcherBase<V, Re> implements IMatcher<V, Re> {
    public function qualify(v: V):Bool return true;
    public function unify(v:V, re:Re):Bool throw 'not implemented';

    public function toString():String return '';
}

class FwdMatcher<V, Re> extends MatcherBase<V, Re> {
    var m: TMatcher<V, Re>;
    public function new(m) {
        this.m = m;
    }

    override function qualify(x: V):Bool return m.qualify( x );
    override function unify(x:V, re:Re):Bool return m.unify(x, re);
    override function toString():String {
        return Std.string( m );
    }

    public static function fwd<V, Re>(m: TMatcher<V, Re>):FwdMatcher<V, Re> {
        return new FwdMatcher( m );
    }

    public static function make<V, U>(u:V->U->Bool, q:V->Bool):Matcher<V, U> {
        return fwd({
            qualify: q,
            unify: u
        });
    }
}

class WrappedMatcher<V, Re> extends MatcherBase<V, Re> {
    var src:Matcher<V, Re>;
    var wrap_spec:TMatcherWrap1<V, Re>;
    public function new(src, wrap) {
        this.src = src;
        this.wrap_spec = wrap;
    }
    override function qualify(x: V):Bool return wrap_spec.qualify(src.qualify, x);
    override function unify(x:V, y:Re):Bool return wrap_spec.unify(src.unify, x, y);
    override function toString():String return src.toString();
}

typedef TMatcherWrap1<A, B> = {
    function qualify(supr:A->Bool, x:A):Bool;
    function unify(supr:A->B->Bool, x:A, y:B):Bool;
}
