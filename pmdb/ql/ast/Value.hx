package pmdb.ql.ast;

import tannus.ds.Lazy;

import hscript.Expr;

import pmdb.ql.ast.TypeExpr;
import pmdb.ql.ts.DataType;

//import pmdb.core.Error;

@:forward
abstract Value (ValueExpr) from ValueExpr to ValueExpr {
    
}

@:structInit
class ValueExpr {
    /* Constructor Function */
    public function new(expr:ValueExprDef, type:DataType) {
        this.expr = expr;
        this.type = type;
    }

/* === Variables === */

    public var expr(default, null): ValueExprDef;
    //@:optional
    public var type(default, null): DataType = DataType.TUnknown;

/* === Statics === */

    public static function make(e:ValueExprDef, ?t:DataType):ValueExpr {
        return {expr:e, type:t};
    }
}

@:using(pmdb.ql.ast.Predicates.ValueExpressions)
enum ValueExprDef {
    EVoid;

    // reference to the current context directly
    EThis;

    // bound-value reference
    EReificate(i: Int);

    // constant values
    EConst(c: ConstExpr);

    // column references
    ECol(column: String);

    // attribute access
    EAttr(o:ValueExpr, name:String);

    // <ValueExpr>[$index]
    EArrayAccess(value:ValueExpr, index:ValueExpr);

    // $min...$max
    ERange(min:ValueExpr, max:ValueExpr);

    // $func($args...)
    ECall(func:String, args:Array<ValueExpr>);

    // array($values...)
    EList(values: Array<ValueExpr>);
    
    // { ${field.k}: ${field.v}... }
    EObject(fields: Array<{k:String, v:ValueExpr}>);

    // unary operators
    EUnop(op:EvUnop, e:ValueExpr);

    // binary operators
    EBinop(op:EvBinop, l:ValueExpr, r:ValueExpr);

    // type casting
    ECast(e:ValueExpr, t:TypeExpr);
}

enum ConstExpr {
    CNull;
    CBool(b: Bool);
    CInt(i: Int);
    CFloat(n: Float);
    CString(s: String);
    CRegexp(re: EReg);

    //CTuple(t: Array<ConstExpr>);

    /**
      CCompiled(...) values represent values which have been computed from the AST,
      and which have been determined to be constants (not subject to change during query-execution)
      by the compiler/optimizer during the compilation phase. This will only be created if the executable node-tree structure
      is transformed back to an AST for some reason
     **/
    //CCompiled(value: TypedData);
    CCompiled(value: pmdb.core.TypedValue);
}

enum EvUnop {
    //UInc;
    //UDec;
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
    //OpInterval;
    OpArrow;
}
