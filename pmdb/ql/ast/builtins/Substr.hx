package pmdb.ql.ast.builtins;

import pmdb.ql.ast.Function;
import pmdb.ql.ast.BuiltinFunction;

class Substr extends BuiltinFunction {
    public function new() {
        super('substr', new Function(NativeFnProxy.Fn3(function(a:Dynamic, b:Dynamic, c:Dynamic):Dynamic {
            if ((a is String) && (b is Int) && (c is Int)) {
                return cast(a, String).substr(a, b).tap(x -> trace(x));
            }
            else {
                return null;
            }
        })));
    }
}