package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.query.*;
import pmdb.core.*;
import pmdb.core.Query;

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
using pmdb.core.QueryFilters;

/**
  QueryFilter - specifies one or more checks used to filter documents from query-results
  based heavily on the query-format in [nedb](https://github.com/louischatriot/nedb)
  References:
  https://github.com/louischatriot/nedb#basic-querying
 **/
class QueryFilter {
    /* Constructor Function */
    public function new(ast:QueryAst, ?pos:PosInfos) {
        this.ast = ast;
        this.position = pos;
        this.raw = null;
        this._match = null;
    }

/* === Methods === */

    /**
      tells whether the given object [doc] is matched by the pattern described by [this]
     **/
    public function match(doc:Anon<Anon<Dynamic>>, ?store:Store<Any>):Bool {
        if (_match == null) {
            _match = new Match( this );
        }
        return _match.test(doc, store);
    }

    public function iterFilters(fn: FilterExpr<Any>->Void):Void {
        ast.iterFilters( fn );
    }

    public function join(other: QueryFilter):QueryFilter {
        switch [ast, other.ast] {
            case [Expr(left), Expr(right)]:
                var c:FilterExpr<Any> = left.copy();
                for (k in right.keys()) {
                    c.set(k, right.get(k));
                }
                for (k in c.keys()) {
                    switch c.get(k) {
                        case VOps(ops):
                            c.set(k, VOps(ops.copy()));

                        case _:
                            //
                    }
                }
                return new QueryFilter(Expr( c ));

            case _:
                return and( other );
        }
    }

    public function and(other: QueryFilter):QueryFilter {
        return new QueryFilter(Flow(LAnd([ast, other.ast])));
    }

/* === Statics === */

    /**
      create and return a new QueryFilter from the given struct
     **/
    public static function ofAnon(o: Anon<Anon<Dynamic>>):QueryFilter {
        return new QueryFilter(pmdb.core.query.ParseFromAnon.run( o ));
    }

    /**
      create and return a new QueryFilter from any valid QueryFilter expression
     **/
    public static function of(q: Dynamic):QueryFilter {
        return CQuery.createQueryFilter( q );
    }

/* === Fields === */

    private var ast(default, null): QueryAst;
    private var raw(default, null): Null<Anon<Anon<Dynamic>>>;
    private var position(default, null): PosInfos;

    private var _match(default, null): Null<Match>;
}

enum QueryAst {
    Flow(logic: LogOp);
    Expr(query: FilterExpr<Any>);
}

//enum QueryExpr {
    //Is(key:String, val:Dynamic);
    //Op(key:String, operator:ColOp);
//}

//enum 

@:forward
abstract FilterExpr<T> (Map<String, FilterExprValue<T>>) from Map<String, FilterExprValue<T>> {
    public inline function new() {
        this = new Map();
    }

    public function addIs(k:String, value:T):FilterExpr<T> {
        if (!this.exists( k )) {
            this.set(k, VIs( value ));
        }

        return this;
    }

    public function addOp(k:String, op:ColOpCode, value:Dynamic):FilterExpr<T> {
        if (this.exists( k )) {
            switch this.get( k ) {
                case VOps( ops ):
                    ops[op] = value;

                default:
                    throw new Error("Cannot operator to $eq directive");
            }
        }
        else {
            var ops:Map<ColOpCode, Dynamic> = new Map();
            ops[op] = value;
            this.set(k, VOps(ops));
        }

        return this;
    }
}

enum FilterExprValue<T> {
    VIs(value: T);
    VOps(ops: Map<ColOpCode, Dynamic>);
}

enum LogOp {
    LNot(sub: QueryAst);
    //LAnd(a:QueryAst, b:QueryAst);
    LAnd(subs: Array<QueryAst>);
    //LOr(a:QueryAst, b:QueryAst);
    LOr(subs: Array<QueryAst>);
    LWhere(predicate: Dynamic->Bool);
}

enum ColOp {
    Lt(val: Dynamic);
    Lte(val: Dynamic);
    Gt(val: Dynamic);
    Gte(val: Dynamic);
    InRange(min:BoundingValue<Dynamic>, max:BoundingValue<Dynamic>);
    In(vals: Array<Dynamic>);
}

enum ColOpCode {
    LessThan;
    LessThanEq;
    GreaterThan;
    GreaterThanEq;
    In;
    NIn;
    Regexp;
}

