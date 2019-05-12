package pmdb.core;

import pmdb.core.StructSchema.IndexType;
import pmdb.core.StructSchema.IndexAlgo;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;

import pmdb.core.ds.*;
import pmdb.core.ds.map.*;
import pmdb.core.Object;
import pmdb.core.StructSchema;

import haxe.rtti.*;
import haxe.rtti.CType;
import haxe.extern.EitherType;

import haxe.EnumFlags;
import haxe.Serializer;
import haxe.Unserializer;

import haxe.ds.ReadOnlyArray;

import haxe.macro.Expr;

using pmdb.ql.ts.DataTypes;
using StringTools;
//using tannus.ds.StringUtils;
using pm.Strings;
using pm.Iterators;
using pm.Functions;

/**
  TODO
  TODO
  TODO
  TOdo!
**/
class FrozenStructSchema {
    public function new(fields:Iterable<FieldInit>, indexes:Iterable<IndexDefInit>, ?opt:{?methods:StructSchemaMethodsInit}):Void {
        var myfields:Array<FrozenStructSchemaField>;
        var myindexes:Array<FrozenIndexDefinition>;
        var myprimary:Int = -1;

        // compute the list of fields
        myfields = fields.map(freezeFieldInit).array();
        this.fieldNameToOffset = new haxe.ds.StringMap<Int>();
        for (offset in 0...myfields.length) {
            fieldNameToOffset[myfields[offset].state.name] = offset;

            // handle primary-key special case
            if (myfields[offset].state.flags.primary) {
                #if debug
                if (myprimary != -1) {
                    throw new pm.Error('primary-key cannot be declared as more than one field');
                }
                myprimary = offset;
                #else 
                if (myprimary == -1) {
                    myprimary = offset;
                }
                #end
            }
        }

        // compute the indexes list
        myindexes = indexes.map(x -> freezeIndexDefInit(this, x)).array();
        this.indexNameToOffset = new Map();
        for (offset in 0...myindexes.length) {
            indexNameToOffset[myindexes[offset].state.name] = offset;
        }

        if (myprimary == -1) {
            // handle unspecified primary-key
            // by inserting a '_id' primary key at offset=0, and shifting existing offsets to the right by `1`
            myfields.unshift(new FrozenStructSchemaField({
                name: '_id',
                etype: DataType.TScalar(TInteger),
                flags: {
                    optional: false,
                    primary: true,
                    autoIncrement: true,
                    unique: true
                }
            }));

            // update `this.pkey`
            myprimary = 0;

            // dictate that documents be indexed by the new '_id' field
            myindexes.unshift(new FrozenIndexDefinition(this, {
                name: '_id',
                kind: Simple(Arch.getDotPath('_id')),
                type: DataType.TScalar(TInteger),
                algorithm: IndexAlgo.AVLIndex
            }));

            // increment pointers
            for (k in fieldNameToOffset.keys())
                fieldNameToOffset[k]++;

            for (k in indexNameToOffset.keys())
                indexNameToOffset[k]++;
        }

        // finally commit computed values onto [this] instance
        this.fields = myfields;
        this.indexes = myindexes;
        this.pkey = myprimary;

        #if debug
            assert(!fields.empty() && !indexes.empty() && pkey != -1, 'Not a valid schema structure');
        #end
    }

/* === Methods === */

    public function field(n: String):FrozenStructSchemaField {
        if (fieldNameToOffset.exists( n )) {
            return fields[fieldNameToOffset[n]];
        }
        throw new pm.Error('$this has no attribute "${n}"', 'InvalidAccess');
    }

    public function index(handle: String):FrozenIndexDefinition {
        if (indexNameToOffset.exists( handle ))
            return indexes[indexNameToOffset[handle]];
        throw new pm.Error('"${handle}" does not refer to any Index on $this');
    }

    public function hasField(n: String):Bool {
        return fieldNameToOffset.exists( n );
    }
    
    public function fieldNames():Array<String> {
        return fieldNameToOffset.keys().array();
    }

    public function validateStruct(o: Doc):Bool {
        return this.methods.is( o );
    }

    public function prepareStruct(o: Doc):Doc {
        return this.methods.prepare( o );
    }

    static function freezeFieldInit(i: FieldInit):FrozenStructSchemaField {
        assert(i.name!=null&&!i.name.empty());
        if (i.flags == null) i.flags = {};
        return new FrozenStructSchemaField({
            name: i.name,
            etype: nor(i.type, DataType.TUndefined).tap(t -> assert(!t.match(TUndefined|TUnknown))),
            flags: {
                optional: nor(i.flags.optional, false),
                unique: nor(i.flags.unique, false),
                primary: nor(i.flags.primary, false),
                autoIncrement: nor(i.flags.autoIncrement, false)
            }
        });
    }

    static function freezeIndexDefInit(schema:FrozenStructSchema, i:IndexDefInit):FrozenIndexDefinition {
        switch i {
            case {name:null, type:null, algorithm:null, kind:null}:
                throw new ValueError(i, 'the given IndexDefInit object is invalid, as it contains no values');

            case  {name:name, type:_, algorithm:_, kind:null}
                | {name:_, type:_, algorithm:_, kind:Simple({pathName:name})}:
                //TODO
                i.type = DataType.TAny;
                i.name = name;
                i.kind = IndexType.Simple(new DotPath(name.split('.'), name));
                i.algorithm = switch i.type {
                    case TAny, TUnknown, TUndefined: IndexAlgo.AVLIndex;
                    case other: IndexAlgo.AVLIndex;
                }

            case other:
                throw new pm.Error('Unsupported IndexDefInit shape');
        }

        assert(
            i.name != null &&
            !i.name.empty() &&
            i.type != null &&
            i.algorithm != null &&
            i.kind != null
        );
        
        return new FrozenIndexDefinition(schema, {
            name: i.name,
            type: i.type,
            algorithm: nor(i.algorithm, IndexAlgo.AVLIndex),
            kind: i.kind
        });
        //throw 'poop';
    }

