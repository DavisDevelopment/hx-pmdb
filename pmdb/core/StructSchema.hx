package pmdb.core;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;

import pmdb.core.ds.*;
import pmdb.core.ds.map.*;

import haxe.extern.EitherType;

import haxe.EnumFlags;
import haxe.Serializer;
import haxe.Unserializer;

//using pmdb.ql.ts.DataTypes;

class StructSchema {
    /* Constructor Function */
    public function new() {
        fields = new Dictionary();
        indexes = new Dictionary();

        _init();
    }

/* === Methods === */

    function _init() {
        inline _refresh();
    }

    function _refresh() {
        if (_pk == null || !hasField(_pk) || !fields.get( _pk ).primary) {
            _findPrimary();
        }
    }

    function _findPrimary() {
        _pk = null;
        for (field in fields) {
            if (field.primary) {
                _pk = field.name;
                break;
            }
        }
        if (_pk == null) {
            addField(_pk = '_id', String, [Primary, Unique]);
        }
        return _pk;
    }

    public function createField(name, type:ValType, ?flags) {
        var field = new StructSchemaField(name, type);
        if (flags != null)
            field.addFlags( flags );
        return field;
    }

    public function addField(name:String, type:ValType, ?flags:Array<FieldFlag>):StructSchemaField {
        return createField(name, type, flags)
            .tap(function(field) {
                insertField(field);
            });
    }

    function insertField(field: StructSchemaField) {
        fields[field.name] = field;
        if (field.primary) {
            if (_pk != null && field.name != _pk) {
                dropField( _pk );
            }
            _pk = field.name;
        }
    }

    public function dropField(field: EitherType<String, Int>) {
        if ((field is Int))
            fields.remove(fields.getByIndex((field : Int)).name);
        else
            fields.remove((field : String));
    }

    public inline function hasField(name: String):Bool {
        return fields.exists( name );
    }

    public inline function field(name: String):StructSchemaField {
        return cast(fields.get(name), StructSchemaField);
    }

    public inline function fieldNames():Array<String> {
        return fields.keyArray();
    }

    public function validateStruct(o: Object<Dynamic>):Bool {
        for (field in fields) {
            if (!o.exists(field.name) || o[field.name] == null) {
                if (!field.isOmittable()) {
                    throw new Error('missing field "${field.name}"');
                    return false;
                }
            }

            if (!field.checkValueType(o[field.name])) {
                throw new Error('${o[field.name]} should be ${field.type}');
                return false;
            }
        }

        return true;
    }

    public function prepareStruct(o: Object<Dynamic>):Object<Dynamic> {
        var doc:Object<Dynamic> = Arch.deepCopy( o );

        if (!doc.exists( primaryKey )) {
            switch (field(primaryKey).type) {
                case TAny|TScalar(TString):
                    doc[primaryKey] = Arch.createNewIdString();

                case TScalar(TBytes):
                    doc[primaryKey] = haxe.io.Bytes.ofString(Arch.createNewIdString());

                case _:
                    throw new Error('Cannot auto-generate doc\'s primary-key, as the assigned column ("$primaryKey") is declared as a ${fieldType(primaryKey)} value');
            }
        }

        return doc;
    }

    public inline function createIndex(kind, ?name, ?algo, ?type) {
        return new IndexDefinition(this, kind, name, algo, type);
    }

    public function putIndex(kind, ?name, ?algo, ?type:ValType) {
        var idx = createIndex(kind, name, algo, type);
        insertIndex( idx );
        return idx;
    }

    @:access( pmdb.core.StructSchema.IndexDefinition )
    function insertIndex(i: IndexDefinition) {
        indexes[i.name] = i;
        i.owner = this;
    }

