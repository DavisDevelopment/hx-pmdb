package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateOp;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

/**
  this class is the basemost class for Predicate Expressions
 **/
class PredicateNode extends QueryNode {
    /* Constructor Function */
    public function new(?expr:PredicateExpr, ?position:PosInfos):Void {
        super( position );

        this.expr = expr;
    }

/* === Methods === */

    /**
      builds and returns a PredicateExpr equivalent to [this]
     **/
    public function getExpr():PredicateExpr {
        if (expr != null) {
            return expr;
        }
        else {
            throw new NotImplementedError();
        }
    }

    override function createSimilar(args:Array<Dynamic>):QueryNode {
        var targs = args.map(v -> (v : Dynamic).typed());
        return switch args {
            case []: super.createSimilar([null, null]);
            case [DEnum(PredicateExpr, _)]|[DEnum(PredicateExpr, _), null]: super.createSimilar([args[0], null]);
            default: super.createSimilar(args);
        }
    }

/* === Properties === */

/* === Variables === */

    private var expr(default, null): Null<PredicateExpr>;
}