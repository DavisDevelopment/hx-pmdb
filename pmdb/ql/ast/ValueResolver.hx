package pmdb.ql.ast;

#if betty
import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.TypedData as Tv;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateOp;
import pmdb.core.Error;
import pmdb.core.Object;

import haxe.io.Bytes;
import haxe.Constraints.Function;
import tannus.math.TMath as Math;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class ValueResolver {
    /* Constructor Function */
    public function new() {
        this.lstack = null;
        this.rstack = null;

        this.rops = {
            add: lbinOp((a:Dynamic, b:Dynamic) -> (a + b)),
            sub: lbinOp((a:Dynamic, b:Dynamic) -> (a - b)),
            mult: lbinOp((a:Dynamic, b:Dynamic) -> (a * b)),
            div: lbinOp((a:Dynamic, b:Dynamic) -> (a / b)),
            mod: lbinOp((a:Dynamic, b:Dynamic) -> (a % b))
        };
    }

/* === Methods === */

    /**
      
     **/
    //public function buildLambdas(val: ValueExpr):Array<Dynamic -> Dynamic> {
        
    //}

    public function resolve(e: ValueExpr):Resolution<Dynamic, Dynamic> {
        return buildResolution( e );
    }

    public function buildResolution(e: ValueExpr):Resolution<Dynamic, Dynamic> {
        return switch e {
            case ValueExpr.EConst(CNull): rc(null);
            case ValueExpr.EConst(CBool((_:Dynamic) => x)|CString((_:Dynamic) => x)|CFloat((_:Dynamic) => x)|CInt((_:Dynamic) => x)): rc( x );
            case ValueExpr.ECol(name): rcc((o -> Object.of(o).dotGet(name)));
            case ValueExpr.EList(valueExprs): rcc((function(fns, o) return fns.map(x -> x(o))).bind(valueExprs.map(e -> buildResolution( e ).compile()), _));
            case ValueExpr.ECall(fname, args): inlineCall(fname, args);
            case ValueExpr.EUnop(op, EConst(c)): switch [op, c] {
                case [EvUnop.UNeg, ConstExpr.CFloat(n)]: rc(-n);
                case _: throw new ValueNodeError(e, 'Invalid unary operation on {{value}}');
            }
            //case ValueExpr.EUnop(op, )
            case ValueExpr.EBinop(a, b, c): resolveBinop(a, b, c);
            case ValueExpr.EReificate(n): rc(n);
            case _: throw new Error('Unexpected $e');
        }
    }
    private inline function rv<T>(v:ValueExpr, fn:Dynamic -> T):Resolution<Object<Dynamic>, T> {
        return buildResolution( v ).map( fn );
    }

    private function inlineCall(name:String, args:Array<ValueExpr>):Resolution<Dynamic, Dynamic> {
        throw new NotImplementedError();
        //return switch [name, args] {
            //case ['abs', [n]]: buildResolution( n ).map(function(n: Float) return Math.abs( n ));
            //case ['max', [x, y]]: rbv(x, y, (x:Float, y:Float) -> Math.max(x, y));
            //case ['min', [x, y]]: rbv(x, y, (x:Float, y:Float) -> Math.min(x, y));
            //case ['hex', [v=x]]: rv(x, tfunc1(function(x: TypedData):String {
                //return switch x {
                    //case DNull: throw new Error('Cannot apply hex(?) to NULL');
                    //case Tv.DBytes(b): b.toHex();
                    //case Tv.DString(s): Bytes.ofString(s).toHex();
                    //case Tv.DInteger(i): i.hex(4);
                    //case _: throw new Error('Cannot apply hex(?) to $v');
                //}
            //}));
            //case _: throw new Error('Unknown identifier $name');
        //}
    }

    private function resolveBinop(op:EvBinop, left:ValueExpr, right:ValueExpr):Resolution<Dynamic, Dynamic> {
        return (switch op {
            case EvBinop.OpAdd: rops.add;
            case EvBinop.OpSub: rops.sub;
            case OpMult: rops.mult;
            case OpDiv: rops.div;
            case OpMod: rops.mod;
            case _: throw new Error('Unexpected $op');
        })(left, right);
    }

    private inline function simplify(e: ValueExpr):ValueExpr {
        return switch e {
            case _: e;
        }
    }

    private inline function lbinOp(fn: Dynamic->Dynamic->Dynamic):ValueExpr->ValueExpr->Resolution<Dynamic, Dynamic> {
        return (function(left:ValueExpr, right:ValueExpr):Resolution<Dynamic, Dynamic> {
            return switch [left, right] {
                case [EConst(cuvalue(_) => a), EConst(cuvalue(_) => b)]: rc(fn(a, b));
                case [_, _]: Resolution.binary(buildResolution(left), buildResolution(right), fn);
            }
        });
    }

    private static function cvalue(c: ConstExpr):TypedData {
        return switch c {
            case ConstExpr.CNull: TypedData.DNull;
            case ConstExpr.CBool(b): TypedData.DBool( b );
            case ConstExpr.CFloat(n): TypedData.DFloat( n );
            case ConstExpr.CInt(i): TypedData.DInt( i );
            case ConstExpr.CString(s): TypedData.DClass(String, s);
            case ConstExpr.CRegexp(re): TypedData.DClass(EReg, re);
        }
    }

    private static function cuvalue(c: ConstExpr):Dynamic {
        return switch c {
            case ConstExpr.CNull: null;
            case ConstExpr.CBool(b): b;
            case ConstExpr.CFloat(n): n;
            case ConstExpr.CInt(i): i;
            case ConstExpr.CString(s): s;
            case ConstExpr.CRegexp(re): re;
        }
    }

    private inline function utvalue(t: TypedData):Dynamic {
        return t.getUnderlyingValue();
    }

    private static inline function rc<O, T>(v: T):Resolution<O, T> return cast Resolution.const( v );
    private static inline function rcc<O, T>(fn: O -> T):Resolution<O, T> return Resolution.context( fn );
    private static inline function re(e: ValueExpr):Resolution<Dynamic, Dynamic> return Resolution.expr( e );
    private static inline function rb<TIn, A, B, TOut>(a:Resolution<TIn, A>, b:Resolution<TIn, B>, fn:A->B->TOut):Resolution<TIn, TOut> return Resolution.binary(a, b, fn);
    private inline function rbv<A, B, C>(a:ValueExpr, b:ValueExpr, ab:A->B->C):Resolution<Object<Dynamic>, C> {
        return rb(cast buildResolution(a), cast buildResolution(b), ab);
    }
    private static inline function tfunc1<T>(fn: TypedData->T):Dynamic->T {
        return ((x: Dynamic) -> fn(x.typed()));
    }
    private static inline function tfunc2<T>(fn: TypedData->TypedData->T):Dynamic->Dynamic->T {
        return ((x:Dynamic, y:Dynamic) -> fn(x.typed(), y.typed()));
    }

/* === Variables === */

    public var expr(default, null): ValueExpr;
    //public var stack(default, null): Array<Ctx -> Dynamic>;
    private var lstack(default, null): Null<Array<Dynamic -> Dynamic>>;
    private var rstack(default, null): Null<Resolution<Dynamic, Dynamic>>;
    //private var ctx(default, null): Ctx;
    private var rops(default, null): {add:Dynamic->Dynamic->Dynamic, sub:Dynamic->Dynamic->Dynamic, mult:Dynamic->Dynamic->Dynamic, div:Dynamic->Dynamic->Dynamic, mod:Dynamic->Dynamic->Dynamic};
}

