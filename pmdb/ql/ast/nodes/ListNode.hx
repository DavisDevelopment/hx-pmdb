package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class ListNode extends ValueNode {
    public function new(values, ?e, ?pos) {
        super(e, pos);

        this.values = values;
        this.constValues = null;
        this.type = TArray(TAny);

        tryConst();
    }

/* === Methods === */

    /**
      determine whether [this] is a 'constant' list-expression
     **/
    inline function tryConst() {
        constValues = new Array();
        var allConst:Bool = true;

        for (node in values) {
            if (node.hasLabel('const')) {
                switch (node.label('const')) {
                    case null:
                        allConst = false;
                        break;

                    case cvalue:
                        constValues.push( cvalue );
                }
            }
            else {
                allConst = false;
                break;
            }
        }

        if ( allConst ) {
            addLabel('const', constValues);
        }
        else {
            constValues = null;
        }
    }

    override function clone():ValueNode {
        return new ListNode(values.map(x -> x.clone()), expr, position);
    }

    override function eval(ctx: QueryInterp):Dynamic {
        if (constValues != null) {
            return constValues;
        }
        else {
            return values.map(x -> x.eval( ctx ));
        }
    }

    override function getChildNodes():Array<QueryNode> {
        return cast values;
    }

    override function compile() {
        if (constValues != null) {
            final cvl = constValues.copy();
            return function(x:Dynamic, y:Array<Dynamic>):Dynamic {
                return cvl;
            }
        }
        else {
            final vals = values.map(x -> x.compile());
            return function(x, y):Dynamic {
                return vals.map(v -> v(x, y));
            }
        }
        //if (constValues != null) {
            //return (constants -> (c -> constants))(constValues.copy());
        //}
        //else {
            //var vals = values.map(x -> x.compile());
            //return ((getters:Array<QueryInterp->Dynamic>) -> ((c: QueryInterp) -> [for (g in getters) g(c)]))( vals );
        //}
    }

    override function optimize():ValueNode {
        if (hasLabel('const')) {
            var tmp:Array<Dynamic> = constValues.copy();
            return new ConstNode(tmp, tmp.typed(), expr, position);
        }
        else {
            return new ListNode(values.map(x -> x.optimize()), expr, position);
        }
    }

    override function getExpr():ValueExpr {
        return ValueExpr.make(EList([for (node in values) node.getExpr()]));
    }

/* === Fields === */

    public var values(default, null): Array<ValueNode>;
    public var constValues(default, null): Null<Array<Dynamic>>;
}
