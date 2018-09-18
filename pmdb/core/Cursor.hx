package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;

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
using pmdb.ql.types.DataTypes;
using pmdb.core.Utils;

class Cursor <Item> {
    /* Constructor Function */
    public function new(store:Store<Item>, query:QueryFilter):Void {
        this.db = store;
        this.query = query;

        _limit = None;
        _skip = None;
        _sort = None;
        _projection = None;
    }

/* === Instance Methods === */

    public function limit(n: Int):Cursor<Item> {
        _limit = Some( n );
        return this;
    }

    public function skip(n: Int):Cursor<Item> {
        _skip = Some( n );
        return this;
    }

    public function sort(q: SortQuery):Cursor<Item> {
        _sort = Some( q );
        return this;
    }

    /**
      
     **/
    public function _exec() {
        
    }

/* === Instance Fields === */

    public var db(default, null): Store<Item>;
    public var query(default, null): QueryFilter;

    public var _limit(default, null): Option<Int>;
    public var _skip(default, null): Option<Int>;
    public var _sort(default, null): Option<SortQuery>;
    public var _projection(default, null): Option<Projection>;
}

typedef SortQuery = Anon<SortOrder>;
typedef Projection = Anon<FieldFlag>;

@:enum
abstract SortOrder (Int) {
    var Asc = 1;
    var Desc = -1;
}

@:enum
abstract FieldFlag (Int) {
    var Omit = 0;
    var Take = 1;
}
