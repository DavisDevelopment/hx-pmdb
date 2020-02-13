package pmdb.core;

import pm.datetime.DateTime;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ts.TypeSystemError;

import pmdb.core.ds.*;
import pmdb.core.ds.map.*;
import pmdb.core.Object;
import pmdb.core.schema.*;
import pm.map.Dictionary;
import pm.map.OrderedMap;

import haxe.rtti.*;
import haxe.rtti.CType;
import haxe.extern.EitherType;

import haxe.EnumFlags;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.macro.Expr;

import pmdb.core.schema.Types;
import pmdb.core.schema.SchemaField;

using pmdb.ql.ts.DataTypes;
using StringTools;
//using tannus.ds.StringUtils;
using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;

typedef StructSchemaConfig = {
    autoInsertIndexes: Bool,
    ignoreTypes: Bool,
    
    primaryKey: Bool
};

/**
  data class which manages and represents the role, shape and type structure of an anonymous object within a particular context in the pmdb library
 **/
class StructSchema {
    /* Constructor Function */
    public function new(?typeClass: Class<Dynamic>) {
        _construct_init();
        
        if (typeClass != null) {
            this.type = {
                proto: typeClass
            };
        }

        if (type != null) {
            if (Rtti.hasRtti( typeClass )) {
                var rt = Rtti.getRtti( typeClass );
                type.info = rt;
            }
        }

        _construct();
    }

/* === Fields === */

	public var fields(default, null):Dictionary<SchemaField>;
	public var indexes(default, null):Dictionary<IndexDefinition>;
	public var type(default, null):Null<StructClassInfo> = null;

	private var _pk(default, null):Null<String> = null;
	private var options:StructSchemaConfig;

    private var _dirty(default, null):Bool = false;
    private var _packedAt(default, null):Null<DateTime> = null;
    private var _preventExtension(default, null):Bool = false;

/* === Properties === */

	public var primaryKey(get, never):String;

	function get_primaryKey():String {
		// return _pk == null ? _findPrimary(false) : _pk;
		if (!_pk.empty())
			return _pk;
		if (_pk == null)
			_findPrimary(false);
		if (_pk == null)
			return '';
		return _pk;
	}

/* === Methods === */

    private function _construct() {
        inline _refresh();
        _type_init_();
    }

    private function _construct_init() {
        fields = new Dictionary();
        indexes = new Dictionary();
        this.type = null;
        this._dirty = false;
        this._packedAt = null;
        this._preventExtension = false;
        this.options = {
            autoInsertIndexes: true,
            primaryKey: true,
            ignoreTypes: false
        };
    }

    function _type_init_() {
        if (type != null) {
            if (type.info != null) {
                //TODO
                //for (field in type.info.fields) {
                    
                //}
            }
        }
    }

    function _refresh() {
        if (_pk == null || !hasField(_pk) || !fields.get( _pk ).primary) {
            _findPrimary(true);
        }
    }

    /**
      attempts to identify the primary-key field, and assign [_pk] to its name
      if no primary field is declared, then a new, auto-generated primary-key field is created
     **/
    inline function _findPrimary(ensure: Bool) {
        _pk = null;

        for (field in fields) {
            if (field.primary) {
                _pk = field.name;
                break;
            }
        }

        if (ensure && options.autoInsertIndexes && _pk == null) {
            addField(_pk = '_id', String, [Primary, Unique, AutoIncrement]);
        }

        return _pk;
    }

    /**
      [betty]
     **/
    public function pack() {
        var oldPacketAt = this._packedAt;
        if (_dirty || true) {
            _packedAt = DateTime.now();
            for (idx in indexes) switch idx.kind {
                case IndexType.Simple({path: [fieldName]}):
                    var correspondingField = fields.get(fieldName);
                    if (correspondingField == null) {
                        correspondingField = this.addField(fieldName, idx.keyType);
                    }

                case IndexType.Expression(e):
                    throw 'Unhandled $e';

                default:
            }

            for (field in fields) {
                if (field.unique) {
                    var correspondingIdx = indexes.find(function(idx) {
                        return switch idx.kind {
                            case Simple({path:[name]}): name==field.name;
                            default: false;
                        }
                    });

                    if (correspondingIdx == null) {
                        correspondingIdx = this.addIndex({
                            name: field.name,
                            kind: Simple(DotPath.fromPath([field.name])),
                            type: field.type,
                            algorithm: IndexAlgo.AVLIndex
                        });
                    }
                }
                
            }
        }
        // throw new pm.Error.NotImplementedError();
    }

