package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
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

/**
  QueryFilter - specifies one or more checks used to filter documents from query-results
  based heavily on the query-format in [nedb](https://github.com/louischatriot/nedb)
  References:
  https://github.com/louischatriot/nedb#basic-querying
 **/
class QueryFilter {
    /* Constructor Function */
    public function new(source:Dynamic, ?pos:PosInfos) {
        raw = null;
        if (source == null) {
            throw new Error('QueryFilter cannot be instantiated as null', pos);
        }
        if (isType(source, QueryAst)) {
            //
        }
        else if (Arch.isObject( source )) {
            raw = source;
        }
    }

/* === Methods === */

    /**
      tells whether the given object [doc] is matched by the pattern described by [this]
     **/
    public function match(doc: Anon<Dynamic>):Bool {
        return pmdb.nedb.NModel.match(doc, raw);
    }

/* === Fields === */

    //private var ast(default, null): QueryAst;
    private var raw(default, null): Null<Anon<Dynamic>>;
}

enum QueryAst {
    Flow(logic: LogOp);
    Filter(query: QueryExpr);
}

enum QueryExpr {
    Is(key:String, val:Dynamic);
    //Op(what...?);
}

enum LogOp {
    LNot(sub: QueryAst);
    LAnd(a:QueryAst, b:QueryAst);
    LOr(a:QueryAst, b:QueryAst);
}


