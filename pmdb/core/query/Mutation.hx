package pmdb.core.query;

import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.update.Update as Node;

import haxe.PosInfos;
import haxe.ds.Option;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;

@:forward
abstract Mutation<Item> (Node) from Node to Node {
    @:from
    public static inline function fromUpdateExpr<I>(expr: UpdateExpr):Mutation<I> {
        return StoreQueryInterface.globalCompiler.compileUpdate( expr );
    }

    @:from
    public static inline function fromHsExpr<I>(expr: hscript.Expr):Mutation<I> {
        return fromUpdateExpr(StoreQueryInterface.globalParser.readUpdate( expr ));
    }

    @:from
    public static inline function fromString<I>(code: String):Mutation<I> {
        return fromUpdateExpr(StoreQueryInterface.globalParser.parseUpdate( code ));
    }
}