    /**
      perform basic sanity and coherence checks, and error out if any fail
     **/
    public function validate(unsafe=false):Bool {
        if (!_dirty && options.primaryKey && (_pk == null || !hasField(_pk) || !fields.get(_pk).primary)) {
            if (!unsafe)
                return false;
            else
                throw new pm.Error('StructSchema is missing its primary-key, but is configured to require one');
        }
        return true;
        //TODO more checks
    }

    /**
      create and return a FrozenStructSchema from [this]
     **/
    public function freeze():FrozenStructSchema {
        return new FrozenStructSchema(
            this.fields.keys().array().map(function(k) {
                return {
                    name: k,
                    type: fields[k].type,
                    flags: {
                        optional: fields[k].optional,
                        unique: fields[k].unique,
                        primary: fields[k].primary,
                        autoIncrement: fields[k].autoIncrement
                    }
                };
            }),
            //[],
            this.indexes.iterator().map(function(i) {
                
                return {
                    name: i.name,
                    type: i.keyType,
                    algorithm: i.algorithm,
                    kind: i.kind
                };
            }).array()
        );
    }

    /**
      create and return a new `SchemaField` instance
     **/
    public function createField(name, type:ValType, ?flags) {
        var field = new SchemaField(name, type);
        if (flags != null)
            field.addFlags( flags );
        return field;
    }

    public function addField(name:String, type:ValType, ?flags:Array<FieldFlag>):SchemaField {
        return createField(name, type, flags)
            .tap(function(field) {
                insertField(field);
            });
    }

    /**
      [TODO]
       - allow "locking" of a schema
       - make mutations to a schema observable
       - add useful options object to schema, making it flexible
     **/
    public function insertField(field: SchemaField) {
        fields[field.name] = field;
        if (field.primary) {
            if (_pk != null && field.name != _pk) {
                dropField( _pk );
            }
            _pk = field.name;
        }
    }

    public function dropField(field: EitherType<String, EitherType<Int, SchemaField>>):Bool {
        return if ((field is Int))
            fields.remove(fields.getByIndex((field : Int)).name)
        else if ((field is String))
            fields.remove((field : String))
        else if ((field is SchemaField))
            fields.remove(cast(field, SchemaField).name)
        else
            #if debug
            throw new pm.Error('Invalid dropField argument: $field') 
            #else 
            false 
            #end;
    }

    public inline function dropFieldNamed(fieldName: String):Bool {
        return fields.remove(fieldName);
    }

    public inline function hasField(name: String):Bool {
        return fields.exists( name );
    }

    public function field(name: String):Null<SchemaField> {
        return switch fields.get( name ) {
            case null: null;
            case fi: cast(fi, SchemaField);
        }
    }

    public inline function fieldNames():Array<String> {
        return fields.keyArray();
    }

    public static function areSchemasEqual(a:StructSchema, b:StructSchema):Bool {
        var strSort:String->String->Int = (a:String, b:String)->Reflect.compare(a, b);
        var aFields = a.fields.keyArray(), bFields = b.fields.keyArray();
        aFields.sort(strSort);
        bFields.sort(strSort);
        if (!Arch.areArraysEqual(aFields, bFields)) return false;
        trace('field keys are equal');
        var aIndexes = a.indexes.keyArray(), bIndexes = b.indexes.keyArray();
        aIndexes.sort(strSort);
        bIndexes.sort(strSort);
        trace([aIndexes, bIndexes]);
        if (!Arch.areArraysEqual(aIndexes, bIndexes)) return false;
        trace('index keys are equal');

        for (i in 0...aFields.length) {
            var aField = a.fields[aFields[i]], bField = b.fields[bFields[i]];
            if (!aField.equals(bField)) {
                trace('${aField.name} != ${bField.name}');
                return false;
            }
        }

        for (i in 0...aIndexes.length) {
            // if (!a.indexes[aIndexes[i]])
        }

        return true;
    }

    /**
      [TODO] add fields to StructSchema for tracking field information over iterated calls to `validateStruct`
     **/
    public function validateStruct(o:Struct, unsafe=false):Bool {
        var keepTrackOfExtraFields = true;
        var structFields = o.keys();

        for (field in fields) {
            if (!o.exists(field.name) || o[field.name] == null) {
                if (!field.isOmittable()) {
                    if (unsafe)
                        throw SchemaError.FieldNotProvided(field);
                    else
                        return false;
                }
            }

            if (!field.checkValueType(o[field.name])) {
                throw new pmdb.core.Error('${o[field.name]}:${o[field.name].dataTypeOf().print()} should be ${field.type}\nin object ${haxe.Json.stringify(o)}');
                return false;
            }

            if (keepTrackOfExtraFields) {
                structFields.remove(field.name);
            }
        }

        if (keepTrackOfExtraFields && !structFields.empty()) {
            structFields.sort(cast Reflect.compare);
            var extraFields = [for (name in structFields) name=>o[name].dataTypeOf()];
        }

        return true;
    }

