package pmdb.ql.ast.nodes.value;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ast.Value;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
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

class BuiltinCallNode extends CompoundValueNode {
    public function new(name:String, values, ?builtin, ?e, ?pos) {
        super(values, e, pos);
        this.name = name;

        this.builtin = builtin;
    }

/* === Methods === */

    function fn(i: QueryInterp):Null<BuiltinFunction> {
        return 
        if (builtin == null)
            builtin = i.builtins[name];
        else builtin;
    }

    override function clone():ValueNode {
        return new BuiltinCallNode(name, childValues.map(x->x.clone()), builtin, expr, position);
    }

    override function eval(ctx: QueryInterp):Dynamic {
        return switch fn( ctx ) {
            case null:
                throw new Error('No builtin "$name" found');

            case fn:
                fn.safeApply(childValues.map(x -> x.eval( ctx )));
        }
    }

    override function getExpr():ValueExpr {
        return ValueExpr.make(ECall(name, [for (node in childValues) node.getExpr()]));
    }

    override function compile() {
        var bfn = _context != null ? fn(_context) : null;
        if (bfn == null)
            throw new Error('Cannot locate function $name');
        final values = childValues.map(v -> v.compile());
        return function(doc:Dynamic, params:Array<Dynamic>):Dynamic {
            return bfn.safeApply(values.map(v -> v(doc, params))).getUnderlyingValue();
        }
    }

/* === Fields === */

    public var name(default, null): String;

    private var builtin(default, null): Null<BuiltinFunction>;
}
