package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
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

class ValueOperatorNode extends ValueNode {
    /* Constructor Function */
    public function new(op, ?e, ?pos) {
        super(e, pos);

        this.op = op;
        this._fn = null;
    }

/* === Methods === */

    inline function get_fn():Null<BuiltinFunction> {
        return _fn;
    }

    inline function gfn(i: QueryInterp) {
        if (fn == null) {
            _fn = cast i.builtins[opmap(i)[op]];
        }
        return _fn;
    }

    private function opmap(i: QueryInterp):Map<String, String> {
        throw 'Betty';
    }

    override function eval(i: QueryInterp):Dynamic {
        return null;
    }

    override function attachInterp(i: QueryInterp) {
        super.attachInterp( i );
        gfn( interp );
    }

/* === Fields === */

    public var op(default, null): String;
    public var fn(get, never): Null<BuiltinFunction>;

    private var _fn(default, null): Null<BuiltinFunction>;
}
