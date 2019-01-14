package pmdb.ql.ast.nodes.update;

import pmdb.core.TypedValue;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.ValueNode;
import pmdb.core.ds.Ref;
import pmdb.core.Error;
import pmdb.ql.ast.ASTError;
import pmdb.core.Object;
import pmdb.core.DotPath;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

import pmdb.core.Assert.assert;
import Slambda.fn;

using Type;
using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class DeleteUpdate extends UnaryUpdate {
    /* Constructor Function */
    public function new(v, ?e, ?pos) {
        super(v, e, pos);
        //
    }

    override function compile():QueryInterp -> Void {
        if (_del == null)
            _computeDelValue();
        var atoms:Array<Ref<Object<Dynamic>>->Void> = [];
        switch _del {
            case DField(fieldName):
                atoms.push(
                  (function(fieldName: String) {
                      var path = DotPath.fromPathName(fieldName);
                      return function(out: Ref<Object<Dynamic>>) {
                          //out.value.dotRemove( fieldName );
                          path.del(out.value);
                      }
                  })(fieldName)
                );

            case other:
                throw new Error('$other is not yet supported');
        }

        if (atoms.length == 1) {
            return function(q: QueryInterp) {
                atoms[0](q.newDoc());
            }
        }
        else {
            return function(q: QueryInterp) {
                var ref = q.newDoc();
                for (atom in atoms) {
                    atom( ref );
                }
            }
        }
    }

    /**
      evaluate [this] update-operation
     **/
    override function eval(c: QueryInterp):Void {
        if (_del == null)
            _computeDelValue();
        assert(_del != null, "Wtf? [_computeDelValue] failed");
        super.eval( c );
    }

    override function apply(c:QueryInterp, v:ValueNode, doc:Ref<Object<Dynamic>>) {
        switch _del {
            case DField(fieldName):
                doc.value.dotRemove( fieldName );

            case other:
                throw new Error('$other is not yet supported');
        }
    }

    override function validate() {
        super.validate();
    }

    override function getExpr():UpdateExpr {
        if (expr == null)
            expr = UpdateExpr.UDelete(value.getExpr());
        return expr;
    }

    function _computeDelValue() {
        var vex = value.getExpr();
        assert(vex != null, '[${value.getClass().getClassName()}::getExpr()] failed to return a ValueExpr');

        _del = switch vex.expr {
            case ECol(column): DField(column);
            case EArrayAccess(o, _.expr => ERange(x, y)) if (validIndexExpr(x) && validIndexExpr(y)):
                throw new NotImplementedError("DItemRange(...)");
            case EArrayAccess(l, r) if (validLefthand(l) && validRighthand(r)):
                throw new NotImplementedError("DItem(...)");
            default:
                throw new Unexpected(vex, 'Cannot construct Deletion from $vex');
        }
    }

    function validLefthand(e: ValueExpr):Bool {
        return switch e.expr {
            case ECol(_):true;
            case EArrayAccess(l, k): (validLefthand(l) && validIndexExpr(k));
            case EList(a): a.every(x -> validLefthand(x));
            case _: false;
        }
    }

    function validRighthand(e: ValueExpr) {
        return validIndexExpr( e );
    }

    function validIndexExpr(e: ValueExpr):Bool {
        return switch e.expr {
            case EConst(c): switch c {
                case CBool(_), CCompiled({type:TScalar(TBoolean)}): true;
                case CInt(_) | CFloat(_) | CCompiled({type:TScalar(TInteger|TDouble)}): true;
                case CString(_) | CCompiled({type:TScalar(TString)}): true;
                case other: false;
            }
            case ERange(validIndexExpr(_)=>true, validIndexExpr(_)=>true): true;
            case EList((_.every(x->validIndexExpr(x))) => true): true;
            case other: false;
        }
    }

/* === Fields === */

    public var _del(default, null): Null<Deletion> = null;
}

enum Deletion {
    DField(field: String);
    DItem(acc:ValueNode, index:Dynamic);
    DItemRange(acc:ValueNode, start:Dynamic, end:Dynamic);
}
