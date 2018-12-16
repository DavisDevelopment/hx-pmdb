package pmdb.ql.ast.nodes;

import pmdb.ql.ast.Value;
import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.ValueResolver.Resolution;
import pmdb.ql.ast.Lnk;

class LnkNode<T> extends ValueNode {
    /* Constructor Function */
    public function new(res:Lnk<T>, ?expr, ?pos) {
        super(expr, pos);

        this.res = res;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):T {
        return res.resolve( ctx.document );
    }

    override function compile() {
        return (function(fn) {
            return (function(ctx: QueryInterp):Dynamic {
                return fn( ctx.document );
            });
        })(res.compile());
    }

    override function clone():ValueNode {
        return new LnkNode(res, expr, position);
    }

    public var res(default, null): Lnk<T>;
}
