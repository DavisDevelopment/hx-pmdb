package pmdb.ql.ast;

import pmdb.core.Object;
import pmdb.ql.ast.Value;

enum UpdateOp {
    USet(key:String, value:ValueExpr);
    UDelete(key: String);
    //UInc(key:String, value:ValueExpr);
    //UMin(key:String, value:ValueExpr);
    //UMax(key:String, value:ValueExpr);
    //UMul(key:String, value:ValueExpr);
    URename(oldKey:String, newKey:String);

/* === Array Operations === */

    //UPush(key:String, value:PushValue<ValueExpr>);
    //UAddToSet(key:String, value:PushValue<ValueExpr>);
    //UPop(key:String, value:Int);
    //UPull(key:String, value:ValueExpr);

/* === Combinators === */

    UCombine(a:UpdateOp, b:UpdateOp);
}

enum PushValue<T> {
    PVOne(value: T);
    PVMany(value: PushMany<T>);
}

@:structInit
class PushMany<T> {
    public var values(default, null): Array<T>;
    @:optional public var position(default, null): Int;
    @:optional public var slice(default, null): Int;
    @:optional public var sort(default, null): Sorting;
}

#if !(macro || eval)
@:build(pmdb.ql.ast.EnumBuilders.enumCopyWithoutFirstArg('pmdb.ql.ast.UpdateOp')) 
#end
enum KeyUpdateOp {}
