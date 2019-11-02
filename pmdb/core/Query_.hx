package pmdb.core;

import tannus.ds.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.query.Criterion;
import pmdb.core.query.QueryResult;
import pmdb.core.ds.*;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.ds.Ref;
import pmdb.core.Object;

import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;
import tannus.math.TMath as M;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

/**
  abstract type for representing a Store query in general
 **/
@:forward
abstract Query<Item> (CQuery<Item>) from CQuery<Item> to CQuery<Item> {
    public inline function new(src) {
        this = new CQuery(src);
    }

/* === Casting Methods === */

    public static function make<Item>(?src:QuerySrc<Item>, ?filter:Criterion<Item>):Query<Item> {
        return CQuery.make(src, filter);
    }
}

/**
  represents a SELECT-type query
 **/
class CQuery<Item> {
    /* Constructor Function */
    public function new(src):Void {
        source = src;
        store = QuerySrcs.getRoot(source);

        filter = null;
        ordering = null;
        paging = null;
    }

/* === Methods === */

    public function where(filter: Criterion<Item>):Query<Item> {
        return withFilter( filter );
    }

    public inline function withFilter(fi: Criterion<Item>) {
        return _filter( fi );
    }

    @:noCompletion
    public function _filter(clause: Criterion<Item>) {
        this.filter = clause;
        return this;
    }

    public function result():QueryResult<Item> {
        return _res();
    }

    public inline function pullFrom(src: QuerySrc<Item>) {
        source = src;
    }

    public inline function withSource(src: QuerySrc<Item>):Query<Item> {
        pullFrom( src );
        return this;
    }

    function _res():QueryResult<Item> {
        /**
          TODO move the actual filtering into this class. Store.getCandidates is actually getting the filtered list
         **/
        var candidates = store.getCandidates(store.q.getSearchIndex(store.q.check( filter )));

        return new QueryResult(this, candidates);
    }

    public static function make<A>(src, ?filter):CQuery<A> {
        var ret = new CQuery(src);
        ret.filter = filter;
        return ret;
    }

/* === Variables === */

    public var source(default, null): Null<QuerySrc<Item>>;
    //public var output(default, null): Null<QueryOut<In, Out>>;
    public var filter(default, null): Null<Criterion<Item>>;

    public var ordering(default, null): Null<QueryOrder>;
    public var paging(default, null): Null<Paging>;

    @:allow( pmdb.core.query.QueryResult )
    private var store(default, null): Null<Store<Item>>;
}

@:using(pmdb.core.Query.QuerySrcs)
enum QuerySrc<T> {
    Store(store: Store<T>):QuerySrc<T>;
    Results(query: Query<T>):QuerySrc<T>;
}

class QuerySrcs {
    public static function getRoot<T>(src: QuerySrc<T>):Store<T> {
        return switch src {
            case Store(x): x;
            case Results(x): getRoot( x.source );
        }
    }
}

typedef QueryOrder = Dynamic<Int>;
typedef Paging = {?offset:Int, ?limit:Int};

