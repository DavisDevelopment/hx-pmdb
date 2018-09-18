package pmdb.core.query;

import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.QueryFilter;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

import Slambda.fn;
import Std.is as isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using pmdb.ql.types.DataTypes;

class ParseFromAnon {
    /* Constructor Function */
    public function new() {
        //
    }

/* === Methods === */

    public function parseAst(src: Anon<Dynamic>):QueryAst {
        var chunks:Array<QueryAst> = new Array();
        for (key in src.keys()) {
            if (src[key] == null || Arch.isPrimitiveType(src[key])) {
                chunks.push(Filter(Is(key, src[key])));
            }
            else if (key.startsWith("$")) {
                switch key {
                    case "$or":
                       if (Arch.isArray(src[key])) {
                           var ors:Array<Dynamic> = cast src[key];
                           chunks.push(ors.map.fn(parseAst(_)).compose(function(a:QueryAst, b:QueryAst):QueryAst {
                               return Flow(LOr(a, b));
                           }, function(a: QueryAst):QueryAst {
                               return a;
                           }));
                       } 

                    case "$and":
                       if (Arch.isArray(src[key])) {
                           var ors:Array<Dynamic> = cast src[key];
                           chunks.push(ors.map.fn(parseAst(_)).compose(function(a:QueryAst, b:QueryAst):QueryAst {
                               return Flow(LAnd(a, b));
                           }, function(a: QueryAst):QueryAst {
                               return a;
                           }));
                       }

                    case "$not":
                       chunks.push(Flow(LNot(parseAst(src[key]))));

                    case other:
                       throw new Error('Unsupported operator "$key"');
                }
            }
            else if (src[key] != null && Arch.isObject(src[key])) {
                var name:String = key;
                var sub:Anon<Dynamic> = Anon.of(src[key]);
                var op:ColOp->QueryAst = (x -> Filter(Op(name, x)));

                for (key in sub.keys()) {
                    switch key {
                        case "$lt":
                            chunks.push(op(Lt(sub[key])));

                        case "$lte":
                            chunks.push(op(Lte(sub[key])));

                        case "$gt":
                            chunks.push(op(Gt(sub[key])));

                        case "$gte":
                            chunks.push(op(Gte(sub[key])));

                        case "$in":
                            chunks.push(op(In(cast sub[key])));

                        case other:
                            throw new Error('Unsupported comparision operator "$other"');
                    }
                }
            }
            else {
                throw new Error('Unhandled key "$key"');
            }
        }

        return chunks.compose(function(a:QueryAst, b:QueryAst):QueryAst {
            return Flow(LAnd(a, b));
        }, FunctionTools.identity);
    }

    public static function run(o: Anon<Dynamic>):QueryAst {
        return (new ParseFromAnon().parseAst( o ));
    }

    private static inline function o<T>(x: Dynamic):Anon<T> {
        return Anon.of(cast x);
    }

/* === Variables === */

    var src(default, null): Anon<Dynamic>;
}