    public function addIndex(desc: IndexInit):IndexDefinition {
        return switch desc {
            case {name:null, kind:null}:
                throw new Error('Either "name" or "kind" fields MUST be provided');

            case {name:_, kind:null}: putIndex(
                    Simple(DotPath.fromPathName(desc.name)),
                    desc.name,
                    desc.algorithm,
                    desc.type
                );

            case {name:null, kind:_}: putIndex(
                    desc.kind,
                    '${desc.kind}',
                    desc.algorithm,
                    desc.type
                );

            case other:
                throw new Error('Invalid IndexInit object $other');
        }
    }

    public inline function hasIndex(name: String):Bool {
        return indexes.exists( name );
    }

    public inline function removeIndex(name: String):Bool {
        return indexes.remove( name );
    }

    public function toDataType():DataType {
        return DataType.TAnon(toObjectType());
    }

    public function toObjectType() {
        var o = new CObjectType([]);
        o.fields.resize( fields.length );
        for (i in 0...fields.length) {
            o.fields[i] = new Property(
                fields[i].name,
                fields[i].type,
                fields[i].optional
            );
        }
        return o;
    }

    /**
      get the data type for the field associated with the given FieldPath
     **/
    public function fieldType(name: String):Null<DataType> {
        var path = name.split('.');
        if (path.length == 1) {
            return fields.get(path[0]).type;
        }
        else {
            return lookupLoopType(fields.get(path.shift()), path);
        }
    }

    @:keep
    public function hxSerialize(s: Serializer) {
        s.serialize( fields.length );
        for (field in fields) {
            field.hxSerialize( s );
        }
        s.serialize( indexes.length );
        for (idx in indexes) {
            idx.hxSerialize( s );
        }
    }

    @:keep
    public function hxUnserialize(u: Unserializer) {
        fields = new Dictionary();
        indexes = new Dictionary();
        for (i in 0...cast(u.unserialize(), Int)) {
            var field = Type.createEmptyInstance(StructSchemaField);
            field.hxUnserialize( u );
            insertField( field );
        }
        for (i in 0...cast(u.unserialize(), Int)) {
            var idx = Type.createEmptyInstance(IndexDefinition);
            idx.hxUnserialize( u );
            insertIndex( idx );
        }
    }

    static function lookupLoopType<Prop:TypedAttr>(prop:Prop, path:Array<String>):Null<DataType> {
        switch ( prop.type ) {
            case TAnon(anon), TNull(TAnon(anon)):
                switch (anon.get(path.shift())) {
                    case null:
                        return null;

                    case field:
                        if (path.length == 0) {
                            return field.type;
                        }
                        else {
                            return lookupLoopType(field, path);
                        }
                }

            case _:
                throw 'Invalid lookup';
        }
    }

/* === Properties === */

    public var primaryKey(get, never): String;
    inline function get_primaryKey():String return _pk == null ? _findPrimary() : _pk;

/* === Fields === */

    public var fields(default, null): Dictionary<StructSchemaField>;
    public var indexes(default, null): Dictionary<IndexDefinition>;

    private var _pk(default, null): Null<String> = null;
}

class StructSchemaField {
    public function new(name, type, ?flags) {
        this.name = name;
        this.flags = flags == null ? new EnumFlags() : flags;

        this.type = type;
    }

/* === Methods === */

    public function clone():StructSchemaField {
        return new StructSchemaField(name, type, flags);
    }

    public function addFlags(flags: Array<FieldFlag>) {
        for (flag in flags)
            inline addFlag( flag );
    }

    public function addFlag(flag: FieldFlag) {
        flags.set( flag );
        calcEType();
    }

    public function removeFlag(flag: FieldFlag) {
        flags.unset( flag );
        calcEType();
    }

    public inline function hasFlag(flag: FieldFlag):Bool {
        return flags.has( flag );
    }

    public inline function is(flag: FieldFlag):Bool {
        return hasFlag( flag );
    }

    public function getComparator():Comparator<Dynamic> {
        return type.getTypedComparator();
    }

    public function getEquator():Equator<Dynamic> {
        return type.getTypedEquator();
    }

