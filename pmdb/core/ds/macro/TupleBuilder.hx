package pmdb.core.ds.macro;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;

using StringTools;
using Lambda;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

//use this for macros or other classes
class TupleBuilder {
    static var _popped:Bool = false;

    public static function buildTuple() {
        Context.onTypeNotFound( middleware );
       
        var type = Context.getLocalType();
        var real:ComplexType = (macro : StdTypes.Void);
        var realName:String = 'pmdb.core.ds.Tuple';

        switch type {
            case TInst(_, [_.toComplexType()=>x, _.toComplexType()=>y]):
                real = macro : pmdb.core.ds.Tuple.Tuple2<$x, $y>;
                realName += '.Tuple2';

            case TInst(_, rest):
                realName += '.Tuple${rest.length}';
                real = ComplexType.TPath({
                    name: 'Tuple',
                    sub: 'Tuple${rest.length}',
                    pack: ['pmdb', 'core', 'ds'],
                    params: rest.map(t -> TPType(t.toComplexType()))
                });

            default:
                Context.error('No Tuple implementation for ${type.toString()}', Context.currentPos());
                real = macro : Test.Unit;
        }

        Context.getType( realName );
        return real;
    }

    static function paramDecls(n: Int):Array<TypeParamDecl>{
        return [for (i in 0...n) {name:names[i]}];
    }

    static function reduceRight<B,T>(a:Array<T>,acc:B, fn:B->T->B):B {
        var i:Int = a.length;
        while (--i >= 0)
            acc = fn(acc, a[i]);
        return acc;
    }

    static function reduce<B,T>(a:Array<T>,acc:B,fn:B->T->B):B {
        for (x in a)
            acc = fn(acc, x);
        return acc;
    }

    static function fold<T>(a:Array<T>, fn:T->T->T):T {
        if (a.length == 0) 
            return null;
        else {
            return reduceRight(a, a.pop(), fn);
        }
    }

    static function fold2<T>(a:Array<T>, fn:T->T->T):T {
        if (a.length == 0) 
            return null;
        else {
            return reduce(a, a.shift(), fn);
        }
    }

    /**
      TODO make parameter types have the path shown in the codecompletion suggestions
     **/
    static function typeForName(i:Int, insideClass=false):ComplexType {
        var name = names[i].toUpperCase();
        return TPath({
            name: name,
            pack: []
        });
    }

    static function typeParamFor(i: Int):TypeParam {
        return TypeParam.TPType(typeForName(i, false));
    }

    static function cellsFor(n:Int, inClass:Bool=true):ComplexType {
        inline function two(x:ComplexType, y:ComplexType) {
            return (macro : pmdb.core.ds.macro.TCell<$x, $y>);
        }

        var paramTypes = [for (i in 0...n) typeForName(i, inClass)];
        var ltype = fold(paramTypes, function(acc:ComplexType, x) {
            return two(acc, x);
        });

        trace(ltype.toString());
        return ltype;
    }

    static function makeAccessExpr(n:Int, o:Expr, props:{v:String, lnk:String}):Expr {
        var acc:Expr = o;
        var field:String = props.lnk;
        for (i in 0...(n - 1)) {
            acc = (macro $acc.$field);
        }
        field = props.v;
        acc = macro $acc.$field;
        trace(acc.toString());
        return acc;
    }

    static function mk2(a:Expr, b:Expr):Expr {
        return macro new pmdb.core.ds.macro.TCell($a, $b);
    }

    /**
      build the expression which constructs the underlying value
     **/
    static function makeConstruction(values: Array<Expr>):Expr {
        if (values.length == 0)
            throw 'empty';
        if (values.length == 1)
            return values[0];
        //if (values.length == 2)
            //return mk2(values[0], values[1]);
        var res = mk2(values.shift(), makeConstruction(values));
        trace(res.toString());
        return res;
    }

    /**
      build and add fields to the given TypeDefinition
     **/
    static function fillOut(type:TypeDefinition, n:Int):TypeDefinition {
        //trace('n == $n');
        var fields = type.fields;
        function field(n:String, t:FieldType, ?a:Null<Array<Access>>):Field {
            return {
                name: n,
                pos: Context.currentPos(),
                kind: t,
                access: a,
                doc: null,
                meta: null
            };
        }

        for (i in 0...n) {
            // the type for [this] field
            var fieldValType:ComplexType = typeForName(i);

            // public var [a...z](get, never):[A...Z];
            fields.push(field(
                names[i],
                FieldType.FProp('get', 'never', fieldValType),
                [APublic]
            ));

            // compute the field-access expression
            var acc:Expr = makeAccessExpr(i, (macro this), {
                v: 'v',
                lnk: 'next'
            });

            // inline function get_[a...z]() return [acc]
            fields.push(field(
                'get_' + names[i],
                FieldType.FFun({
                    args: [],
                    expr: (macro return $acc),
                    ret: fieldValType
                }),
                [APrivate, AInline]
            ));
        }

        /**
          build the constructor function
         **/
        fields.push(field(
            'new',
            FFun({
                args: [
                    for (i in 0...n) {
                        name: names[i],
                        meta: null,
                        opt: false,
                        type: null,
                        value: null
                    }
                ],
                expr: (function() {
                    var values = [for (i in 0...n) names[i]]
                        .map(s -> (macro $i{s}));
                    values.reverse();
                    //trace((macro $a{values}).toString());
                    var constr:Expr = makeConstruction(values);
                    return macro this = $constr;
                })(),
                ret: (macro : StdTypes.Void)
            }),
            [APublic, AInline]
        ));

        type.fields = fields;
        return type;
    }


    /**
      generates TypeDefinitions for types who have been referenced and not yet defined
     **/
    static function middleware(path: String):TypeDefinition {
        var tpn: Int = 0;
        if (path.startsWith('Tuple')) {
            tpn = Std.parseInt(path.substr(5));
            //trace('${tpn}tuple');
            return fillOut({
                name: 'Tuple$tpn',
                pack: [],
                pos: Context.currentPos(),
                params: paramDecls(tpn),
                kind: TypeDefKind.TDAbstract(cellsFor(tpn)),
                fields: []
            }, tpn);
        }
        return null;
    }

/* === Variables === */

    //static var names:Array<String> = [ "a", "b", "c", "d", "e", "f", "g", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z" ];
    static var names = {'abcdefghijklmnopqrstuvwxyz'.split('');};
}
