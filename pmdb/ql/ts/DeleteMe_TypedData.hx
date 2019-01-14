package pmdb.ql.ts;

enum TypedData {
    /* [= NUL & UNTYPED =] */
    DNull;
    DAny(v: Dynamic);

    /* [= ATOMIC TYPES =] */
    DBool(b: Bool);
    DInt(n: Int);
    DFloat(n: Float);


    //DString(s: String);
    //DBytes(b: haxe.io.Bytes);
    //DDate(d: Date);

    DTuple(typedValues:Array<TypedData>, values:Array<Dynamic>);
    DArray(elemType:DataType, values:Array<Dynamic>);
    DObject(fields:Array<{name:String, value:TypedData}>, object:Dynamic);
    //DArray(values: Array<TypedData>);
    //DObject(properties: Array<{name:String, value:TypedData}>);

    DClass<T>(proto:Class<T>, value:T);
    DEnum<E>(proto:Enum<E>, value:E);
}

class CTypedValue {
    public var value(default, null): Dynamic;
    public var type(default, null): Lazy<ConcreteType>;

    public function new(v:Dynamic, ?t:ConcreteType) {
        value = v;
        if (t == null)
            type = Type.typeof.bind(value);
        else
            type = t;
    }
}

private typedef ConcreteType = ValueType;
