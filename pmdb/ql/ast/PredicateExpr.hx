package pmdb.ql.ast;

import pmdb.ql.ast.Value;

enum PredicateExpr {
    // * ({})
    PNoOp;

    // && ({$and: [...])
    POpBoolAnd(a:SubPredicate, b:SubPredicate);

    // || ({$or: [...])
    POpBoolOr(a:SubPredicate, b:SubPredicate);

    // !<expr> ({$not: {...})
    POpBoolNot(neg: SubPredicate);

    // ==
    POpEq(left:ValueExpr, right:ValueExpr);

    // !=
    POpNotEq(left:ValueExpr, right:ValueExpr);

    // >
    POpGt(left:ValueExpr, right:ValueExpr);

    // <
    POpLt(left:ValueExpr, right:ValueExpr);

    // >=
    POpGte(left:ValueExpr, right:ValueExpr);

    // <=
    POpLte(left:ValueExpr, right:ValueExpr);

    // (A in B)
    POpIn(col:ValueExpr, seq:ValueExpr);

    // !(A in B)
    POpNotIn(col:ValueExpr, seq:ValueExpr);

    // <RegExp Pattern>.match(<column>)
    POpRegex(col:ValueExpr, pattern:ValueExpr);

    // (<column> LIKE '<GLOB patterns>')
    POpLike(col:ValueExpr, pattern:ValueExpr);

    // (<column> is <DataType>)
    POpIs(col:ValueExpr, type:ValueExpr);

    // (exists(<column>)
    POpExists(column: ValueExpr);

    // len(<column>[]) == <const integer>
    POpSizeEq(col:ValueExpr, right:ValueExpr);

    /*
     {match_element,matchElement}(
      <column>[],
      where([{] | @:where {
       [= &SUBQUERY =]
      } | [}])
    */
    POpElemMatch(column:ValueExpr, predicate:ValueExpr);
}

typedef SubPredicate = PredicateExpr;
