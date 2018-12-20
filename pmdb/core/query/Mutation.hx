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
abstract Mutation<Item> (EMutation<Item>) from EMutation<Item> to EMutation<Item> {
/* === Instance Methods === */

    public function isStruct():Bool {
        return this.match(StructMutation(_));
    }

    public function isParsed():Bool {
        return this.match(UpdateExprMutation(_)|CompiledMutation(_));
    }

    public function isCompiled():Bool {
        return this.match(CompiledMutation(_));
    }

    public function toUpdate():Update {
        return switch (this) {
            case CompiledMutation(up): up;
            default: throw new Error('Invalid call');
        }
    }

    public function toStruct():Object<Dynamic> {
        return switch (this) {
            case StructMutation( o ): o;
            default: throw new Error('Invalid call');
        }
    }

    public function compile(qi: StoreQueryInterface<Item>):Mutation<Item> {
        return _compile(this, qi);
    }

    @:access( pmdb.core.query.StoreQueryInterface )
    static function _compile<T>(m:Mutation<T>, i:StoreQueryInterface<T>):Mutation<T> {
        switch ( m ) {
            case UpdateExprMutation(expr):
                return _compile(CompiledMutation(i.compileUpdateExpr(expr)), i);

            case HScriptExprMutation(expr):
                return _compile(UpdateExprMutation(i.compileHsExprToUpdate(expr)), i);

            case StringMutation(expr):
                return _compile(UpdateExprMutation(i.compileStringToUpdate(expr)), i);

            case CompiledMutation(up):
                return CompiledMutation(i.init_update(up, true));

            case StructMutation(o):
                return StructMutation( o );
        }
    }

/* === Casting Methods === */

    @:from
    public static inline function fromUpdateExpr<I>(expr: UpdateExpr):Mutation<I> {
        //return StoreQueryInterface.globalCompiler.compileUpdate( expr );
        return UpdateExprMutation( expr );
    }

    @:from
    public static inline function fromHsExpr<I>(expr: hscript.Expr):Mutation<I> {
        //return fromUpdateExpr(StoreQueryInterface.globalParser.readUpdate( expr ));
        return HScriptExprMutation( expr );
    }

    @:from
    public static inline function fromString<I>(code: String):Mutation<I> {
        return StringMutation( code );
    }

    @:from
    public static inline function fromObject<I>(o: Object<Dynamic>):Mutation<I> {
        return StructMutation( o );
    }

    @:from
    public static inline function fromStruct<I, O:{}>(o: O):Mutation<I> {
        return fromObject( o );
    }
}

enum EMutation<Item> {
    StringMutation(value: String);
    UpdateExprMutation(value: UpdateExpr);
    HScriptExprMutation(value: hscript.Expr);

    StructMutation(value: Object<Dynamic>);
    CompiledMutation(value: Node);
}
