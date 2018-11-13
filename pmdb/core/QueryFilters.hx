package pmdb.core;

import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.ds.Pair;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.ql.ast.BoundingValue;
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
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.core.Utils;

class QueryFilters {

}

class QueryAsts {
    public static function queryMatch(expr:QueryAst, doc:Anon<Anon<Dynamic>>, store:Store<Any>):Bool {
        return switch expr {
            case QueryAst.Expr( expr ): Filters.queryMatch(expr, doc, store);
            case QueryAst.Flow( logic ): Flows.queryMatch(logic, doc, store);
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

    public static function compileQuery(expr:QueryAst, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        return switch expr {
            case Expr(e): Filters.compileQuery(e, store);
            case Flow(o): Flows.compileLogOp(o, store);
        }
    }
}

class Flows {
    public static function queryMatch(expr:LogOp, doc:Anon<Anon<Dynamic>>, store:Store<Any>):Bool {
        var match = QueryAsts.queryMatch.bind(_, _, store);
        switch expr {
            case LNot( query ):
                return !match(query, doc);

            case LAnd( queries ):
                return queries.all(QueryAsts.queryMatch.bind(_, doc, store));

            case LOr( queries ):
                return queries.any(QueryAsts.queryMatch.bind(_, doc, store));

            case LWhere( check ):
                return check(cast doc);

            case other:
                throw new Error('Unsupported logical operator $other');
        }
    }

    public static function compileLogOp(expr:LogOp, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        return (switch expr {
            case LNot(query): ((test, doc:Doc) -> !test(doc)).bind(QueryAsts.compileQuery(query, store), _);
            case LAnd(queries):
                queries.map(e -> QueryAsts.compileQuery(e, store)).nireduce(function(acc:Doc->Bool, check:Doc->Bool) {
                    return (doc -> acc(doc) && check(doc));
                }, (x -> true));
            case LOr(queries):
                queries.map(e -> QueryAsts.compileQuery(e, store)).nireduce(function(acc:Doc->Bool, check:Doc->Bool) {
                    return (doc -> acc(doc) || check(doc));
                }, (x -> true));
            case LWhere(check):
                // there may be a better way?
                return check.bind(_);
        });
    }
}

class Filters {
    public static function queryMatch(expr:FilterExpr<Any>, doc:Anon<Anon<Dynamic>>, store:Store<Any>):Bool {
        for (name in expr.keys()) {
            if (!FilterValues.queryMatch(name, expr.get(name), doc, store)) {
                return false;
            }
        }

        return true;
    }

    /**
      iteratively reduces the set of query-criteria down to a singe predicate function
     **/
    public static function compileQuery(expr:FilterExpr<Any>, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        return expr.keys().array()
        .map(k -> new Pair(k, expr.get(k)))
        .nireduce(
            function(check:Doc->Bool, kv:Pair<String, FilterExprValue<Any>>):Doc->Bool {
                return ((kvc, doc:Doc) -> (check(doc) && kvc(doc))).bind(FilterValues.compileQuery(kv.right, kv.left, store), _);
            }, (doc -> true)
        );
    }
}

class FilterValues {
    @:noUsing
    public static function queryMatch<T>(name:String, expr:FilterExprValue<T>, doc:Anon<Anon<Dynamic>>, store:Store<Any>):Bool {
        return switch expr {
            case VIs( value ): Arch.areThingsEqual(value, doc.dotGet( name ));
            case VOps( ops ): testQueryOps(name, doc, ops, store);
        }
    }

    public static function compileQuery<T>(expr:FilterExprValue<T>, name:String, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        return switch expr {
            case VIs(value): 
                (function(eq, name:String):Doc->Bool {
                    return doc -> eq(doc.dotGet(name));
                })(Arch.areThingsEqual.bind(value, _), name);

            case VOps( ops ):
                return compileQueryOps(ops, name, store);
                //(function(check: ):Doc->Bool {

                //})(compileQueryOps(ops, name, store));
        }
    }

    public static function testQueryOps<T>(name:String, doc:Anon<Anon<Dynamic>>, ops:Map<ColOpCode, Dynamic>, store:Store<Any>):Bool {
        for (op in ops.keys()) {
            if (!testQueryOp(name, doc, op, ops[op], store)) {
                return false;
            }
        }
        return true;
    }

    /**
      [=NOTE=] uses mystical sorcery to 'compile' query-filter-ops into a single function
     **/
    public static function compileQueryOps<T>(ops:Map<ColOpCode, Dynamic>, name:String, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        return ops.keys().map(function(op: ColOpCode) {
            return compileQueryOp(op, name, ops[op], store);
        })
        .array()
        .compose(function(a:Doc->Bool, b:Doc->Bool):Doc->Bool {
            return (function(a:Doc->Bool, b:Doc->Bool, doc:Doc) {
                return (a( doc ) && b( doc ));
            }).bind(a, b, _);
        }, FunctionTools.identity);
    }

    public static function testQueryOp<T>(name:String, doc:Anon<Anon<Dynamic>>, op:ColOpCode, value:Dynamic, store:Store<Any>):Bool {
        return switch op {
            case LessThan: 
                Ops.op_lt(cast doc.dotGet( name ), value, store.indexes.exists(name) ? store.indexes[name].key_comparator() : Comparator.cany());
            case LessThanEq:
                Ops.op_lte(cast doc.dotGet( name ), value, store.indexes.exists(name) ? store.indexes[name].key_comparator() : Comparator.cany());
            case GreaterThan:
                Ops.op_gt(cast doc.dotGet( name ), value, store.indexes.exists(name) ? store.indexes[name].key_comparator() : Comparator.cany());
            case GreaterThanEq:
                Ops.op_gte(cast doc.dotGet( name ), value, store.indexes.exists(name) ? store.indexes[name].key_comparator() : Comparator.cany());
            case In:
                Ops.op_in(cast doc.dotGet( name ), cast value, store.indexes.exists(name) ? store.indexes[name].item_equator() : Equator.any());
            case NIn:
                Ops.op_nin(cast doc.dotGet( name ), cast value, store.indexes.exists(name) ? store.indexes[name].item_equator() : Equator.any());
            case Regexp:
                Ops.op_regex(doc.dotGet( name ), cast value);
        }
    }

    public static function compileQueryOp(op:ColOpCode, name:String, value:Dynamic, store:Store<Any>):Anon<Anon<Dynamic>>->Bool {
        var idx = store.indexes[name],
        comp = fn(_.key_comparator()),
        eq = fn(_.item_equator());

        switch op {
            case LessThan:
                return Ops.op_lt.bind(_, cast value, (idx != null ? comp(idx) : Comparator.cany()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case LessThanEq:
                return Ops.op_lte.bind(_, cast value, (idx != null ? comp(idx) : Comparator.cany()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case GreaterThan:
                return Ops.op_gt.bind(_, cast value, (idx != null ? comp(idx) : Comparator.cany()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case GreaterThanEq:
                return Ops.op_gte.bind(_, cast value, (idx != null ? comp(idx) : Comparator.cany()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case In:
                return Ops.op_in.bind(_, cast value, (idx != null ? eq(idx) : Equator.any()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case NIn:
                return Ops.op_nin.bind(_, cast value, (idx != null ? eq(idx) : Equator.any()))
                    .wrap(function(_, doc:Anon<Anon<Dynamic>>):Bool return _(cast doc.dotGet(name)));
            case Regexp:
                return Ops.op_regex.bind(_, cast value)
                    .wrap((_, doc:Anon<Anon<Dynamic>>) -> _(doc.dotGet(name)));
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
            min = switch ops[GreaterThanEq] {
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

private typedef Doc = Anon<Anon<Dynamic>>;
