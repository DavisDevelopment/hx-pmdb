package pmdb.core.query;

import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
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
using pmdb.ql.ts.DataTypes;

class ParseFromAnon {
    /* Constructor Function */
    public function new() {
        //
    }

/* === Methods === */

    /**
      parse an ast from the given source
     **/
    public function parseAst(src: Anon<Dynamic>):QueryAst {
        if (src.exists("$or") || src.exists("$and") || src.exists("$not")) {
            return QueryAst.Flow(parseFlow( src ));
        }
        // hack; must be a better way to do this
        else if (src.exists("$where")) {
            var fn = src["$where"];
            src.remove("$where");
            if (!Arch.isFunction( fn )) {
                throw new Error('$$where operator called on non-function');
            }

            if (src.keys().empty()) {
                return QueryAst.Flow(LWhere(cast fn));
            }
            else {
                return QueryAst.Flow(LAnd([parseAst(src), QueryAst.Flow(LWhere(cast fn))]));
            }
        }
        else {
            return QueryAst.Expr(parseExpr( src ));
        }
    }

    /**
      parse out a filter expression from the given source
     **/
    function parseExpr(src: Anon<Dynamic>):FilterExpr<Any> {
        var expr:FilterExpr<Any> = new FilterExpr();
        for (key in src.keys()) {
            if (src[key] == null || Arch.isPrimitiveType(src[key])) {
                expr.addIs(key, src[key]);
            }
            else if (src[key] != null && Arch.isObject(src[key])) {
                var name:String = key;
                var sub:Anon<Dynamic> = Anon.of(src[key]);

                for (key in sub.keys()) {
                    expr.addOp(name, (switch key {
                        case "$lt": ColOpCode.LessThan;
                        case "$lte": LessThanEq;
                        case "$gt": GreaterThan;
                        case "$gte": GreaterThanEq;
                        case "$in": ColOpCode.In;
                        case "$regex", "$regexp": ColOpCode.Regexp;

                        case other: throw new Error('Invalid opcode "$other"');
                    }), sub[key]);
                }
            }
            else {
                throw new Error('Unhandled key "$key"');
            }
        }

        return expr;
    }

    /**
      parse a logical flow statement from the given source
     **/
    function parseFlow(src: Anon<Dynamic>):LogOp {
        if (src.exists("$not")) {
            return LNot(parseAst(cast src["$not"]));
        }
        else if (src.exists("$and")) {
            var rawSubs:Array<Anon<Dynamic>> = cast src["$and"];
            var subs:Array<QueryAst> = rawSubs.map( parseAst );
            return LAnd( subs );
        }
        else if (src.exists("$or")) {
            var rawSubs:Array<Anon<Dynamic>> = cast src["$or"];
            var subs:Array<QueryAst> = rawSubs.map( parseAst );
            return LOr( subs );
        }
        else {
            var keys = src.keys();
            if (keys.empty()) {
                throw new Error('Empty flow source');
            }
            else {
                throw new Error('Invalid logop "${keys[0]}"');
            }
        }
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
