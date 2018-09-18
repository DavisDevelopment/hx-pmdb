package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.QueryFilter;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
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

/**
  used to build QueryFilters functionally
 **/
class QueryFilterBuilder {
    /* Constructor Function */
    public function new() {
        expr = new FilterExpr();
        fields = new Map();
        ast = QueryAst.Expr( expr );

        _wrap = FunctionTools.identity;
    }

/* === Methods === */

    public function eq(fieldName:String, value:Dynamic):QueryFilterBuilder {
        expr.addIs(fieldName, value);
        return this;
    }

    public function op(fieldName:String, op:ColOpCode, operand:Dynamic):QueryFilterBuilder {
        expr.addOp(fieldName, op, operand);
        return this;
    }

    public function field(name: String):QueryFilterFieldBuilder {
        if (!fields.exists( name )) {
            return fields[name] = new QueryFilterFieldBuilder(name, this);
        }
        return fields[name];
    }

    public function not():QueryFilterBuilder {
        _wrap = _wrap.wrap(function(_, ast:QueryAst):QueryAst {
            return QueryAst.Flow(LNot(_( ast )));
        });
        return this;
    }

    public function toQueryFilter():QueryFilter {
        return new QueryFilter(_wrap( ast ));
    }

/* === Variables === */

    @:noCompletion
    public var expr(default, null): Null<FilterExpr<Any>>;
    @:noCompletion
    public var fields(default, null): Map<String, QueryFilterFieldBuilder>;

    public var ast(default, null): QueryAst;

    private var _wrap: QueryAst -> QueryAst;
}

class QueryFilterFieldBuilder {
    /* Constructor Function */
    public function new(k, q) {
        this.name = k;
        this.q = q;
    }

    public function eq(value: Dynamic):QueryFilterFieldBuilder {
        q.eq(name, value);
        return this;
    }

    public function op(opcode:ColOpCode, value:Dynamic):QueryFilterFieldBuilder {
        q.op(name, opcode, value);
        return this;
    }

    public function lt(value: Dynamic):QueryFilterFieldBuilder {
        return op(LessThan, value);
    }

    public function lte(value: Dynamic):QueryFilterFieldBuilder {
        return op(LessThanEq, value);
    }

    public function gt(value: Dynamic):QueryFilterFieldBuilder {
        return op(GreaterThan, value);
    }

    public function gte(value: Dynamic):QueryFilterFieldBuilder {
        return op(GreaterThanEq, value);
    }

    public function isIn(values: Array<Dynamic>):QueryFilterFieldBuilder {
        return op(In, values);
    }

    public function isNIn(values: Array<Dynamic>):QueryFilterFieldBuilder {
        return op(NIn, values);
    }

    public function regex(value: Dynamic):QueryFilterFieldBuilder {
        if (Arch.isRegExp( value ))
            return op(Regexp, value);

        if ((value is String))
            return op(Regexp, new EReg(cast value, ''));

        throw new Error('$value is not a valid argument for $$regex');
    }

    var name(default, null): String;
    var q(default, null): QueryFilterBuilder;
}
