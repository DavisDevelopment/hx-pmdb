package pmdb.ql.ast;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.ds.Set;
import tannus.math.TMath as M;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.Index;
import pmdb.core.Arch;
import pmdb.core.Comparator;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.ql.QueryIndex;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

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
using pmdb.ql.ts.DataTypes;

class Predicates {}

class PredicateExpressions {
    public static inline function isBoolOp(e: PredicateExpr):Bool {
        return e.match(POpBoolAnd(_,_)|POpBoolOr(_,_)|POpBoolNot(_));
    }

    /*
    public static function iter(e:PredicateExpr, fn:PredicateExpr->Void):Void {
        switch e {
            case Pe.POpBoolAnd(a, b)|Pe.POpBoolOr(a, b):
                fn( a );
                fn( b );

            case Pe.POpBoolNot(x):
                fn( x );

            case _:
                //
        }
    }
    */

    /*
    public static function iterValues(e:PredicateExpr, fn:ValueExpr->Void):Void {
        function vi(ve: PredicateExpr) {
            switch ve {
                case Pe.POpBoolAnd(a, b)|Pe.POpBoolOr(a, b):
                    vi( a );
                    vi( b );

                case Pe.POpBoolNot(x):
                    vi( x );

                case Pe.POpElemMatch(a, b, _) | Pe.POpWith(a, b):
                    fn( a );
                    vi( b );

                case Pe.POpEq(a, b)|Pe.POpNotEq(a, b)|Pe.POpGt(a, b)|Pe.POpLt(a, b)|Pe.POpGte(a, b)|Pe.POpLte(a, b)|Pe.POpIn(a, b)|Pe.POpNotIn(a, b)|Pe.POpContains(a, b)|Pe.POpRegex(a, b)|Pe.POpIs(a, b):
                    fn(a);
                    fn(b);

                case Pe.POpInRange(a, b, c):
                    fn( a );
                    fn( b );
                    fn( c );

                case Pe.POpExists(x): 
                    fn( x );

                case Pe.POpMatch(a, _):
                    fn( a );

                case Pe.PNoOp:
                    return ;
            }
        }

        iter(e, vi);
    }
    */

    //public static function map(e:PredicateExpr, fn:PredicateExpr->PredicateExpr, ?vfn:ValueExpr->ValueExpr):PredicateExpr {
        //if (vfn == null)
            //vfn = FunctionTools.identity;
        //return switch e {
            //case Pe.POpBoolAnd(a, b): POpBoolAnd(fn(a), fn(b));
            //case Pe.POpBoolOr(a, b): POpBoolOr(fn(a), fn(b));
            //case Pe.POpBoolNot(x): POpBoolNot(fn(x));
            //case Pe.PNoOp: Pe.PNoOp;
            //case Pe.POpExists(x): POpExists(vfn(x)); //TODO
            //case Pe.POpMatch(a, b):
                //return POpMatch(vfn(a), b);
            //case Pe.POpEq(a, b)|Pe.POpNotEq(a, b)|Pe.POpGt(a, b)|Pe.POpLt(a, b)|Pe.POpGte(a, b)|Pe.POpLte(a, b)|Pe.POpIn(a, b)|Pe.POpNotIn(a, b)|Pe.POpContains(a, b)|Pe.POpRegex(a, b)|Pe.POpIs(a, b):
                //return Pe.createByIndex(e.getIndex(), [vfn(a), vfn(b)]);
            //case Pe.POpInRange(a, b, c):
                //Pe.POpInRange(vfn(a), vfn(b), vfn(c));
        //}
    //}

