package pmdb.ql.ts;

enum TypedData {
    DNull;
    DAny(v: Dynamic);
    DInteger(n: Int);
    DDouble(n: Float);
    DBoolean(b: Bool);
    DString(s: String);
    DBytes(b: haxe.io.Bytes);
    DDate(d: Date);

    DArray(values: Array<TypedData>);
    DObject(properties: Array<{name:String, value:TypedData}>);

    DClass<T>(proto:Class<T>, value:T);
    DEnum<E:EnumValue>(proto:Enum<E>, value:E);
}
