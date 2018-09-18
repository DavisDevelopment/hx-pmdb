package pmdb.core;

import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.QueryFilter;

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

class QueryFilters {

}

class QueryAsts {
    public static function queryMatch(expr:QueryAst, doc:Anon<Anon<Dynamic>>):Bool {
        return switch expr {
            case QueryAst.Filter( expr ): Filters.queryMatch(expr, doc);
            case QueryAst.Flow( logic ): Flows.queryMatch(logic, doc);
        }
    }

    public static function iterFilter(expr:QueryAst, fn:QueryExpr->Void):Void {
        switch expr {
            case Filter(e):
                fn( e );

            case Flow( flow ):
                switch flow {
                    case LNot(expr):
                        iterFilter(expr, fn);

                    case LAnd(l, r), LOr(l, r):
                        iterFilter(l, fn);
                        iterFilter(r, fn);
                }
        }
    }
}

class Flows {
    public static function queryMatch(expr:LogOp, doc:Anon<Anon<Dynamic>>):Bool {
        var match = QueryAsts.queryMatch.bind(_, _);
        switch expr {
            case LNot( query ):
                return !match(query, doc);

            case LAnd(left, right):
                return match(left, doc) && match(right, doc);

            case LOr(left, right):
                return match(left, doc) || match(right, doc);

            case other:
                throw new Error('Unsupported logical operator $other');
        }
    }
}

class Filters {
    public static function queryMatch(expr:QueryExpr, doc:Anon<Anon<Dynamic>>):Bool {
        switch expr {
            case Is(key, val):
                return (doc[key] == val);

            case Op(name, op):
                switch op {
                    case Lt(val):
                        return Ops.op_lt(doc[name], val, Comparator.any());
                    
                    case Lte(val):
                        return Ops.op_lte(doc[name], val, Comparator.any());
                    
                    case Gt(val):
                        return Ops.op_gt(doc[name], val, Comparator.any());
                    
                    case Gte(val):
                        return Ops.op_gte(doc[name], val, Comparator.any());

                    case In(vals):
                        return Ops.op_in(doc[name], vals, cast Equator.any());

                    case other:
                        throw new Error('Unexpected $other');
                }
        }
    }
}

class Ops {
    public static function op_lt<T>(a:T, b:T, c:Comparator<T>):Bool {
        return (c.compare(a, b) < 0);
    }

    public static function op_lte<T>(a:T, b:T, c:Comparator<T>):Bool {
        return (a == b || op_lt(a, b, c));
    }

    public static function op_gte<T>(a:T, b:T, c:Comparator<T>):Bool {
        return (a == b || op_gt(a, b, c));
    }

    public static function op_gt<T>(a:T, b:T, c:Comparator<T>):Bool {
        return (c.compare(a, b) > 0);
    }

    public static function op_in<T>(a:T, b:Array<T>, e:Equator<T>):Bool {
        if (!Arch.isArray( b )) {
            throw new Error('$$in operator called with a non-array');
        }

        for (i in 0...b.length) {
            if (e.equals(a, b[i])) {
                return true;
            }
        }

        return false;
    }

    public static function op_nin<T>(a:T, b:Array<T>, e:Equator<T>):Bool {
        if (!Arch.isArray( b )) {
            throw new Error('$$nin operator called with a non-array');
        }

        return !op_in(a, b, e);
    }

    public static function op_regex(a:Dynamic, b:EReg):Bool {
        if (!Arch.isRegExp( b )) {
            throw new Error("$regex operator called with a non-regexp");
        }

        if ((a is String)) {
            return b.match(cast a);
        }
        else {
            return false;
        }
    }

    public static function op_exists(value:Dynamic, exists:Bool):Bool {
        if (value == null) {
            return !exists;
        }
        else {
            return exists;
        }
    }
}
