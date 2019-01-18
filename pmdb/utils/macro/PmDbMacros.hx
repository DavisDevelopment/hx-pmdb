package pmdb.utils.macro;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;
using haxe.macro.PositionTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;

using StringTools;
using tannus.ds.StringUtils;
using Lambda;
using tannus.ds.ArrayTools;

class PmDbMacros {
    public static function init() {
        //TODO library-initialization code goes here
    }

    static function def(flag:String, ?value:String, mutuallyExclude:Iterable<String>) {
        Compiler.define(flag, value);
    }

    static function isdef(flag: String):Bool {
        return Context.defined(flag) && Context.definedValue(flag) != "false";
    }

    private static function run_middleware(modules: Array<ModuleType>) {
        for (mod in modules) {
            switch ( mod ) {
                case TClassDecl(_.get() => cl):
                    onClassDecl( cl );

                default:
                    continue;
            }
        }
    }

    private static function onClassDecl(classDecl: ClassType) {
        //TODO
    }
}