@:forward
abstract Resolution<Src, T> (EResolution<Src, T>) from EResolution<Src, T> to EResolution<Src, T> {

    @:op(A & B)
    public inline function map<O>(fn: T -> O):Resolution<Src, O> {
        return RMapped(this, fn);
    }

    /**
      "compile" [this] Resolution into a Lambda
     **/
    public function compile<Src2>():Src->T {
        return switch this {
            case RConstant(x): (_ -> x);
            case RContextual(fn): (o -> fn( o ));
            case RMapped(res, fn):
                cast (function(ab:Src->Src2, bc:Src2->T) {
                    return ((o: Src) -> bc(ab(o)));
                })(cast res.compile(), cast fn);
            case _: null;
        }
    }

    public function resolve(o: Src):T {
        return switch this {
            case RConstant(c): c;
            case RContextual(get): get( o );
            case RMapped(src, get): get(src.resolve( o ));
            case RBinary(a, b, binary): binary(a.resolve(o), b.resolve(o));
            case _: null;
        }
    }

    @:from
    public static inline function res<A, B>(r: EResolution<A, B>):Resolution<A, B> {
        return r;
    }

    @:from
    public static inline function context<Src, Val>(get: Src -> Val):Resolution<Src, Val> {
        return RContextual( get );
    }

    @:from
    public static inline function expr(e: ValueExpr):Resolution<Dynamic, Dynamic> {
        return RExpression( e );
    }

    @:from
    public static inline function const<T>(c: T):Resolution<Dynamic, T> {
        return RConstant( c );
    }

    public static inline function binary<TIn, TInA, TInB, TOut>(a:Resolution<TIn, TInA>, b:Resolution<TIn, TInB>, fn:TInA->TInB->TOut):Resolution<TIn, TOut> {
        return RBinary(a, b, fn);
    }
}

enum EResolution<Src, T> {
    RExpression(expr: ValueExpr): EResolution<Dynamic, Dynamic>;
    RConstant(value: T): EResolution<Dynamic, T>;
    RContextual(get: Src -> T): EResolution<Src, T>;
    RMapped<Src2>(src:Resolution<Src, Src2>, get:Src2->T): EResolution<Src, T>;
    RBinary<TInA, TInB>(left:Resolution<Src, TInA>, right:Resolution<Src, TInB>, fn:TInA->TInB->T):EResolution<Src, T>;
}

typedef Ctx = pmdb.ql.ast.nodes.PredicateContext;

class ValueNodeError extends Error {
    /* Constructor Function */
    public function new(node:ValueExpr, msg:String, ?pos:haxe.PosInfos):Void {
        super('', pos);
        this.node = node;
        _msg = (function() {
            return msg.replace('{{value}}', Std.string(node));
        });
    }

/* === Variables === */

    public var node: ValueExpr;
}
#end
