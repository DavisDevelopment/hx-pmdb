package pmdb.ql.ast;

import tannus.ds.Lazy;
import tannus.ds.Ref;

import pmdb.core.Arch;
//import pmdb.core.Key;
import pmdb.core.Object;
import pmdb.ql.ts.DataType;

import haxe.Constraints.Function;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class UpdateMethods {
    public static function update_set(doc:Object<Dynamic>, key:String, value:Dynamic) {
        
    }
}

class UpdateMethod <Method:(Function)> {
    /* Constructor Function */
    public function new(key:String, value:Dynamic, assign:Method -> Void) {
        key = key;
        parts = key.split('.');
    }

    static function compileSow<F:(Function)>(comp:Array<Dynamic>->(F -> Void)->Dynamic, start:F):F {
        var out:Ref<F> = Ref.const( start );
        var assign:F->Void = (f -> (out.set( f )));
        
        function _comp(args: Array<Dynamic>):Dynamic {
            return comp(args, assign);
        }
        out.set(cast Reflect.makeVarArgs( _comp ));

        return cast Reflect.makeVarArgs(function(args: Array<Dynamic>):Dynamic {
            return Reflect.callMethod(null, out.get(), args);
        });
    }

    var key(default, null): String;
    var parts(default, null): Array<String>;
    var value(default, null): Dynamic;
}
