package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateOp;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

/**
  contains and manages information about the context in which a PredicateNode is being evaluated
 **/
class PredicateContext {
    /* Constructor Function */
    public function new(row:Object<Dynamic>, ?args:Array<Dynamic>, ?schema:DocumentSchema):Void {
        this.document = row;
        this.parameters = (args != null ? args : new Array());
        this.schema = schema;
    }

/* === Methods === */

    /**
      create and return a shallow-copy of [this] Context
     **/
    public inline function clone():PredicateContext {
        return new PredicateContext(document, parameters.copy(), schema);
    }

    public function setDocument(newDoc: Object<Dynamic>) {
        this.document = newDoc;
    }

    public function setSchema(newSchema: Null<DocumentSchema>) {
        this.schema = newSchema;
    }

    public function clearSchema() {
        setSchema( null );
    }

    public function setParameters(newParams: Array<Dynamic>) {
        this.parameters = newParams;
    }

/* === Variables === */

    public var document(default, null): Object<Dynamic>;
    public var parameters(default, null): Array<Dynamic>;
    public var schema(default, null): Null<DocumentSchema>;
}
