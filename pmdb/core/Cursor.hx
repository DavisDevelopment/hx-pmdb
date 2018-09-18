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

    /**
      set the pagination-limit of [this] Cursor
     **/
    public function limit(n: Int):Cursor<Item> {
        _limit = Some( n );
        return this;
    }

    /**
      set the pagination-offset of [this] Cursor
     **/
    public function skip(n: Int):Cursor<Item> {
        _skip = Some( n );
        return this;
    }

    /**
      set the sorting of [this] Cursor
     **/
    public function sort(q: SortQuery):Cursor<Item> {
        _sort = Some( q );
        return this;
    }

    /**
      set the 'projection' of [this] Cursor
     **/
    public function projection(p: Projection) {
        _projection = Some( p );
        return this;
    }

    public function project(items: Array<Item>):Array<Item> {
        switch _projection {
            case None:
                return items;

            case Some( select ):
                var res = [],
                keepId:Bool = true,
                action = null, keys;

                keepId = switch select[db.primaryKey] {
                    case Omit: false;
                    default: true;
                }

                select.remove( db.primaryKey );
                keys = select.keys();
                for (key in keys) {
                    if (action != null && select[key] != action) {
                        throw new Error('Cannot both keep and omit fields except for the primary key');
                    }
                    action = select[key];
                }

                for (item in items) {
                    res.push( item );
                }

                return res;
        }
    }

    /**
      get the results of [this] Cursor's query
     **/
    @:noCompletion
    public function _exec():Array<Item> {
        var res:Array<Item> = [];
        var added:Int = 0;
        var skipped:Int = 0;
        var i:Int, keys:Array<String>, key:String;

        var candidates = db.getCandidates( query );
        for (i in 0...candidates.length) {
            if (query.match(cast candidates[i], cast db)) {
                if (_sort.isNone()) {
                    res.push(candidates[i]);
                }
                else {
                    switch _skip {
                        case Some(skip) if (skip > skipped):
                            skipped++;

                        case None:
                            res.push(candidates[i]);
                            added++;

                            switch _limit {
                                case Some(limit) if (limit <= added):
                                    break;

                                case _:
                                    //
                            }

                        case _:
                            //
                    }
                }
            }
        }

        switch _sort {
            case Some(sort):
                var keys = sort.keys();
                var criteria = [];
                for (i in 0...keys.length) {
                    criteria.push({
                        key: keys[i],
                        direction: sort[keys[i]]
                    });
                }

                res.sort(cast function(a:Anon<Dynamic>, b:Anon<Dynamic>):Int {
                    for (criterion in criteria) {
                        var compare = criterion.direction * Arch.compareThings(a.dotGet(criterion.key), b.dotGet(criterion.key));
                        if (compare != 0) {
                            return compare;
                        }
                    }
                    return 0;
                });

            case _:
                //
        }

        var limit:Int = _limit.or( res.length );
        var skip:Int = _skip.or( 0 );

        res = res.slice(skip, skip + limit);

        // apply projection
        if (_projection.isSome()) {
            res = project( res );
        }

        return res;
    }

    /**
      execute [this] Cursor
     **/
    public function exec():Array<Item> {
        return _exec();
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
abstract SortOrder (Int) from Int to Int {
    var Asc = 1;
    var Desc = -1;
}

@:enum
abstract FieldFlag (Int) {
    var Omit = 0;
    var Take = 1;
}
