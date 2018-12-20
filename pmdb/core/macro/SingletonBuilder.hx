package pmdb.core.macro;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using tannus.async.OptionTools;
using Lambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using tannus.macro.MacroTools;

class SingletonBuilder {
    public static macro function build():Array<Field> {
        var fields = Context.getBuildFields();
        var type = Context.getLocalType();
        var cmType = type.toComplexType();
        var cl = Context.getLocalClass().get();
        var path:TypePath = cl.fullName().toTypePath();
        
        var instField:Field = cast {
            name: 'instance',
            doc: null,
            meta: [],
            access: [AStatic, APrivate],
            kind: FProp('default', 'null', type, (macro new $path())),
            pos: Context.currentPos()
        };

        var factoryField:Field = cast {
            name: 'make',
            doc: null,
            meta: [],
            access: [AStatic, AInline, APublic],
            kind: FFun({
                args: [],
                ret: type,
                expr: macro return instance
            }),
            pos: Context.currentPos()
        }

        fields.push( instField );
        fields.push( factoryField );

        return fields;
    }
}
