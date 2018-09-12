package pmdb.ql.types;

enum DataType {
    TAny;
    TScalar(type: ScalarDataType);
    TNull(type: DataType);
    TArray(type: DataType);
    TUnion(left:DataType, right:DataType);
    TAnon(type: Null<CObjectType>);

    // should these even be here?
    TClass(ctype: Class<Dynamic>);
    //TEnum(etype: Enum<Dynamic>);
}

enum ScalarDataType {
    TBoolean;
    TInteger;
    TDouble;
    TString;

    TDate;
}

class CObjectType {
    /* Constructor Function */
    public function new(fields) {
        this.fields = fields;
    }

    public var fields(default, null): Array<Property>;
}

class Property {
    /* Constructor Function */
    public function new(name, type, opt=false) {
        this.name = name;
        this.type = type;
        this.opt = opt;
    }

/* === Instance Fields === */

    public var name(default, null): String;
    public var type(default, null): DataType;
    public var opt(default, null): Bool;
}
