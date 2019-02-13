package pmdb.runtime;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.ASTError;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PmQlStmt;
import pmdb.core.ds.map.Dictionary;
import pmdb.core.StructSchema;
import pmdb.core.Store;

import haxe.ds.Option;

using pmdb.ql.ts.DataTypes;
using pmdb.core.ds.tools.Options;

/**
  traverses query AST and plans query strategy
 **/
class QueryPlanner {
    /* Constructor Function */
    public function new(spec: DbInfo) {
        this.spec = spec;
        this.scope = new DbScope( this.spec );
    }

/* === Methods === */

    public function plan(stmt: PmQlStmt):QueryPlan {
        switch ( stmt.kind ) {
            case PmQlStmtKind.FindStmt(predicate, null):
                return planFind( predicate );

            default:
                //
        }
        return null;
    }

    function planFind(predicate: PredicateExpr):QueryPlan {
        return null;
    }

    function getPredicateRoutes(expr: PredicateExpr):Array<Dynamic> {
        switch ( expr ) {
            case PredicateExpr.POpBoolAnd(expr, _): 
                return getPredicateRoutes( expr );
            case PredicateExpr.POpEq(left=(getColumn(_) => leftCol), right) if (leftCol != null):
                throw 'Assy';

            default:
                return [];
        }
    }

    function getColumn(expr: ValueExpr):Null<String> {
        return switch ( expr.expr ) {
            case ValueExprDef.ECol(col): col;
            case ValueExprDef.EAttr({expr:EThis}, col): col;
            case ValueExprDef.EAttr(getColumn(_)!=null=>true, col): col;
            case ValueExprDef.EArrayAccess({expr:EThis}, {expr:EConst(CString(col))}): col;
            case ValueExprDef.EArrayAccess(getColumn(_)!=null=>true, {expr:EConst(CString(col))}): col;
            default: null;
        }
    }

/* === Variables === */

    //public var plan: QueryPlan;
    public var scope: IScope;

    public var spec: DbInfo;
}

interface IScope {
    var parent:Null<IScope>;

    function lookup(id: String):Option<Declared>;
    function declare(id:String, ?t:DataType):Void;
}

class DbScope implements IScope {
    var tables: Dictionary<TableScope>;
    public var parent:Null<IScope>;

    /* Constructor Function */
    public function new(spec: DbInfo) {
        this.parent = null;
        this.tables = new Dictionary();
        var tm:haxe.DynamicAccess<StructSchema> = spec.tables;
        for (k in tm.keys()) {
            tables.set(k, new TableScope(this, k, TStruct(tm[k])));
        }
    }

    public function lookup(id: String):Option<Declared> {
        return tables.exists( id ) ? Some({
            ident: id,
            type: tables[id].rowType,
            kind: Table
        }) : None;
    }

    public function declare(id:String, ?t:DataType) {
        throw 'Fewp';
    }
}

class RootDbScope extends DbScope {
    public var planner(default, null): QueryPlanner;
    public function new(qp: QueryPlanner) {
        super( qp.spec );
        this.planner = qp;
    }
}

class TableScope implements IScope {
    public function new(db:DbScope, name, type) {
        //initialize variables
        this.parent = db;
        this.name = name;
        this.rowType = type;

        columns = new Dictionary();

        switch ( rowType ) {
            case DataType.TStruct(type):
                for (field in type.fields) {
                    columns.set(field.name, {
                        ident: field.name,
                        type : field.type,
                        kind : TableColumn
                    });
                }

            default:
                throw new Error();
        }
    }

    public function lookup(id: String):Option<Declared> {
        return ((columns.exists( id ) ? Some(columns[id]) : None).flatMap(function(d) {
            return if (parent != null) parent.lookup( id ) else None;
        }));
    }

    public function declare(id, ?type:DataType) {
        throw new Error('TableScope is immutable');
    }

    public var parent: Null<IScope>;
    public var name: String;
    public var rowType: DataType;

    var columns:Dictionary<Declared>;
}

@:structInit
class Declared {
    public var ident: String;
    public var type: DataType = TUnknown;
    public var kind: RefKind;
}

enum RefKind {
    Table;
    TableColumn;
    LocalVar;
}

typedef QueryPlan = Dynamic;
typedef DbInfo = {
    tables: Dynamic<StructSchema>
};

typedef TableInfo = {
    name:String,
    type:StructSchema
};

