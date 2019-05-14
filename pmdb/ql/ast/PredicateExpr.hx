package pmdb.ql.ast;

import pmdb.ql.ast.Value;

@:using(pmdb.ql.ast.Predicates)
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

    // has(A, B) OR A.has(B) OR (B in A)
    POpContains(col:ValueExpr, val:ValueExpr);

    POpInRange(col:ValueExpr, min:ValueExpr, max:ValueExpr);

    // <RegExp Pattern>.match(<column>)
    POpRegex(col:ValueExpr, pattern:ValueExpr);

    // (<column> LIKE '<GLOB patterns>')
    POpMatch(col:ValueExpr, pattern:PatternExpr);

    // (<column> is <DataType>)
    POpIs(col:ValueExpr, type:ValueExpr);

    // (exists(<column>)
    POpExists(column: ValueExpr);

    POpWith(scope:ValueExpr, expr:PredicateExpr);

    // len(<column>[]) == <const integer>
    //POpSizeEq(col:ValueExpr, right:ValueExpr);

    /*
     {match_element,matchElement}(
      <column>[],
      where([{] | @:where {
       [= &SUBQUERY =]
      } | [}])
      --OR--
      @with(<column>  => $element) [@any | @every] {
         <predicate>
      }
    */
    POpElemMatch(column:ValueExpr, predicate:PredicateExpr, greedy:Bool);
}

typedef SubPredicate = PredicateExpr;

enum PatternExpr {
    PatRegexp(re: EReg);
    PatGlob(glob: Dynamic); //TODO
    PatNoop; //[=Not yet Used=]
}