    /*
    public static function mapValues(e:PredicateExpr, fn:ValueExpr->ValueExpr):PredicateExpr {
        function vmapper(pe: PredicateExpr):PredicateExpr {
            return switch pe {
                case Pe.POpBoolAnd(a, b): POpBoolAnd(vmapper(a), vmapper(b));
                case Pe.POpBoolOr(a, b): POpBoolOr(vmapper(a), vmapper(b));
                case Pe.POpBoolNot(x): POpBoolNot(vmapper(x));
                case Pe.POpEq(a, b)|Pe.POpNotEq(a, b)|Pe.POpGt(a, b)|Pe.POpLt(a, b)|Pe.POpGte(a, b)|Pe.POpLte(a, b)|Pe.POpContains(a, b)|Pe.POpIn(a, b)|Pe.POpNotIn(a, b)|Pe.POpRegex(a, b)|Pe.POpIs(a, b)|Pe.POpElemMatch(a, b, _):
                    Pe.createByIndex(pe.getIndex(), [fn(a), fn(b)]);
                case Pe.POpExists(x): POpExists(fn(x));
                case Pe.POpInRange(a, b, c):
                    Pe.POpInRange(fn(a), fn(b), fn(c));
                case Pe.POpMatch(a, b):
                    Pe.POpMatch(fn(a), b);
                case Pe.PNoOp: PNoOp;
            }
        }
        return map(e, vmapper);
    }

    public static function replace(e:PredicateExpr, what:PredicateExpr, replacement:PredicateExpr):PredicateExpr {
        return replaceAny(e, x->x.equals(what), (_)->replacement);
    }

    public static function replaceAny(e:PredicateExpr, repl:PredicateExpr->Bool, what:PredicateExpr->PredicateExpr):PredicateExpr {
        if (repl( e )) {
            return what( e );
        }
        return map(e, replaceAny.bind(_, repl, what));
    }
    */

    /**
      ...
     **/
    public static function getTraversalIndex(expr:PredicateExpr, indices:Map<String, pmdb.core.Index<Dynamic, Dynamic>>):Null<QueryIndex<Dynamic, Dynamic>> {
        if (expr.match(PNoOp))
            return null;

        inline function isidx(ce: ValueExpr):Bool {
            return indices.exists(columnName(ce));
        }

        inline function idx(ce: ValueExpr):Null<Index<Dynamic, Dynamic>> {
            return indices[columnName(ce)];
        }

        var usableExpr = getIndexableExpr( expr );
        if (usableExpr == null) return null;
        switch ( usableExpr ) {
            case Pe.POpEq(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name)) {
                    return new QueryIndex(indices[name], ICKey(val));
                }

            case Pe.POpEq(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name)) {
                    return new QueryIndex(indices[name], ICKey(val));
                }