    /**
      perform initialization on [o] to prepare it for insertion into the data store
      [TODO]
       - create actual Struct type, which implements its own methods for the operations I'm relying on `Arch` to provide currently
     **/
    public function prepareStruct(o: Struct):Struct {
        // create the document object which will actually be inserted into the Store's internal cache
        var doc: Struct;
        #if (row_type_coerce)
        if (type != null && !Std.is(o, type.proto)) {
            doc = Arch.buildClassInstance(type.proto, Arch.clone(o, ShallowRecurse));
        }
        else if (type == null && Type.getClass(o) != null) {
            doc = Arch.anon_copy(o, null, v -> Arch.clone(v, ShallowRecurse));
        }
        else {
            doc = Arch.clone(o, ShallowRecurse);
        }
        #else
        doc = Arch.clone(o, ShallowRecurse);
        #end

        // redeclare the document, (This really shouldn't be being done)
        var doc:Struct = Arch.clone(Arch.ensure_anon(o), ShallowRecurse);

        // ensure that the primary-key field has a value
        if (!doc.exists(primaryKey) || doc[primaryKey] == null) {
            switch (field( primaryKey )) {
                case {type:TAny|TScalar(TString)}:
                    doc[primaryKey] = Arch.createNewIdString();

                case f={type:TScalar(TInteger)} if ( f.autoIncrement ):
                    doc[primaryKey] = f.incr();

                case _:
                    throw new pmdb.core.Error('Cannot auto-generate doc\'s primary-key, as the assigned column ("$primaryKey") is declared as a ${fieldType(primaryKey)} value');
            }
        }

        /* === [Sanity Checks] === */


        // this will ensure that the document has been altered such that it can be inserted successfully into a Store<?>
        // and ensure that the shape/structure of documents passing through the schema can have analytics reliably captured
        validateStruct(doc, true);

        return doc;
    }