    //

/* === Properties === */

    public var primaryKey(get, never): String;
    inline function get_primaryKey():String return this.fields[this.pkey].state.name;

/* === Variables === */

    // array of immutable Field models
    public final fields : ReadOnlyArray<FrozenStructSchemaField>;
    // mapping of field-names to their indices in `fields`
    var fieldNameToOffset : Map<String, Int>;
    
    // array of immutable indexing definitions
    public final indexes : ReadOnlyArray<FrozenIndexDefinition>;
    var indexNameToOffset : Map<String, Int>;

    // index of the field which will act as a primary key
    final pkey : Int;

    // helper object which stores useful utility methods
    private var methods : StructSchemaMethods;
}

typedef StructSchemaMethods = {
    function is(o: Dynamic):Bool;
    function prepare(doc:Doc):Doc;
    function clone(doc: Doc):Doc;
};

typedef StructSchemaMethodsInit = {
    ?is:Dynamic -> Bool,
    ?prepare: Doc -> Doc,
    ?clone: Doc -> Doc
};

typedef StructSchemaOptions = {
    ?methods: StructSchemaMethodsInit,
    ?type: StructClassInfo
};

class DefaultStructSchemaMethods {
    var schema : FrozenStructSchema;
    public function new(x){
        schema = x;
    }

    dynamic
    public function is(doc: Dynamic):Bool {
        var o:Doc = cast doc;
        for (f in schema.fields) {
            if (!o.exists( f.name ) || o[f.name] == null) {
                if (!f.isOmittable()) {
                    throw new pm.Error('missing field "${f.name}"');
                    return false;
                }
            }
            //
            // ...
            if (!f.type.checkValue(o.get(f.name))) {
                throw new pm.Error('${o[f.name].dataTypeOf().print()} should be ${f.type.print()}', 'for doc.${f.name}: ');
                return false;
            }
        }

        return true;
    }

    dynamic
    public function prepare(doc: Doc):Doc {
        var cc:Doc = this.clone( doc );
        
        // ensure that the primary-key field is present on [doc]
        if (!cc.exists( schema.primaryKey ) || cc[schema.primaryKey] == null) {
            switch (schema.field(schema.primaryKey)) {
                case f={type:TAny|TScalar(TInteger)} if (f.autoIncrement):
                    cc[schema.primaryKey] = f.incr();

                case {type: TScalar(TString)}:
                    cc[schema.primaryKey] = Arch.createNewIdString();

                default:
                     throw new pm.Error('Cannot auto-generate doc\'s primary-key, as the assigned column ("${schema.primaryKey}") is declared as a ${schema.field(schema.primaryKey).type} value');
            }
        }

        return cc;
    }

    dynamic
    public function clone(doc: Doc):Doc {
        //return Arch.clone( doc );
        var cc:Doc = Arch.clone(doc, ShallowRecurse);
        /// ...
        return cc;
    }

    dynamic
    public function createNew(?params:Array<Dynamic>):Doc {
        //[STUB]
        var stub:Doc = new Doc();
        for (k in schema.fieldNames()) {
            stub.set(k, null);
        }
        return stub;
    }
}

typedef FrozenStructSchemaFieldState = {
    final name : String;
    final etype : DataType;
    final flags : {
        final optional : Bool;
        final unique : Bool;
        final primary : Bool;
        final autoIncrement : Bool;
    };
};

typedef FieldInit = {?name:String, ?type:DataType, ?flags:FieldFlagsInit};
typedef FieldFlagsInit = {?optional:Bool,?unique:Bool,?primary:Bool,?autoIncrement:Bool};

typedef FrozenIndexDefinitionState = {
    final name : String;
    final type : DataType;
    final algorithm : IndexAlgo;
    final kind : IndexType;
};
typedef IndexDefInit = {?name:String,?type:DataType,?algorithm:IndexAlgo,?kind:IndexType};

class FrozenStructSchemaField {
    public final state : FrozenStructSchemaFieldState;
    public final comparator : Comparator<Dynamic>;
    public final equator : Equator<Dynamic>;

    private var incrementer : Null<Incrementer>;

    public function new(state) {
        this.state = state;
        this.comparator = this.type.getTypedComparator();
        this.equator = this.type.getTypedEquator();
        this.incrementer = null;
    }

    public function incr():Int {
        assert(state.autoIncrement, 'Invalid Call to incr()');
        if (incrementer == null) {
            incrementer = new Incrementer();
        }
        return incrementer.next();
    }

    public function isOmittable() {
        return state.flags.optional || (state.flags.autoIncrement) || state.etype.match(TNull(_));
    }

    public var name(get, never): String;
    inline function get_name() return this.state.name;

    public var type(get, never): DataType;
    function get_type() return this.state.etype;
}

class FrozenIndexDefinition {
    public final state : FrozenIndexDefinitionState;
    public final schema : FrozenStructSchema;

    public function new(schema, state) {
        this.schema = schema;
        this.state = state;
    }
}