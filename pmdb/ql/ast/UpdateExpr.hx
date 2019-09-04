package pmdb.ql.ast;

import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;

enum UpdateExpr {
    UNoOp;

    UStruct(fields: Array<UpdateStructField>);
    UAssign(column:ValueExpr, value:ValueExpr);
    UDelete(column: ValueExpr);
    //URename(oldColumn:ValueExpr, newColumn:ValueExpr);

    /**
      [=NOTE=]
      Incr and Decr operations are constrained to accepting only expressions which map to numerical literals.
      Columns of numerical types may be in/decremented by numerical values (Int & Float)
      Columns of structure types may be in/decremented by structures whose type left-unifies with the column-type. Example:
      <code>
        // if @pos is of type {x:Float, y:Float}
        pos.x++; // valid
        // more verbose, but equivalent
        pos += {x:1, y:0};
        // could be shortened to:
        pos += {x:1};

        // alternatively, if @pos was of type Tuple<Float, Float>, this would work
        pos[0]++;
        // as would this
        pos += [1, 0];
      </code>
     **/
    UIncr(col:ValueExpr, amnt:ValueExpr);
    UDecr(col:ValueExpr, amnt:ValueExpr);

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
