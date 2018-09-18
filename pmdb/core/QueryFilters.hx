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
using pmdb.core.Utils;

class QueryFilters {

}

class QueryAsts {
    public static function queryMatch(expr:QueryAst, doc:Anon<Anon<Dynamic>>):Bool {
        return switch expr {
            case QueryAst.Expr( expr ): Filters.queryMatch(expr, doc);
            case QueryAst.Flow( logic ): Flows.queryMatch(logic, doc);
        }
    }

    public static function iterFilters(expr: QueryAst, fn:FilterExpr<Any>->Void):Void {
        switch expr {
            case Flow( log ):
                switch log {
                    case LNot( e ):
                        iterFilters(e, fn);

                    case LAnd( ea ), LOr( ea ):
                        for (e in ea)
                            iterFilters(e, fn);

                    case _:
                        return ;
                }

            case Expr( expr ):
                fn( expr );
        }
    }
}

class Flows {
    public static function queryMatch(expr:LogOp, doc:Anon<Anon<Dynamic>>):Bool {
        var match = QueryAsts.queryMatch.bind(_, _);
        switch expr {
            case LNot( query ):
                return !match(query, doc);

            case LAnd( queries ):
                return queries.all(QueryAsts.queryMatch.bind(_, doc));

            case LOr( queries ):
                return queries.any(QueryAsts.queryMatch.bind(_, doc));

            case other:
                throw new Error('Unsupported logical operator $other');
        }
    }
}

class Filters {
    public static function queryMatch(expr:FilterExpr<Any>, doc:Anon<Anon<Dynamic>>):Bool {
        for (name in expr.keys()) {
            if (!FilterValues.queryMatch(name, expr.get(name), doc)) {
                return false;
            }
        }

        return true;
    }
}

class FilterValues {
    @:noUsing
    public static function queryMatch<T>(name:String, expr:FilterExprValue<T>, doc:Anon<Anon<Dynamic>>):Bool {
        return switch expr {
            case VIs( value ): Arch.areThingsEqual(value, doc.dotGet( name ));
            case VOps( ops ): testQueryOps(name, doc, ops);
        }
    }

    public static function testQueryOps<T>(name:String, doc:Anon<Anon<Dynamic>>, ops:Map<ColOpCode, Dynamic>):Bool {
        for (op in ops.keys()) {
            if (!testQueryOp(name, doc, op, ops[op])) {
                return false;
            }
        }
        return true;
    }

    public static function testQueryOp<T>(name:String, doc:Anon<Anon<Dynamic>>, op:ColOpCode, value:Dynamic):Bool {
        return switch op {
            case LessThan: Ops.op_lt(cast doc.dotGet( name ), value, Comparator.any());
            case LessThanEq: Ops.op_lte(cast doc.dotGet( name ), value, Comparator.any());
            case GreaterThan: Ops.op_gt(cast doc.dotGet( name ), value, Comparator.any());
            case GreaterThanEq: Ops.op_gte(cast doc.dotGet( name ), value, Comparator.any());
            case In: Ops.op_in(cast doc.dotGet( name ), cast value, cast Equator.any());
            case NIn: Ops.op_nin(cast doc.dotGet( name ), cast value, cast Equator.any());
            case Regexp: Ops.op_regex(doc.dotGet( name ), cast value);
        }
    }

    public static inline function hasValueRange<T>(ops: Map<ColOpCode, T>):Bool {
        return (ops.exists(LessThan) || ops.exists(LessThanEq) || ops.exists(GreaterThan) || ops.exists(GreaterThanEq));
    }

    public static function getValueRange<T>(ops: Map<ColOpCode, T>, remove:Bool=false):Null<{?min:BoundingValue<T>, ?max:BoundingValue<T>}> {
        var min:Null<BoundingValue<T>> = null;
        var max:Null<BoundingValue<T>> = null;

        if (ops.exists(LessThan)) {
            max = switch ops[LessThan] {
                case null: null;
                case v: BoundingValue.Edge( v );
            }
            if ( remove )
                ops.remove( LessThan );
        }

        if (ops.exists( LessThanEq )) {
            max = switch ops[LessThanEq] {
                case null: null;
                case v: BoundingValue.Inclusive( v );
            }

            if ( remove )
                ops.remove( LessThanEq );
        }

        if (ops.exists( GreaterThan )) {
            min = switch ops[GreaterThan] {
                case null: null;
                case v: BoundingValue.Edge( v );
            }

            if ( remove )
                ops.remove( GreaterThan );
        }

        if (ops.exists( GreaterThanEq )) {
            max = switch ops[GreaterThanEq] {
                case null: null;
                case v: BoundingValue.Inclusive( v );
            }
            if ( remove )
                ops.remove( GreaterThanEq );
        }

        if (min == null && max == null) {
            return null;
        }
        else {
            var out:{?min:BoundingValue<T>, ?max:BoundingValue<T>} = {};
            if (min != null)
                out.min = min;
            if (max != null)
                out.max = max;
            return out;
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
