package pmdb.ql.ast;

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

import pm.Pair;
import pm.Ref;

import pm.Functions.fn;
import Std.is as isType;

using StringTools;
using pm.Strings;
using pm.Arrays;
//using tannus.async.OptionTools;
//using tannus.FunctionTools;
using pm.Options;
using pm.Functions;
using pmdb.ql.ts.DataTypes;

using pm.Options;
using pm.Functions;

class Predicates {}

class PredicateExpressions {
    public static inline function isBoolOp(e: PredicateExpr):Bool {
        return e.match(POpBoolAnd(_,_)|POpBoolOr(_,_)|POpBoolNot(_));
    }

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

        var result = null;
        inline function handle(a:ValueExpr, b:ValueExpr, kc:Dynamic->IndexConstraint<Dynamic, Dynamic>) {
            var tmp = kv(a, b);
            if (indices.exists(tmp.key)) {
                result = new QueryIndex(indices[tmp.key], kc(tmp.value));
            }
        }

        var usableExpr = getIndexableExpr( expr );
        trace('$usableExpr');

        if (usableExpr == null)
            return null;
        switch ( usableExpr ) {
            case Pe.POpExists(columnName(_)=>name):
                if (indices.exists(name))
                    return new QueryIndex(indices[name]);

            case Pe.POpEq(a, b):
                handle(a, b, fn(ICKey(_)));
                trace(result);
            
            case Pe.POpEq(columnName(_)=>name, extractConstValue(_).getValue()=>val):
                if (indices.exists(name)) {
                    return new QueryIndex(indices[name], ICKey(val));
                }

            case Pe.POpEq(extractConstValue(_).getValue()=>val, columnName(_)=>name):
                if (indices.exists(name)) {
                    return new QueryIndex(indices[name], ICKey(val));
                }

                
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

        return result;
    }

    static function kv(a:ValueExpr, b:ValueExpr):{key:String, value:Dynamic} {
        var name = nor(columnName(a), columnName(b));
        var val = extractConstValue(a).orOpt(extractConstValue(b)).getValue();
        assert(name != null && val != null, 'uStoopid');
        return {key:name, value:val};
    }

    public static function plan(indexes:Map<String, Idx>, thePlan:Plan):Void {
        //var res = expr;
        var pp = _plan_(thePlan.check.get(), indexes);
        switch pp {
            case {left:exprRef, right:idx}:
                thePlan.check.assign(exprRef.get());
                switch idx {
                    case Some(qi):
                        thePlan.index.assign( qi );

                    case None:
                        //
                }

            case other:
                throw 'wtf';
        }
    }

    static function _plan_(e:PredicateExpr, indexes:Map<String, Idx>):Pair<pm.Ref<PredicateExpr>, Option<QueryIndex<Dynamic, Dynamic>>> {
        var predicate:pm.Ref<PredicateExpr> = pm.Ref.to( e );
        var traversalIndex:Option<QueryIndex<Dynamic, Dynamic>> = None;
        switch e {
            // $left && $right
            case POpBoolAnd(left, right):
                //trace(left, right);
                //trace('${getIndexableExpr(left)}, ${getIndexableExpr(right)}');
                switch [getIndexableExpr(left), getIndexableExpr(right)] {
                    case [null, null]:
                        null;

                    case [pe, _]|[null, pe]:
                        var rest = Pe.PNoOp;
                        if (left.equals(pe)) {
                            rest = right;
                        }
                        else if (right.equals(pe)) {
                            rest = left;
                        }
                        //trace( pe );

                        var qi = getTraversalIndex(pe, indexes);
                        if (qi != null) {
                            traversalIndex = Some(qi);
                            if (rest != null) {
                                predicate.assign( rest );
                            }
                        }

                    default:
                        //
                }

            // betty
            case other:
                switch (getIndexableExpr(other)) {
                    case null:
                        //

                    case ide:
                        var rest = Pe.PNoOp;
                        var qi = getTraversalIndex(ide, indexes);
                        trace( qi );

                        if (qi != null) {
                            traversalIndex = Some( qi );
                            if (rest != null) {
                                predicate.assign( rest );
                            }
                        }
                }

            //case other:
                //
        }

        var res = new Pair(predicate, traversalIndex);
        trace(res);

        return res;
    }

