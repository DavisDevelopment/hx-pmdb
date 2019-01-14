package pmdb.ql.hsn;

import hscript.Expr;
import hscript.Expr.ExprDef;
import hscript.Expr.ExprDef as Ed;
import haxe.macro.Context;
import haxe.macro.Expr as MacroExpr;
import haxe.macro.Expr as Me;
import haxe.macro.Expr.ExprDef as Med;
import haxe.macro.Expr.Binop;
import haxe.macro.Expr.Unop;
import haxe.macro.Printer;

using hscript.Tools;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;

using Lambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;

class Tools {
    inline static function ee(a: MacroExpr):Expr return toExpr(a);

    public static function toExpr(expr: MacroExpr):Expr {
        var pos = expr.pos;
        var edef:Ed = switch (expr.expr) {
            case Med.EBreak: Ed.EBreak;
            case Med.EContinue: Ed.EContinue;
            case Med.EArray(e, idx): Ed.EArray(toExpr(e), toExpr(idx));
            case Med.EArrayDecl(values): Ed.EArrayDecl(values.map(toExpr));
            case Med.EBinop(binop, left, right): Ed.EBinop(printBinop(binop), toExpr(left), toExpr(right));
            case Med.EUnop(unop, prefix, expr): Ed.EUnop(printUnop(unop), prefix, toExpr(expr));
            case Med.EBlock(exprs): Ed.EBlock(exprs.map( toExpr ));
            case Med.ECall(e, params): Ed.ECall(toExpr(e), params.map(toExpr));
            case Med.ECast(_, _), Med.ECheckType(_, _): throw 'not implemented';
            case Med.EFunction(name, func): throw 'not implemented';
            case Med.EDisplay(_, _), Med.EDisplayNew(_): throw 'dafuq?';
            case Med.EConst(haxe.macro.Expr.Constant.CIdent(id)): Ed.EIdent(id);
            case Med.EConst(CFloat(number)): Ed.EConst(CFloat(Std.parseFloat(number)));
            case Med.EConst(CInt(number)): Ed.EConst(CInt(Std.parseInt(number)));
            case Med.EConst(CString(number)): Ed.EConst(CString(number));
            case Med.EConst(CRegexp(pattern, opts)): Ed.ENew('EReg', [EConst(CString(pattern)), EConst(CString(opts))]);
            case Med.EField(a, b): Ed.EField(ee(a), b);
            case Med.EFor((macro $i{v} in $it), e): Ed.EFor(v, ee(it), ee(e));
            case Med.EFor(other, _): throw 'UnsupportedExpression: macro for (${mep.printExpr(other)}) {...}';
            case Med.EIf(a, b, null): Ed.EIf(ee(a), ee(b), null);
            case Med.EIf(a, b, c): Ed.EIf(ee(a), ee(b), ee(c));
            case Med.EMeta(entry, expr): Ed.EMeta(entry.name, entry.params!=null?entry.params.map(toExpr):null, ee(expr));
            case Med.ENew(t, params): Ed.ENew(mep.printTypePath(t), params.map(toExpr));
            case Med.EObjectDecl(fields): Ed.EObject(fields.map(f -> {name:f.field, e:ee(f.expr)}));
            case Med.EParenthesis(expr): Ed.EParent(ee(expr));
            case Med.EReturn(null): Ed.EReturn(null);
            case Med.EReturn(e): Ed.EReturn(ee(e));
            case Med.ESwitch(e, cases, edef): Ed.ESwitch(ee(e), cases.map(function(kace) {
                return {
                    values: kace.values.map( toExpr ),
                    expr: kace.expr != null ? ee(kace.expr) : ee(macro trace('placeholder..'))
                };
            }), edef != null ? ee(edef) : null);
            case Med.ETernary(c, a, b): Ed.ETernary(ee(c), ee(a), ee(b));
            case Med.EThrow(e): Ed.EThrow(ee(e));
            case Med.ETry(e, [ec={type:_.match(macro : StdTypes.Dynamic)=>true}]): Ed.ETry(ee(e), ec.name, null, ee(ec.expr));
            case Med.ETry(_, catches): throw 'UnsupportedExpression: macro try {...} catch (${catches[0].name} : ${mep.printComplexType(catches[0].type)}) {...}';
            case Med.EUntyped(e): ee(e);
            case Med.EVars(vars): Ed.EBlock(vars.map(v -> Ed.EVar(v.name, null, if (v.expr != null) ee(v.expr) else null)));
            case Med.EWhile(econd, expr, true): Ed.EWhile(ee(econd), ee(expr));
            case Med.EWhile(econd, expr, false): Ed.EDoWhile(ee(econd), ee(expr));
                //var catches.find(c -> c.type.match(macro : StdTypes.Dynamic))

            //case other: new hscript.Parser().parseString(new Printer().printBinop(
        }

        #if hscriptPos
        return {
            e: edef,
            origin: pos.file,
            pmin: pos.min,
            pmax: pos.max,
            line: -1
        };
        #else
        return edef;
        #end
    }

    public static function printUnop(unop: Unop):String return mep.printUnop( unop );
    public static function printBinop(binop: Binop):String {
        return mep.printBinop( binop );
        return switch ( binop ) {
            case Binop.OpAdd: '+';
            case Binop.OpAnd: '&';
            case Binop.OpAssign: '=';
            case Binop.OpArrow: '=>';
            case Binop.OpBoolAnd: '&&';
            case Binop.OpBoolOr: '||';
            case Binop.OpDiv: '/';
            case Binop.OpEq: '==';
            case other: '$other';
        }
    }

    /**
     * obtain a copy of [e], with all instances of [what] replaced with [with]
     */
    public static function replace(e:Expr, what:Expr, with:Expr):Expr {
        if (e.equals( what )) {
            return with;
        }
        else {
            return e.map(replacer.bind(_, what, with));
        }
    }

    // mapper method used by [replace]
    private static function replacer(e:Expr, what:Expr, with:Expr):Expr {
        if (e.equals( what  )) {
            return with;
        }
        return e.map(replacer.bind(_, what, with));
    }

    private static var mep = new Printer();
    @:noCompletion
    public static var hsm = new hscript.Macro(cast {file:'betty.hx', min:0, max:1024});
}

class HSExprs {
    public static function convert(expr: Expr):MacroExpr {
        return Tools.hsm.convert( expr );
    }
}

class MacroExprs {
/**
     * obtain a copy of [e], with all instances of [what] replaced with [with]
     */
    public static function replace(e:MacroExpr, what:MacroExpr, with:MacroExpr):MacroExpr {
        if (e.expr.equals( what.expr )) {
            return with;
        }
        else {
            return e.map(replacer.bind(_, what, with));
        }
    }

    // mapper method used by [replace]
    private static function replacer(e:MacroExpr, what:MacroExpr, with:MacroExpr):MacroExpr {
        if (e.expr.equals( what.expr )) {
            return with;
        }
        return e.map(replacer.bind(_, what, with));
    }
}

typedef HSTools = hscript.Macro;
