package pmdb.ql.ast;

enum QlCommand {
    QlSelect(t:String, m:Null<Dynamic>, q:PredicateExpr);
    QlFind(q:PredicateExpr);
    QlUpdate(u:UpdateOp, ?p:PredicateExpr);
    QlRemove(q:PredicateExpr, multiple:Bool);
}
