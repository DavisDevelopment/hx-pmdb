package pmdb.ql.ast;

import haxe.macro.Expr;

import pmdb.ql.ast.Function;

import pm.Lazy;

class BuiltinFunction {
    public var fn(default, null): Function;
    public var name(default, null): String;

    public function new(id, fn) {
        this.name = id;
        this.fn = fn;
    }

    public function __call__(args: Array<Dynamic>):Dynamic {
        return this.fn.__call__( args );
    }

    public macro function call(self:ExprOf<BuiltinFunction>, args:Array<Expr>):ExprOf<Dynamic> {
        return macro $self.__call__($a{args});
    }
}