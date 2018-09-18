package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.query.*;
import pmdb.core.*;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

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
using pmdb.ql.types.DataTypes;
using pmdb.core.QueryFilters;

/**
  QueryFilter - specifies one or more checks used to filter documents from query-results
  based heavily on the query-format in [nedb](https://github.com/louischatriot/nedb)
  References:
  https://github.com/louischatriot/nedb#basic-querying
 **/
class QueryFilter {
    /* Constructor Function */
    public function new(ast:QueryAst, ?pos:PosInfos) {
        this.ast = ast;
        this.position = pos;
        this.raw = null;
        this._match = null;
    }

/* === Methods === */

    /**
      tells whether the given object [doc] is matched by the pattern described by [this]
     **/
    public function match(doc: Anon<Anon<Dynamic>>):Bool {
        if (_match == null) {
            _match = new Match( this );
        }
        return _match.test( doc );
    }

    public function iterFilter(fn: QueryExpr -> Void):Void {
        return ast.iterFilter( fn );
    }

    /**
      create and return a new QueryFilter from the given struct
     **/
    public static function ofAnon(o: Anon<Anon<Dynamic>>):QueryFilter {
        return new QueryFilter(pmdb.core.query.ParseFromAnon.run( o ));
    }

/* === Fields === */

    private var ast(default, null): QueryAst;
    private var raw(default, null): Null<Anon<Anon<Dynamic>>>;
    private var position(default, null): PosInfos;

    private var _match(default, null): Null<Match>;
}

enum QueryAst {
    Flow(logic: LogOp);
    Filter(query: QueryExpr);
}

enum QueryExpr {
    Is(key:String, val:Dynamic);
    Op(key:String, operator:ColOp);
}

enum LogOp {
    LNot(sub: QueryAst);
    LAnd(a:QueryAst, b:QueryAst);
    LOr(a:QueryAst, b:QueryAst);
}

enum ColOp {
    Lt(val: Dynamic);
    Lte(val: Dynamic);
    Gt(val: Dynamic);
    Gte(val: Dynamic);
    In(vals: Array<Dynamic>);
}
