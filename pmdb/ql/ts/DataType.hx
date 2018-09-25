package pmdb.ql.ts;

enum DataType {
    TAny;
    TScalar(type: ScalarDataType);
    TNull(type: DataType);
    TArray(type: DataType);
    TUnion(left:DataType, right:DataType);
    TStruct(schema: DocumentSchema);
    TAnon(type: Null<CObjectType>);

    // should these even be here?
    TClass(c: DataTypeClass);
    //TEnum(etype: Enum<Dynamic>);
}

enum ScalarDataType {
    TBoolean;
    TInteger;
    TDouble;
    TString;
    TBytes;

    TDate;
}

class CObjectType {
    /* Constructor Function */
    public function new(fields, ?params) {
        this.fields = fields;
        this.params = params;
    }

    public function get(name: String):Null<Property> {
        for (x in fields)
            if (x.name == name)
                return x;
        return null;
    }

    public var fields(default, null): Array<Property>;
    public var params(default, null): Null<Array<String>>;
}

class Attribute {
    /* Constructor Function */
    public function new(name) {
        this.name = name;
    }

    public var name(default, null): String;
}

class Property extends Attribute {
    /* Constructor Function */
    public function new(name, type, opt=false) {
        super( name );
        this.type = type;
        this.opt = opt;
    }

/* === Instance Fields === */

    public var type(default, null): DataType;
    public var opt(default, null): Bool;
}

class CEnumType {
    /* Constructor Function */
    public function new(constructs, ?valueType) {
        this.constructs = constructs;
        this.valueType = valueType == null ? TScalar(TInteger) : valueType;
    }

    public var constructs(default, null): Array<CEnumConstruct>;
    public var valueType(default, null): DataType;
}

class CEnumConstruct {
    /* Constructor Function */
    public function new(e, name, ?args) {
        this.name = name;
        this.enumType = e;
        this.args = args;
    }

/* === Instance Methods === */
/* === Instance Fields === */

    public var name(default, null): String;
    public var enumType(default, null): CEnumType;
    public var args(default, null): Null<Array<Argument>>;
}

class Argument {
    /* Constructor Function */
    public function new(name, ?type) {
        this.name = name;
        this.type = type == null ? TAny : type;
    }

    public var name(default, null): String;
    public var type(default, null): DataType;
}
