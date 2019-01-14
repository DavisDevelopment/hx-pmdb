package pmdb.core.query;

import pmdb.core.TypedValue;
import pmdb.core.ds.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;
import pmdb.ql.ast.Value;
import pmdb.ql.QueryIndex;

import pmdb.ql.*;
import pmdb.ql.ast.*;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.ASTError;

import haxe.macro.Expr;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.core.ds.tools.Options;
using pmdb.ql.ts.DataTypes;

/**
  [= TODO =]
 **/
class QueryPartial {
    public function new(params, body) {
        this.parameters = params.copy();
        this._query = body;
    }

/* === Methods === */

    public static function fromFunctionDecl(decl: Function) {
        //TODO..
        throw 'ass';
    }

    /**
      [TODO] 
        compile [= _query =] into a lambda expression which returns a properly bound query-tree
     **/
    function _compile_() {
        final pcomp = new PartialCompiler( this );
        //...[= MAGIC =]
        throw 'There is no magic. Magic isn\'t real; It never was. You\'re a failure.';
    }

/* === Variables === */

    private var _query(default, null): QueryPartialKind;
    public var parameters(default, null): Array<PartialParameter>;
}

enum QueryPartialKind {
    Find(x:PredicateExpr);
    Update(x:UpdateExpr, ?y:PredicateExpr);
    //TODO
}

typedef PartialParameter = {
    final name: String;
    final type: DataType;
}

class PartialCompiler extends pmdb.ql.ast.QueryCompiler {
    public function new(q) {
        //initialize variables
        super();

        this.query = q;
    }

    public function compileFind(pred: PredicateExpr):(args: Array<Dynamic>) -> Check {
        return switch pred {
            case PNoOp: a -> PNoOp;
            case POpEq(l, r): ((l, r) -> a -> POpEq(l(a), r(a)))(value(l), value(r));
            case POpNotEq(l, r): ((l, r) -> a -> POpNotEq(l(a), r(a)))(value(l), value(r));
            case POpLt(l, r): ((l, r) -> a -> POpLt(l(a), r(a)))(value(l), value(r));
            case POpGt(l, r): ((l, r) -> a -> POpGt(l(a), r(a)))(value(l), value(r));
            case POpGte(l, r): ((l, r) -> a -> POpGte(l(a), r(a)))(value(l), value(r));
            case POpLte(l, r): ((l, r) -> a -> POpLte(l(a), r(a)))(value(l), value(r));
            default: throw 'ass';
        }
    }

    public function compileUpdate(mut:UpdateExpr, ?pred:PredicateExpr):(args: Array<TypedValue>)->Update {
        throw 'poop';
    }

    function value(expr: ValueExpr):(args: Array<Dynamic>)->ValueExpr {
        return switch (expr.expr) {
            case EVoid: a -> expr;
            case EThis: a -> expr;
            case EReificate(index): 
                return compileParameter( index );
            case EConst(c): a -> expr;
            case EAttr(o, name):
                var oo = value( o );
                return a -> EAttr(oo(a), name);
            case EArrayAccess(a, i):
                return ((a, i) -> args -> EArrayAccess(a(args), i(args)))(value(a), value(i));

            case EList(vals):
                return (vals -> args -> EList(vals.map(v -> v(args))))(vals.map(v -> value(v)));

            case EUnop(op, val):
                return (val -> args -> EUnop(op, val))(value(val));
            
            case EBinop(op, l, r):
                return ((l, r) -> args -> EBinop(op, l(args), r(args)))(value(l), value(r));

            case ECol(name):
                var fn = compileNamedParameter( name );
                if (fn == null) {
                    return a -> expr;
                }
                return fn;
                
            case other:
                throw new Error('Unexpected $other');
        }
    }

    override function vnode(expr: ValueExpr) {
        switch ( expr.expr ) {
            case ValueExprDef.EReificate( i ):
                return vnode(compileParameter( i ));

            case ValueExprDef.ECol('arguments'):
                throw new Error('NotImplemented: inline [arguments] reference as a tuple of the parameters');

            case ValueExprDef.ECol(name):
                for (i in 0...query.parameters.length) {
                    if (query.parameters[i].name == name) {
                        return vnode(compileParameter( i ));
                    }
                }
                return super.vnode( expr );

            default:
                return super.vnode( expr );
        }
    }

    private function compileParameter(i: Int) {
        //if (!query.parameters[i].type.unify(parameters[i].type))
            //throw new Error('Cannot unify (${query.parameters[i].type}, ${parameters[i].type})');
        return (args: Array<Dynamic>) -> EConst(CCompiled(
            new TypedValue(
                args[i],
                query.parameters[i].type
            )
        ));
    }

    private function compileNamedParameter(name: String):Null<Array<Dynamic> -> ValueExpr> {
        for (i in 0...query.parameters.length) {
            if (query.parameters[i].name == name) {
                return compileParameter( i );
            }
        }
        return null;
    }

    private var query(default, null): QueryPartial;
    private var parameters:Null<Array<TypedValue>> = null;
}

