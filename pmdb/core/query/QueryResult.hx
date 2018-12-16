package pmdb.core.query;

import tannus.ds.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.query.Criterion;
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

@:access(pmdb.core.Query)
class QueryResult<Item> {
    public function new(q) {
        this.query = q;
        //this.rows = rows;
    }

/* === Methods === */

    public inline function exec():Array<Item> {
        _exec();
        return rows;
    }

    inline function _exec() {
        if (cand == null) {
            var candidates = @:privateAccess query.store.getCandidates(query.filter != null ? query.filter : cast Criterion.noop());
            cand = rows = candidates;
        }
    }

/* === Properties === */

    public var length(get, never): Int;
    inline function get_length():Int return rows.length;

/* === Fields === */

    public var query(default, null): Query<Item>;
    
    private var cand(default, null): Array<Item>;
    private var rows(default, null): Array<Item>;
}

