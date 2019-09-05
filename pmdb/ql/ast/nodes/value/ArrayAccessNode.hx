package pmdb.ql.ast.nodes.value;

import pm.Lazy;

import pmdb.core.Error;
import pmdb.core.Assert.assert;
import pmdb.ql.ts.TypeSystemError;

import pmdb.ql.ast.Value;
import pmdb.ql.ast.nodes.ValueNode;
import pmdb.ql.ts.DataType;

import haxe.PosInfos;
import haxe.ds.Option;

using pm.Arrays;
using pm.Options;
using pm.Functions;

class ArrayAccessNode extends CompoundValueNode {
    /* Constructor Function */
    public function new(array, index, ?expr, ?pos) {
        super([array, index], expr, pos);

        var left = childValues[0];
        if (left.isTyped()) {
            ctype = left.type;
            if (ctype != null) {
                var retype = returnType(ctype);
                if (retype != null)
                    assignType( retype );
            }
        }
    }

/* === Methods === */

    function returnType(ctype: DataType):Null<DataType> {
        return switch ctype {
            case DataType.TScalar(TString): TScalar(TString);
            case DataType.TArray(type): TNull(type);
            case DataType.TNull(type): TNull(returnType(type));
            default: null;
        }
    }

    override function eval(ctx: QueryInterp):Dynamic {
        var left:Dynamic = childValues[0].eval( ctx );
        if (left == null)
            throw new Error('Cannot perform array-access on null');
        if (ctype != null) return switch (ctype) {
            case TNull(TArray(_))|TArray(_): array_get(ctx, left, childValues[1]);
            case TNull(TScalar(TString))|TScalar(TString): string_get(ctx, left, childValues[1]);
            case _: dynamic_get(ctx, left, childValues[1]);
        }
        else {
            return dynamic_get(ctx, left, childValues[1]);
        }
    }

    override function compile():(doc:Dynamic, args:Array<Dynamic>)->Dynamic {
        //trace('warning: unoptimized .compile() for ArrayAccessNode');
        //return eval.bind(_);
        final l = childValues[0].compile();
        final r = childValues[1].compile();

        if (ctype != null) {
            switch ctype {
                case TNull(TArray(_))|TArray(_):
                    return array_getter.bind(_, _, cast l, cast r);
                    return function(doc:Dynamic, args):Dynamic {
                        return array_getter(doc, args, cast l, cast r);
                    }

                case TNull(TScalar(TString))|TScalar(TString):
                    //return string_getter.bind(_, _, cast l, cast  r);
                    return function(doc:Dynamic, args):Dynamic {
                        return string_getter(doc, args, cast l, cast r);
                    }

                case other:
                    //
            }
        }

        return function(doc:Dynamic, args:Array<Dynamic>):Dynamic {
            return dynamic_getter(doc, args, l, r);
        }
    }

    static function dynamic_get(ctx:QueryInterp, c:Dynamic, indx:ValueNode):Dynamic {
        final i:Dynamic = indx.eval( ctx );
        if (Arch.isArray(c)) {
            return Arch.isType(i, Int) ? cast(c, Array<Dynamic>)[cast(i, Int)] : throw new Error('Invalid array-access ${c}[$i]');
        }
        else if (Arch.isString(c)) {
            return Arch.isType(i, Int) ? cast(c, String).charAt(cast(i, Int)) : throw new Error('Invalid array-access ${c}[$i]');
        }
        else {
            throw new Error('Invalid array-access ${c}[$i]');
        }
    }

    static function array_get(ctx:QueryInterp, array:Array<Dynamic>, indx:ValueNode):Dynamic {
        assert(Arch.isArray(array), '${haxe.Json.stringify(array)} is not an array');
        return array[cast(indx.eval(ctx), Int)];
    }

    static function string_get(ctx:QueryInterp, string:String, indx:ValueNode):String {
        assert(Arch.isString(string), '${haxe.Json.stringify(string)} is not a String');
        return string.charAt(cast(indx.eval(ctx), Int));
    }

    static function string_getter<O>(doc:O, params:Array<Dynamic>, str:ValueNodeLambda<O, String>, pos:ValueNodeLambda<O, Int>):String {
        final s:String = str(doc, params);
        final i:Int = pos(doc, params);

        assert(Arch.isString(s), 'Invalid value extracted from document; expected String, got ${haxe.Json.stringify(s)}');
        assert(Arch.isType(i, Int), 'Invalid value extracted from document; expected Int, got ${haxe.Json.stringify(i)}');

        return s.charAt( i );
    }

    static function array_getter<O, Elem>(doc:O, params:Array<Dynamic>, list:ValueNodeLambda<O, Array<Elem>>, index:ValueNodeLambda<O, Int>):Elem {
        final arr = list(doc, params),
              idx = index(doc, params);

        assert(Arch.isArray(arr), 'invalid call');
        assert(Arch.isType(idx, Int), 'invalid call');

        return arr[idx];
    }

    static function dynamic_getter<O>(doc:O, params:Array<Dynamic>, left:ValueNodeLambda<O, Dynamic>, right:ValueNodeLambda<O, Dynamic>):Dynamic {
        final c = left(doc, params);
        final i = right(doc, params);

        if (Arch.isString( c )) {
            if (Arch.isType(i, Int)) {
                return cast(c, String).charAt(cast(i, Int));
            }
        }

        if (Arch.isArray( c )) {
            if (Arch.isType(i, Int)) {
                return (c : Array<Dynamic>)[(i : Int)];
            }
        }

        throw new Error('Invalid array access ${c}[$i]');
    }

    private var ctype(default, null): Null<DataType> = null;
}
