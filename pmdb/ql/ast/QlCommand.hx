package pmdb.ql.ast;

enum QlCommand {
    QlSelect(t:String, m:Null<Dynamic>, q:PredicateExpr);
    QlFind(q:PredicateExpr);
    QlUpdate(u:UpdateExpr, ?p:PredicateExpr);
    QlRemove(q:PredicateExpr, multiple:Bool);
}
