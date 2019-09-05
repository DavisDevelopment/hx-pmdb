package pmdb.utils.macro;

#if macro
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;


using haxe.macro.ExprTools;

using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using pmdb.utils.macro.Exprs;
#end
using pm.Strings;
using pm.Numbers;
using pm.Arrays;

class SchemaProtoMacros {
    public static macro function create(type: Expr) {
        
        var type:Type = switch type {
            case macro $i{name}:
                try Context.getType(name)
                catch (s: String) {
                    trace(s);
                    switch Context.typeExpr(type).expr {
                        case TTypeExpr(m):
                            var fields:Array<Field> = new Array();
                            switch m {
                                case TClassDecl(c):
                                    for (field in c.get().fields.get()) {
                                        fields.push((field : Field));
                                    }
                                    
                                case TTypeDecl(t):
                                    switch t.get().type.getFields(true) {
                                        case null:
                                        case Success(result): for(r in result) fields.push(r);
                                        case Failure(error): throw error;
                                    }

                                case TAbstract(a):
                                    throw 'ass';
                            }

                        default:
                            throw 'anus';
                    }
                }
        }
        return macro $v{type.toString()};
    }
#if macro
    public static function gather(ut:Type, fields:Array<Dynamic>) {
        #if macro
            
        #end
        trace(ut.toComplexType().toString());
        var utBase = ut.reduce(false);
        trace(utBase.toComplexType().toString());
        
        switch utBase.getFields(true) {
            case null:
                throw 'y u null';

            case Success(result): 
                trace(result);
            
            case Failure(error):
                trace(error);
                throw error;
        }
        return macro 'shit';
        switch ut {
            case TInst(ref, params):
                for (f in ref.get().fields.get())
                    fields.push(f);
            case TAnonymous(fields):

            case TDynamic(t) if (t != null):
                //

            default:
                //
            // case TMono(t):
            // case TEnum(t, params):
            // case TType(t, params):
            // case TFun(args, ret):
            // case TLazy(f):
            // case TAbstract(t, params):
        }
    }
#end
}

// #end