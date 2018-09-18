package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Cursor;
import pmdb.core.QueryFilter;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
//using pmdb.ql.types.DataTypes;

/**
  abstract type for representing a Store query in general
 **/
@:forward
abstract Query (CQuery) from CQuery to CQuery {
    /* Constructor Function */
    public inline function new(?q: QueryFilter) {
        this = new CQuery( q );
    }

/* === Casting Methods === */

    @:from
    public static inline function of(o: Dynamic):Query {
        return CQuery.of( o );
    }
}

/**
  represents a SELECT-type query
 **/
class CQuery {
    /* Constructor Function */
    public function new(?filter: QueryFilter) {
        this.filter = filter;
        sorting = null;
        selection = null;
        pagination = null;
    }

/* === Methods === */

    /**
      define some filter criteria
     **/
    public function where(query: Dynamic):Query {
        filter = createQueryFilter( query );
        return this;
    }

    public function skip(n: Option<Int>):Query {
        if (pagination == null) {
            switch n {
                case Some(v):
                    pagination = {
                        skip: v,
                        limit: null
                    };

                case None:
                    //
            }

            return this;
        }
        else {
            switch n {
                case Some(v):
                    pagination.skip = v;

                case None:
                    pagination.skip = null;
            }

            return this;
        }
    }

    public function limit(n: Option<Int>):Query {
         if (pagination == null) {
            switch n {
                case Some(v):
                    pagination = {
                        skip: null,
                        limit: v
                    };

                case None:
                    //
            }

            return this;
        }
        else {
            switch n {
                case Some(v):
                    pagination.limit = v;

                case None:
                    pagination.limit = null;
            }

            return this;
        }       
    }

    public function join(other: Query):Query {
        var sum:Query = new Query();
        sum.filter = switch [filter, other.filter] {
            case [null, v]|[v, null]: v;
            case [a, b]: a.join( b );
        }
        return sum;
    }

    public function applyToCursor(cursor: Cursor<Any>) {
        if (pagination != null) {
            if (pagination.skip != null)
                cursor.skip( pagination.skip );
            if (pagination.limit != null)
                cursor.limit( pagination.limit );
        }

        if (sorting != null) {
            cursor.sort( sorting );
        }

        if (selection != null) {
            cursor.projection( selection );
        }
    }

    public static function createQueryFilter(query: Dynamic):QueryFilter {
        if (isType(query, QueryFilter)) {
            return cast query;
        }
        else if (isType(query, QueryAst)) {
            return new QueryFilter(cast(query, QueryAst));
        }
        else if (isType(query, CQuery)) {
            return cast(query, CQuery).filter;
        }
        else if (Arch.isFunction( query )) {
            var builder = new QueryFilterBuilder();
            var tmp = untyped query( builder );
            if (isType(tmp, QueryFilterBuilder))
                builder = cast tmp;
            return builder.toQueryFilter();
        }
        else if (Arch.isObject( query )) {
            return QueryFilter.ofAnon( query );
        }
        else {
            throw new Error('Cannot create QueryFilter from $query');
        }
    }

    public static function of(value: Dynamic):CQuery {
        if (isType(value, CQuery)) {
            return cast value;
        }
        else {
            return new CQuery(createQueryFilter( value ));
        }
    }

/* === Variables === */

    public var filter(default, null): Null<QueryFilter>;
    public var sorting(default, null): Null<SortQuery>;
    public var selection(default, null): Null<Projection>;
    public var pagination(default, null): Null<{?skip:Int, ?limit:Int}>;
}
