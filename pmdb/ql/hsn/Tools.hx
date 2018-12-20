package pmdb.ql.hsn;

import hscript.Expr;
import hscript.Expr.ExprDef;
import hscript.Expr.ExprDef as Ed;
import haxe.macro.Context;
import haxe.macro.Expr as MacroExpr;
import haxe.macro.Expr as Me;
import haxe.macro.Expr.ExprDef as Med;
import haxe.macro.Expr.Binop;

using hscript.Tools;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

using Lambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;

class Tools {
    public static function toExpr(expr: MacroExpr):Expr {
        var edef:Ed = switch (expr.expr) {
            case Med.EBreak: Ed.EBreak;
            case Med.EContinue: Ed.EContinue;
            case Med.EArray(e, idx): Ed.EArray(toExpr(e), toExpr(idx));
            case Med.EArrayDecl(values): Ed.EArrayDecl(values.map(toExpr));
            case Med.EBinop(binop, left, right): switch (printBinop(binop)) {
                case other: Ed.EBinop(other, toExpr(left), toExpr(right));
            }
        }
    }

    public static function printBinop(binop: Binop):String {
        return switch ( binop ) {
            case Binop.OpAdd: '+';
            case Binop.OpAnd: '&';
            case Binop.OpAssign: '=';
            case Binop.OpArrow: '=>';
            case Binop.OpBoolAnd: '&&';
            case Binop.OpBoolOr: '||';
            case Binop.OpDiv: '/';
            case Binop.OpEq: '==';
        }
    }
}
