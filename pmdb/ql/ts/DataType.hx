package pmdb.ql.ts;

import pmdb.core.ds.Ref;
import pmdb.core.StructSchema;

@:using(pmdb.ql.ts.DataTypes)
enum DataType {
    // a non- value
    TVoid;

    // no value provided at all
    TUndefined;

    // type is unspecified
    TUnknown;

    // allow any non-null value
    TAny;

    // atomic ("scalar") values
    TScalar(type: ScalarDataType);

    // list of values which are all of the same type
    TArray(type: DataType);

    // list of values typed by position in the list
    TTuple(types: Array<DataType>);

    // represents (optionally) named structures with a consistent and predefined schema
    TStruct(schema: pmdb.core.FrozenStructSchema);
    TAnon(type: Null<CObjectType>);

    // represents objects which are instances of [c]
    TClass<T>(c: Class<T>);

    // monomorphic type holder, for progressive mutation of the contained type
    TMono(type: Null<DataType>);

    // type which is omittable
    TNull(type: DataType);

    // type which unifies with both [left] and [right]
    TUnion(left:DataType, right:DataType);
}

@:using(pmdb.ql.ts.DataTypes.ScalarDataTypes)
enum ScalarDataType {
    TBoolean;
    TDouble;
    TInteger;
    TString;
    TBytes;
    TDate;
}

enum ObjectKind {
    KAnonymous;
    KInstanceof(cl: Class<Dynamic>);
}

class CEnumOf<T> {
    public function new() {
        constructs = new Array();
    }

/* === Methods === */

    public inline function addConstruct(name, value) {
        return constructs[constructs.push(new CEnumOfConstruct(this, name, constructs.length, value)) - 1];
    }

/* === Fields === */

    public var constructs(default, null): Array<CEnumOfConstruct<T>>;
}

class CEnumOfConstruct<T> {
    public function new(e:CEnumOf<T>, id:String, idx:Int, v:T):Void {
        tenum = e;
        name = id;
        index = idx;
        value = v;
    }

    public inline function getEnum():CEnumOf<T> {
        return tenum;
    }

    public var name(default, null): String;
    public var index(default, null): Int;
    public var value(default, null): T;

    private var tenum(default, null): CEnumOf<T>;
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
