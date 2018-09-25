package pmdb.ql.ast;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class EnumBuilders {
    #if macro
    public static function enumCopyWithoutFirstArg(typeName: String):Array<Field> {
        var src: Type, srcE:EnumType;
        try {
            src = Context.getType( typeName );
            srcE = switch src {
                case TEnum(_.get()=>e, params): e;
                case _: null;
            }
        }
        catch (err: Dynamic) {
            Context.error('Error: Unknown type $typeName', Context.currentPos());
            src = null;
            srcE = null;
        }

        if (src == null) {
            return [];
        }

        var fields:Array<Field> = new Array();

        for (key in srcE.constructs.keys()) {
            var c = srcE.constructs[key];
            var ef = makeEnumField(c.name, (switch c.type {
                case TFun(args, ret): 
                    FieldType.FFun({
                        args: cast args.slice(1).map(x -> cast {
                            name: x.name,
                            type: x.t.toComplexType()
                        }),
                        expr: null,
                        ret: null
                    });
                case _: null;
            }));
            fields.push( ef );
        }

        fields = fields.filter(x -> x != null);

        return fields;
    }

    private static function makeEnumField(name, kind) {
        return {
            name: name,
            doc: null,
            meta: [],
            access: [],
            kind: kind,
            pos: Context.currentPos()
        };
    }
    #end
}