    /**
      convert the given Doc to an object of the type that will be expected by functions handling Store outputs
     **/
    public function export(doc: Doc):Dynamic {
        if (type != null && !Std.is(doc, type.proto)) {
            var proto:Dynamic = type.proto;
            if (Reflect.hasField(proto, 'hxFromRow')) {
                doc = proto.hxFromRow(doc);
            }
            else {
                doc = Arch.buildClassInstance(type.proto, Arch.clone(doc, ShallowRecurse));
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
        var i:Dynamic = untyped desc;
        if ((i is IndexDefinition)) {
            insertIndex(cast(i, IndexDefinition));
            return cast(i, IndexDefinition);
        }

        return switch desc {
            case {name:null, kind:null}:
                throw new pmdb.core.Error('Either "name" or "kind" fields MUST be provided');

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

            case literal:
                trace(literal);
                putIndex(desc.kind, desc.name, desc.algorithm, desc.type);
        }
    }

    public inline function hasIndex(name: String):Bool {
        return indexes.exists( name );
    }

    public inline function removeIndex(name: String):Bool {
        return indexes.remove( name );
    }

    public function toJson():JsonSchemaData {
        return {
            rowClass: (nn(type) && nn(type.proto) && (type.proto is Class<Dynamic>)) ? Type.getClassName(type.proto) : null,
            version: 1,
            fields: fields.array().map(field -> field.toJson()),
            indexes: indexes.array().map(idx -> idx.toJson())
        };
    }

    public function toDataType():DataType {
        return DataType.TAnon(toObjectType());
    }

    @:deprecated("StructSchema should represent a DataType category of its own")
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

    public function toString():String {
        var res = '{';
        for (field in fields) {
            res += field.name;
            res += ': ';
            res += field.etype.print();
            res += ',';
        }
        res = res.beforeLast(',');
        res += '}';
        return res;
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

    public static function ofComplexType(type: haxe.macro.ComplexType):StructSchema {
        return switch type {
            case haxe.macro.ComplexType.TAnonymous(fields):
                var res = new StructSchema();
                for (f in fields) {
                    betty(res, f);
                }
                return res;

            default:
                throw 'ass';
        }
    }

    private static function betty(schema:StructSchema, f:haxe.macro.Expr.Field) {
        var flags:Array<FieldFlag> = new Array();
        var type:ValType = DataType.TAny;

        if (f.meta != null) {
            for (m in f.meta) {
                switch m.name {
                    case ':optional', 'optional':
                        flags.push(FieldFlag.Optional);

                    case ':primary', 'primary':
                        flags.push(FieldFlag.Primary);

                    case ':unique', 'unique':
                        flags.push(FieldFlag.Unique);

                    case ':autoincrement', 'autoincrement':
                        flags.push(FieldFlag.AutoIncrement);
                }
            }
        }

        switch f.kind {
            case FieldType.FVar(null, _):
                type = DataType.TAny;

            case FieldType.FVar(t, _):
                type = ValType.ofComplexType( t );

            default:
                throw 'ass';
        }

        schema.addField(f.name, type, flags);
        schema.putIndex(Simple( f.name ));
    }

    /**
      [TODO] actually implement this method
     **/
    public static function ofClass<T>(type:Class<T>) {
        if (Rtti.hasRtti(type)) {
            var info = Rtti.getRtti(type);
        }
    }

    public function fromJsonState(state:JsonSchemaData, clearFirst=true) {
        if (clearFirst) {
            this._construct_init();
        }
        for (f in state.fields) {
            var field = new SchemaField(f.name, DataType.TUnknown);
            field.fromJson(f);
            this.insertField(field);
        }
        for (s in state.indexes) {
            this.insertIndex(IndexDefinition.unserialize(this, s));
        }
        this.pack();
    }

    public static function ofJsonState(state: JsonSchemaData) {
        var schema = new StructSchema(state.rowClass.empty()?null:Type.resolveClass(state.rowClass));
        schema.fromJsonState( state );
        return schema;
    }
}



/**
    IndexDefinition - object which represents a Store index
**/
class IndexDefinition {
    public function new(schema, kind, ?name, ?algo, ?type) {
        this.owner = schema;
        this.kind = kind;
        this.name = name == null ? kindName(kind) : name;
        this.algorithm = algo == null ? IndexAlgo.AVLIndex : algo;
        this.keyType = kindType(owner, kind);
    }

/* === Methods === */

    static function kindName(k: IndexType):String {
        return switch k {
            case Simple(path): path.pathName;
            // case Compound(a): "("+a.map(kindName).join(',')+")";
            case Expression(e): '$e';
        }
    }

    public function toString():String {
        return 'IndexDefinition(kind=${kindName(this.kind)}):${keyType.print()}';
    }

    /**
      [TODO]
       - comprehensive index typing
     **/
    static function kindType(schema:StructSchema, k:IndexType):DataType {
        return switch k {
            case Simple(path) if (path.path.length == 1): 
                schema.fields.get(path.pathName).type;
            case Simple(_.pathName => key): 
                schema.fieldType( key );
            case Expression(_): 
                TAny; // 
        }
    }

    public function toJson():JsonSchemaIndex {
        return serialize();
    }

    /**
      extract the "key" from the given struct that the Indexer will file the document under
     **/
    public function extractKey(doc: Struct):Dynamic {
        throw new pm.Error.NotImplementedError();
    }

    public function createIndexMap():Dynamic {
        throw new pm.Error.NotImplementedError('TODO: interface IndexMap');
    }

    public function createIndex():Dynamic {
        throw new pm.Error.NotImplementedError('TODO: interface Index');
    }

    public function serialize():String {
        var s = new Serializer();
        s.useCache = true;
        s.serialize(this);
        return s.toString();
    }

    @:keep
    public function hxSerialize(s: Serializer) {
        s.serialize({
            name: name,
            algorithm: algorithm,
            keyType: keyType,
            kind: kind
        });
    }

    @:keep
    public function hxUnserialize(u: Unserializer) {
        var state:Struct = Struct.unsafe(u.unserialize());
        state.push(this);
    }

    public static function unserialize(schema:StructSchema, serialized:String):IndexDefinition {
        var u = new Unserializer(serialized);
        var idx = u.unserialize();
        assert((idx is IndexDefinition), 'Invalid value');
        var idx:IndexDefinition = cast(idx, IndexDefinition);
        idx.owner = schema;
        return idx;
    }

/* === Fields === */

    public var name(default, null): String;
    @:keep
    public var algorithm(default, null): IndexAlgo;
    
    public var keyType(default, null): DataType;
    public var kind(default, null): IndexType;

    @:allow( pmdb.core.StructSchema )
    public var owner(default, null): StructSchema;
}