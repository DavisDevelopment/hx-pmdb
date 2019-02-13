package pmdb.ql.ast;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;

class PmQlStmt {
    public var kind(default, null): PmQlStmtKind;

    public function new(stmt) {
        this.kind = stmt;
    }

    public static function find(p:PredicateExpr, ?out:StmtOutputPipe):PmQlStmt {
        return new PmQlStmt(FindStmt(p, out));
    }
}

enum PmQlStmtKind {
    FindStmt(predicate:PredicateExpr, ?pipe:StmtOutputPipe);
}

enum StmtOutputPipe {
    //PChunk(chunkSize:Int, chunkOffset:Int, ?chunkCount:Int);
    //PGroup(by: StmtTerm);
    //POrder(by: StmtTerm);
}

enum StmtTerm {
    //ColumnTerm(column:String);
    //ExprTerm(expr: ValueExpr);
    //AggrTerm(term: StmtTerm, aggregate:Aggregator);
}

enum Aggregator {}
