package pmdb.ql.ast;

import tannus.ds.Lazy;

import hscript.Expr;

//import pmdb.core.Error;

@:forward
abstract Value<T> (EValue<T>) from EValue<T> to EValue<T> {
    @:to
    public static function get<T>(v: Value<T>):T {
        return switch v {
            case VConstant(c): c;
            case VComputed(c): switch c {
                case CVLazy(v): v.get();
                //case CVDerived()
            }
        }
    }
}

enum EValue<T> {
    VConstant(value: T):EValue<T>;
    VComputed(value: EComputedValue<T>):EValue<T>;
}

enum EComputedValue<T> {
    CVLazy(v: Lazy<T>):EComputedValue<T>;
    //CVDerived(fn: T -> Value<T>):EComputedValue<T>;
}

enum ValueExpr {
    EReificate(ident: String);
    ETabColRef(table:String, col:EValueExpr);
    ECol(column: String);
    ECall(args: Array<EValueExpr>);
    EUnop(op:EvUnop, e:EValueExpr);
    EBinop(op:EvBinop, l:EValueExpr, r:EValueExpr);
}

enum EvUnop {
    UInc;
    UDec;
    UNeg;
}

enum EvBinop {
    OpAdd;
    OpMult;
    OpDiv;
    OpSub;
    OpAssign;
    OpAnd;
    OpOr;
    OpXOr;
    OpShl;
    OpShr;
    OpUShr;
    OpMod;
    OpInterval;
    OpArrow;
}
