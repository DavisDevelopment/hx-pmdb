package pmdb.ql.ast;

import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;

enum UpdateExpr {
    UNoOp;
    UAssign(column:ValueExpr, value:ValueExpr);
    UDelete(column: ValueExpr);
    //URename(oldColumn:ValueExpr, newColumn:ValueExpr);

/* === Array/Tuple Modifiers === */

    UPush(column:ValueExpr, elem:ValueExpr);

/* === Combinators === */

    UBlock(updates: Array<UpdateExpr>);
}