    public inline function isOmittable():Bool {
        return optional || primary || type.match(TNull(_));
    }

    public function checkValueType(value: Dynamic):Bool {
        return etype.checkValue( value );
    }

    public function toString() {
        return 'FieldDefinition("$name", ...)';
    }

    inline function calcEType() {
        etype = type;
        if (isOmittable())
            etype = etype.makeNullable();
    }

    @:keep
    public function hxSerialize(s: Serializer) {
        s.serialize( name );
        s.serialize( etype );
        s.serialize(flags.toInt());
    }

    @:keep
    public function hxUnserialize(u: Unserializer) {
        name = u.unserialize();
        etype = u.unserialize();
        flags = u.unserialize();
    }

    public inline function extract(o: Dynamic):Null<Dynamic> {
        return Reflect.field(o, name);
    }

    public inline function assign(o:Dynamic, value:Dynamic):Null<Dynamic> {
        Reflect.setField(o, name, value);
        return value;
    }

    public inline function exists(o: Dynamic):Bool {
        return Reflect.hasField(o, name);
    }

/* === Properties === */

    public var optional(get, never): Bool;
    inline function get_optional() return hasFlag(Optional);

    public var unique(get, never): Bool;
    inline function get_unique() return hasFlag(Unique);

    public var primary(get, never): Bool;
    inline function get_primary():Bool return is(Primary);

    public var type(default, set): DataType;
    inline function set_type(v: DataType) {
        this.type = v;
        calcEType();
        return type;
    }

/* === Fields === */

    public var name(default, null): String;
    public var flags(default, null): EnumFlags<FieldFlag>;

    private var etype(default, null): DataType;
}

enum FieldFlag {
    Primary;
    Optional;
    Unique;
    AutoIncrement;
}

class IndexDefinition {
    public function new(schema, kind, ?name, ?algo, ?type) {
        this.owner = schema;
        this.kind = kind;
        this.name = name == null ? kindName(kind) : name;
        this.algorithm = algo == null ? IndexAlgo.AVLIndex : algo;
        this.type = kindType(owner, kind);
    }

/* === Methods === */

    @:keep
    public function hxSerialize(s: Serializer) {
        s.serialize( name );
        s.serialize( kind );
        s.serialize( algorithm );
        s.serialize( type );
    }

    public function hxUnserialize(u: Unserializer) {
        name = u.unserialize();
        kind = u.unserialize();
        algorithm = u.unserialize();
        type = u.unserialize();
    }

    static function kindName(k: IndexType):String {
        return switch k {
            case Simple(path): path.pathName;
            case Compound(a): a.map(kindName).join(',');
            case Expression(e): '$e';
        }
    }

    public function toString() {
        return 'IndexDefinition(...)';
    }

    static function kindType(schema:StructSchema, k:IndexType):DataType {
        return switch k {
            case Simple(path) if (path.path.length == 1): schema.fields.get(path.pathName).type;
            case Simple(_.pathName => key): schema.fieldType( key );
            case Expression(_): TAny;
            case Compound(arr): TTuple(arr.map(x -> kindType(schema, x)));
        }
    }

/* === Fields === */

    public var name(default, null): String;
    @:keep
    public var algorithm(default, null): IndexAlgo;
    public var type(default, null): DataType;
    public var kind(default, null): IndexType;

    @:allow( pmdb.core.StructSchema )
    public var owner(default, null): StructSchema;
}

@:keep
enum IndexType {
    Simple(path: DotPath);
    Compound(types: Array<IndexType>);
    Expression(expr: ValueExpr);
}

@:keep
enum abstract IndexAlgo (String) from String to String {
    var AVLIndex;
}

typedef TypedAttr = {
    var name(default, null): String;
    var type(default, null): DataType;
}

typedef IndexInit = {
    ?name: String,
    ?type: ValType,
    ?kind: IndexType,
    ?algorithm: IndexAlgo
};
