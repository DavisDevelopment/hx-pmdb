package pmdb.ql.ast.nodes.update;

import hscript.Expr;

import pmdb.ql.QueryInterp;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.ValueNode;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.ds.Ref;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class Update extends QueryNode {
    /* Constructor Function */
    public function new(?expr:UpdateExpr, ?pos) {
        super( pos );

        this.expr = null;
    }

/* === Methods === */

    /**
      create and return a deep-copy of [this] node
     **/
    public function clone():Update {
        return new Update(expr, position);
    }

    /**
      evaluate [this] node
     **/
    public function eval(ctx: QueryInterp):Void {
        throw new NotImplementedError('pmdb.ql.ast.nodes.Update.eval');
    }

    /**
      'compile' [this] node to a standalone lambda
     **/
    public function compile():QueryInterp->Void {
        return eval.bind(_);
    }

    /**
      faster, more ast-independant method of 'compilation' to a lambda
     **/
    public function compileNew():(oldDoc:Doc, newDoc:Ref<Doc>, params:Array<Dynamic>)->Void {
        //
        throw 'fewp';
    }

    /**
      build and return an optimized alternative for [this] node
     **/
    public function optimize():Update {
        return this;
    }

    /**
      check whether [this] node is equal to [other]
     **/
    override function equals(other: QueryNode):Bool {
        return (this == other);
    }

    /**
      build and return the equivalent UpdateExpr value for [this] node
     **/
    public function getExpr():UpdateExpr {
        throw new NotImplementedError();
    }

    /**
      build and return an hscript Expr that (if interpreted) will perform the same task as [this] node
     **/
    public function getHScriptExpr():Expr {
        throw new NotImplementedError();
    }

/* === Fields === */

    public var expr(default, null): Null<UpdateExpr>;
}