    /**
      determine whether the given PredicateExpr is an indexible one
     **/
    public static function getIndexableExpr(pe: PredicateExpr):Null<PredicateExpr> {
        return switch ( pe ) {
            case Pe.POpEq(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            case Pe.POpExists(ce=(isColumn(_)=>true)): pe;
            case Pe.POpGt(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            //case Pe.POpGt(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            case Pe.POpGte(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            //case Pe.POpGte(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            case Pe.POpLt(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            //case Pe.POpLt(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            case Pe.POpLte(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            //case Pe.POpLte(a, b): isIndexableBinaryArgs(a, b) ? pe : null;

            //case Pe.POpInRange(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            case Pe.POpIn(a, b): isIndexableBinaryArgs(a, b) ? pe : null;
            //case Pe.POpIn(a, b): Pe.POpIn(ce, ve);
            case Pe.POpBoolAnd(a, b): nor(getIndexableExpr(a), getIndexableExpr(b));
            default: null;
        }
    }

    static function isIndexableBinaryArgs(a:ValueExpr, b:ValueExpr):Bool {
        if (isColumn( a )) return isConst( b );
        if (isConst( a )) return isColumn( b );
        return false;
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

    public static function map(expr:PredicateExpr, fun:PredicateExpr->PredicateExpr):PredicateExpr {
        return switch expr {
            case Pe.POpBoolAnd(a, b): Pe.POpBoolAnd(fun(a), fun(b));
            case Pe.POpBoolOr(a, b): (Pe.POpBoolOr(fun(a), fun(b)));
            case Pe.POpBoolNot(sub): (Pe.POpBoolNot(fun(sub)));
            default: fun( expr );
        }
    }

    public static function simplify(e:PredicateExpr):PredicateExpr {
        //e.simplify
        return map(_simplify_(e), _simplify_);
    }
    static function _simplify_(e: PredicateExpr):PredicateExpr {
        switch e {
            case POpBoolAnd(pred, PNoOp)|POpBoolAnd(PNoOp, pred):
                return _simplify_( pred );

            case POpBoolOr(pred, PNoOp)|POpBoolOr(PNoOp, pred):
                return PNoOp;

            case POpBoolNot(simplify(_) => neg):
                return switch neg {
                    case POpEq(a, b): POpNotEq(a, b);
                    case POpNotEq(a, b): POpEq(a, b);
                    case _: POpBoolNot(neg);
                }

            case POpEq(a, b):
                return simplify(POpEq(a.simplify(), b.simplify()));

            case _:
                return e;
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

    public static function simplify(e:ValueExpr):ValueExpr {
        return map(e, _simplify_);
    }
    static function _simplify_(e: ValueExpr):ValueExpr {
        return switch expr(e) {
            case _: e;
        }
    }

    public static function expr(e: ValueExpr) {
        return e.expr;
    }

    public static function print(e:ValueExpr, compat:Bool=false) {
        return switch e.expr {
            case EVoid: 'undefined';
            case EThis: 'this';
            case EReificate(argn): 'arguments[$argn]';
            case EConst(c): switch c {
                case ConstExpr.CBool((_:Dynamic)=>x), CFloat((_:Dynamic)=>x), CInt((_:Dynamic)=>x), CString((_:Dynamic)=>x): Std.string(x);
                case ConstExpr.CNull: 'null';
                case ConstExpr.CCompiled(v): Std.string(v);
                case ConstExpr.CRegexp(re): '$re';
            }
            case ECol(n): n;
            case ECast(_, _): Std.string(e.expr);
            case ECall(f, args): '$f('+[for (x in args) print(x, compat)].join(', ')+')';
            case EUnop(UNeg, x): '-'+print(x, compat);
            case EBinop(printBinop(_)=>op, print(_, compat)=>a, print(_, compat)=>b): '$a $op $b';
            case EList(vals): '['+[for (x in vals) print(x, compat)].join(', ')+']';
            case EObject(fields): 
                (
                '{' +
                 [for (f in fields) (f.k+': '+print(f.v, compat))].join(',') +
                '}'
                );
            case EArrayAccess(a, i): print(a, compat) + '['+print(i, compat)+']';
            case EAttr(o, n): print(o, compat) + '.' + n;
            case ERange(a, b): '['+print(a,compat)+'...'+print(b, compat)+']';
        }

    }

    static function printBinop(op:EvBinop) {
        return switch op {
            case OpAdd: '+';
            case OpSub: '-';
            case OpMult: '*';
            case OpDiv: '/';
            case other: throw 'unsupported $other';
        }
    }
}

private typedef Idx = pmdb.core.Index<Dynamic, Dynamic>;

@:structInit
class Plan {
    public var index : Ref<QueryIndex<Dynamic, Dynamic>>;
    public var check : Ref<PredicateExpr>;

    public function toString():String {
        return Std.string({
            index: index.toString(),
            check: check.toString()
        });
    }
}