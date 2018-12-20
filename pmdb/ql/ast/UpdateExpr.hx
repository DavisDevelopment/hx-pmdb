package pmdb.ql.ast;

import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;

enum UpdateExpr {
    UNoOp;

    UAssign(column:ValueExpr, value:ValueExpr);
    UStruct(fields: Array<UpdateStructField>);
    UDelete(column: ValueExpr);
    //URename(oldColumn:ValueExpr, newColumn:ValueExpr);

/* === Array/Tuple Modifiers === */

    UPush(column:ValueExpr, elem:ValueExpr);

/* === Combinators === */

    UBlock(updates: Array<UpdateExpr>);
}

@:structInit
class UpdateStructField {
    public final field: String;
    public final value: ValueExpr;

    public inline function new(field, value) {
        this.field = field;
        this.value = value;
    }
}