            case Pe.POpExists(columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name]);
                
            case Pe.POpGt(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(BoundingValue.Edge(val)));

            case Pe.POpGt(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(null, BoundingValue.Edge(val)));

            case Pe.POpGte(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(BoundingValue.Inclusive(val)));

            case Pe.POpGte(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(null, BoundingValue.Inclusive(val)));

            case Pe.POpLt(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(null, BoundingValue.Edge(val)));

            case Pe.POpLt(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(BoundingValue.Edge(val)));

            case Pe.POpLte(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(null, BoundingValue.Inclusive(val)));

            case Pe.POpLte(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(BoundingValue.Inclusive(val)));

            case Pe.POpInRange(columnName(_)=>name, extractConstValue(_).getValue()=>min, extractConstValue(_).getValue()=>max):
                if (indices.exists(name))
                    return new QueryIndex(indices[name], ICKeyRange(BoundingValue.Edge(min), BoundingValue.Edge(max)));

            case Pe.POpIn(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name) && Arch.isArray(val))
                    return new QueryIndex(indices[name], ICKeyList(cast val));

            default:
                //
        }
        return null;
    }

    /**
      determine whether the given PredicateExpr is an indexible one
     **/
    public static function getIndexableExpr(pe: PredicateExpr):Null<PredicateExpr> {
        return switch ( pe ) {
            case Pe.POpEq(ce=(isColumn(_)=>true), ve), Pe.POpEq(ve, ce=(isColumn(_)=>true)): pe;
            case Pe.POpExists(ce=(isColumn(_)=>true)): pe;
            case Pe.POpGt(ce=(isColumn(_)=>true), ve=(isConst(_)=>true)): pe;
            case Pe.POpGt(ve=(isConst(_)=>true), ce=(isColumn(_)=>true)): pe;
            case Pe.POpGte(ce=(isColumn(_)=>true), ve=(isConst(_)=>true)): pe;
            case Pe.POpGte(ve=(isConst(_)=>true), ce=(isColumn(_)=>true)): pe;
            case Pe.POpLt(ce=(isColumn(_)=>true), ve=(isConst(_)=>true)): pe;
            case Pe.POpLt(ve=(isConst(_)=>true), ce=(isColumn(_)=>true)): pe;
            case Pe.POpLte(ce=(isColumn(_)=>true), ve=(isConst(_)=>true)): pe;
            case Pe.POpLte(ve=(isConst(_)=>true), ce=(isColumn(_)=>true)): pe;
            case Pe.POpInRange(ce=(isColumn(_)=>true), emin=(isConst(_)=>true), emax=(isConst(_)=>true)): pe;
            case Pe.POpIn(ce=(isColumn(_)=>true), ve=(isConst(_)=>true)): pe;
            case Pe.POpIn(ve=(isConst(_)=>true), ce=(isColumn(_)=>true)): Pe.POpIn(ce, ve);
            case Pe.POpBoolAnd(left, _): getIndexableExpr( left );

            default: null;
        }
    }

    public static inline function isConst(e: ValueExpr):Bool {
        return extractConstValue(e).isSome();
    }

    public static inline function extractConstValue(e: ValueExpr):Option<Dynamic> {
        return switch e.expr {
            case EConst(c): switch c {
                case ConstExpr.CNull: Some(null);
                case CBool(b): Some(b);
                case CFloat(n): Some(n);
                case CInt(n): Some(n);
                case CString(s): Some(s);
                case CRegexp(re): Some(re);
                case CCompiled(v): Some( v.value );
            }
            case EList(values):
                if (values.every(ve -> extractConstValue(ve).isSome()))
                    Some(values.map(x -> extractConstValue(x).getValue()));
                else None;
            default: None;
        }
    }

    public static inline function isColumn(expr: ValueExpr):Bool {
        return columnName(expr) != null;
    }

    public static inline function columnName(expr: ValueExpr):Null<String> {
        return switch ( expr.expr ) {
            case ECol(name): name;
            case EAttr({expr:EThis}, name): name;
            case ECast(ce=(isColumn(_)=>true), _): columnName(ce);
            case _: null;
        }
    }
}

class ValueExpressions {
    static function mkv(d:ValueExprDef, ?type:DataType):ValueExpr {
        return {
            expr: d,
            type: type
        };
    }

    public static function map(e:ValueExpr, fn:ValueExpr -> ValueExpr):ValueExpr {
        return switch e.expr {
            case EVoid, EThis: e;
            case EReificate(_), EConst(_), ECol(_), ECast(_, _): e;
            case ECall(f, args): mkv(ECall(f, [for (x in args) fn(x)]));
            case EUnop(u, e): mkv(EUnop(u, fn(e)));
            case EBinop(b, l, r): mkv(EBinop(b, fn(l), fn(r)));
            case EList(values): mkv(EList([for (x in values) fn(x)]));
            case EObject(fields): mkv(EObject([for (f in fields) {k:f.k, v:fn(f.v)}]));
            case EArrayAccess(array, index): mkv(EArrayAccess(fn(array), fn(index)));
            case EAttr(o, n): mkv(EAttr(fn(o), n));
            case ERange(min, max): mkv(ERange(fn(min), fn(max)));
        }
    }

    public static function expr(e: ValueExpr) {
        return e.expr;
    }
}
