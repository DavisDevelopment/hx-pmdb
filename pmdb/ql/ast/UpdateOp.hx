package pmdb.ql.ast;

import pmdb.core.Object;

enum UpdateOp {
    USet(key:String, value:Dynamic);
    UDelete(key: String);
    UInc(key:String, value:Dynamic);
    UMin(key:String, value:Dynamic);
    UMax(key:String, value:Dynamic);
    UMul(key:String, value:Dynamic);
    URename(oldKey:String, newKey:String);

/* === Array Operations === */

    UPush(key:String, value:PushValue<Dynamic>);
    UAddToSet(key:String, value:PushValue<Dynamic>);
    UPop(key:String, value:Int);
    UPull(key:String, value:Dynamic);
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

@:build(pmdb.ql.aif.EnumBuilders.enumCopyWithoutFirstArg('pmdb.ql.aif.UpdateOp'))
enum KeyUpdateOp {}
