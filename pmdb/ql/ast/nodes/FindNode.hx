package pmdb.ql.ast.nodes;

import pmdb.core.Arch;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Assert.assert;

import pmdb.ql.ast.QlCommand;
import pmdb.ql.ast.nodes.Check;

using pm.Arrays;
using pm.Functions;
using pmdb.Macros;

class FindNode<Item> extends QueryRootNode<Iterable<Item>> {
    /* Constructor Function */
    public function new(check, ?e, ?pos):Void {
        super(e, pos);

        this.check = check;
    }

/* === Methods === */

    override function clone():QueryRootNode {
        return new FindNode(cast(check.clone(), Check), expr, position);
    }

    override function eval(ctx: QueryInterp) {
        assert(ctx.store != null, 'No Store<T> given');
    }

/* === Variables === */

    public var check(default, null): Check;
}
