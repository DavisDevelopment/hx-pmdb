package pmdb.core;

import pmdb.core.schema.Types.IndexType;
import pmdb.core.schema.Types.IndexAlgo;
import pmdb.core.schema.FieldFlag;

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
using pm.Arrays;
using pm.Strings;
using pm.Iterators;
using pm.Functions;

#if !(macro || java)
import pm.Assert.aassert as assert;
#end

/**
  TODO
  TODO
  TODO
  TOdo!

```markdown

    ## Roadmap for pmdb.core.FrozenStructSchema:
    
     - [ ] adapt the API to be able to easily describe and access schemas for database documents, as well as nested documents and anonymous objects
     - [ ] support Collection-supervised/-managed documents, which follow a particular protocol _*(TODO: [specification](about:blank))*_
     - [ ] support describing Collection-independent object structures
      - [ ] no index data, because that doesn't even make sense
      - [ ] no primary-key, or auto-increment

```
**/
class FrozenStructSchema {
    public function new(fields:Iterable<FieldInit>, indexes:Iterable<IndexDefInit>, ?opt:{?methods:StructSchemaMethodsInit}):Void {
        #if java try { #end
        var myfields:Array<FrozenStructSchemaField>;
        var myindexes:Array<FrozenStructSchemaIndex>;
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
            myindexes.unshift(new FrozenStructSchemaIndex(this, {
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
        
        if (myindexes.empty()) {
            myindexes.unshift(new FrozenStructSchemaIndex(this, {
                name: myfields[myprimary].name,
				kind: Simple(Arch.getDotPath(myfields[myprimary].name)),
                type: DataType.TScalar(TInteger),
                algorithm: IndexAlgo.AVLIndex
            }));
        }

        // finally commit computed values onto [this] instance
        this.fields = myfields;
        this.indexes = myindexes;
        this.pkey = myprimary;

        this.methods =
            if (opt==null||opt.methods == null) new DefaultStructSchemaMethods(this)
            else throw '[TODO]';

        // assert(!fields.empty() && !indexes.empty() && pkey != -1, new pm.Error('Not a valid schema structure'));
        assert(this.fields.length != 0);
        assert(this.indexes.length != 0);
        assert(this.pkey != -1);

        #if java }
        catch (e: Dynamic) {
            throw e;
        }
        #end
    }

#if java
    
    static function assert(c:Dynamic):Void {
        return ;
    }

#end

/* === Methods === */

    public function field(n: String):FrozenStructSchemaField {
        if (fieldNameToOffset.exists( n )) {
            return fields[fieldNameToOffset[n]];
        }
        throw new pm.Error('$this has no attribute "${n}"', 'InvalidAccess');
    }

    public function index(handle: String):FrozenStructSchemaIndex {
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

    public function hasIndex(id: EitherType<String, IndexType>):Bool {
        if ((id is String)) {
            return this.indexNameToOffset.exists( id );
        }
        else if ((id is IndexType)) {
            return switch (cast(id, IndexType)) {
                case IndexType.Simple({pathName:name}): indexNameToOffset.exists(name);
                case other: throw new pm.Error.ValueError(other, 'Lookup via $other is currently unsupported');
            }
        }
        else {
            throw 'wtf';
        }
    }

    public function fieldType(name: String):Null<DataType> {
        var path = name.split('.');
        if (path.length == 1) {
            return field(path[0]).type;
        }
        else {
            return lookupLoopType(PField(field(path.shift())), path);
        }
    }

    public function thaw(?rowClass: Dynamic):StructSchema {
        var res = new StructSchema(rowClass);
        for (f in fields) {
            var flags = [];
            if (f.state.flags.optional) flags.push(FieldFlag.Optional);
            if (f.state.flags.primary) flags.push(FieldFlag.Primary);
            if (f.state.flags.autoIncrement) flags.push(FieldFlag.AutoIncrement);
            if (f.state.flags.unique) flags.push(FieldFlag.Unique);
            res.addField(f.name, f.type, flags);
        }
        for (i in indexes) {
            res.putIndex(i.state.kind, i.state.name, i.state.algorithm, i.state.type);
        }
        return res;
    }

    public static function ofComplexType(type: haxe.macro.ComplexType):FrozenStructSchema {
        return switch type {
            case haxe.macro.ComplexType.TAnonymous(fields):
                var res:FrozenStructSchemaInit = {
                    fields: new Array<FieldInit>(),
                    indexes: new Array<IndexDefInit>(),
                    options: (cast {} : Dynamic)
                };

                for (f in fields) {
                    addHaxeMacroField(res, f);
                }

                var prim = null;
                for (f in res.fields) {
                    if (f.flags.primary) {
                        if (prim == null) {
                            prim = f;
                        }
                    }
                }

                return buildInit(res);

            case ComplexType.TNamed(_, type), ComplexType.TParent(type):
                ofComplexType(type);

            case other:
                throw 'Unhandled $other';
        }
    }

    public static function ofClass(classType:Class<Dynamic>) {
        if (!Rtti.hasRtti(classType)) {
            throw 'nope';
        }

        var cdef:Classdef = Rtti.getRtti(classType);
        for (field in cdef.fields) {
            trace('${field.type}');
            switch field.type {
                case CUnknown:
                    //
                case CEnum(name, params):
                    //
                case CClass(name, params):
                    //
                case CTypedef(name, params):
                    //
                case CFunction(args, ret):
                    //
                case CAnonymous(fields):
                    //
                case CDynamic(t):
                    //
                case CAbstract(name, params):
                    //
            }
        }
    }

    public static inline function build(schema: FrozenStructSchemaInit):FrozenStructSchema {
        return new FrozenStructSchema(schema.fields, schema.indexes, schema.options);
    }

    private static function buildInit(schema : FrozenStructSchemaInit):FrozenStructSchema {
        return new FrozenStructSchema(schema.fields, schema.indexes, schema.options);
    }

    private static function addHaxeMacroField(schema:FrozenStructSchemaInit, f:haxe.macro.Expr.Field) {
        var flags:Array<FieldFlag> = new Array();
        var type:ValType = DataType.TAny;
        var idx = false;

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

                    case ':index', 'index':
                        idx = true;
                }
            }
        }

        switch f.kind {
            case FieldType.FVar(null, _):
                type = DataType.TAny;

            case FieldType.FVar(t, _):
                switch t {
                    // case null: false;
                    case TParent(t): false;
                    case TOptional(t): false;
                    case TNamed(n, t): false;
                    case TExtend(p, fields): false;
                    case TPath(p): false;
                    
                    case TFunction(args, ret): false;
                    case TAnonymous(fields): false;
                    case TIntersection(types):
                        throw new pm.Error.NotImplementedError('intersection (A & B) types not implemented yet');
                }
                type = ValType.ofComplexType( t );

            default:
                throw 'ass';
        }

        //schema.addField(f.name, type, flags);
        //schema.putIndex(Simple( f.name ));
        schema.fields.push({
            name: f.name,
            type: type,
            flags: {
                optional: flags.has(Optional),
                primary: flags.has(Primary),
                unique: flags.has(Unique)||flags.has(Primary),
                autoIncrement: flags.has(AutoIncrement)
            }
        });
        if ( idx ) {
            schema.indexes.push({name: f.name});
        }
    }

    static function lookupLoopType(prop:Prop, path:Array<String>):Null<DataType> {
        switch (switch prop {
            case PField(f): f.type;
            case PSub(f): f.type;
        }) {
            case DataType.TAnon(anon), DataType.TNull(DataType.TAnon(anon)):

                switch (anon.get(path.shift())) {
                    case null:
                        return null;

                    case field:
                        if (path.length == 0) {
                            return field.type;
                        }
                        else {
                            return lookupLoopType(PSub(field), path);
                        }
                }

            case _:
                throw 'Invalid lookup';
        }
    }

    static function freezeFieldInit(i: FieldInit):FrozenStructSchemaField {
        function nor<T>(x:T, y:T):T {
            return switch x {
                case null: y;
                default: x;
            }
        }

        assert(i.name!=null&&!i.name.empty());
        if (i.flags == null) i.flags = {};
        var etype = nor(i.type, DataType.TUndefined);
        assert(!etype.match(TUndefined|TUnknown));
        return new FrozenStructSchemaField({
            name: i.name,
            etype: etype,
            flags: {
                optional: nor(i.flags.optional, false),
                unique: nor(i.flags.unique, false),
                primary: nor(i.flags.primary, false),
                autoIncrement: nor(i.flags.autoIncrement, false)
            }
        });
    }

    static function freezeIndexDefInit(schema:FrozenStructSchema, i:IndexDefInit):FrozenStructSchemaIndex {
        switch i {
            case {name:null, type:null, algorithm:null, kind:null}:
                throw new ValueError(i, 'the given IndexDefInit object is invalid, as it contains no values');

            case  {name:name, type:_, algorithm:_, kind:null}
                | {name:_, type:_, algorithm:_, kind:Simple({pathName:name})}:
                //TODO
                i.type = DataType.TAny;
                i.name = name;
                
                i.kind = IndexType.Simple(Arch.getDotPath(name));
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
        
        return new FrozenStructSchemaIndex(schema, {
            name: i.name,
            type: i.type,
            algorithm: nor(i.algorithm, IndexAlgo.AVLIndex),
            kind: i.kind
        });
        //throw 'poop';
    }

    //
    public function toString():String {
        var res = '{';
        for (field in fields) {
            res += field.state.name;
            res += ': ';
            res += field.state.etype.print();
            res += ',';
        }
        res = res.beforeLast(',');
        res += '}';
        return res;
    }

/* === Properties === */

    public var primaryKey(get, never): String;
    inline function get_primaryKey():String return this.fields[this.pkey].state.name;

/* === Variables === */

    // array of immutable Field models
    public final fields : ReadOnlyArray<FrozenStructSchemaField>;
    // mapping of field-names to their indices in `fields`
    var fieldNameToOffset : Map<String, Int>;
    
    // array of immutable indexing definitions
    public final indexes : ReadOnlyArray<FrozenStructSchemaIndex>;
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
    ?type: pmdb.core.schema.Types.StructClassInfo
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
                if (o[f.name] == null && f.isOmittable()) {
                    continue;
                }

                throw new pm.Error('${o[f.name].dataTypeOf().print()} should be ${f.type.print()}', 'for doc.${f.name}: ');
                //return false;
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
                case f={type:TAny|TScalar(TInteger)} if (f.state.flags.autoIncrement):
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

typedef FrozenStructSchemaInit = {
    fields: Array<FieldInit>,
    indexes: Array<IndexDefInit>,
    ?options: Dynamic
};

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

//#F2SF
class FrozenStructSchemaField {
    public final state : FrozenStructSchemaFieldState;

    public final comparator : Comparator<Dynamic>;
    public final equator : Equator<Dynamic>;

    private var incrementer : Null<Incrementer>;

    public function new(state) {
        this.state = normalize_state(state);
        this.comparator = this.type.getTypedComparator();
        this.equator = this.type.getTypedEquator();
        this.incrementer = null;
    }

    public function incr():Int {
        assert(state.flags.autoIncrement, 'Invalid Call to incr()');
        if (incrementer == null) {
            incrementer = new Incrementer();
        }
        return incrementer.next();
    }

    public function isOmittable() {
        return state.flags.optional || (state.flags.primary && state.flags.autoIncrement) || state.etype.match(TNull(_));
    }

    public var name(get, never): String;
    inline function get_name() return this.state.name;

    public var type(get, never): DataType;
    function get_type() return this.state.etype;

    
    private static inline function normalize_state(s: FrozenStructSchemaFieldState):FrozenStructSchemaFieldState {
        return {
            name: s.name,
            etype: s.etype,
            flags: {
                unique: s.flags.primary||s.flags.unique,
                optional: s.flags.autoIncrement||s.flags.optional,
                autoIncrement: s.flags.autoIncrement,
                primary: s.flags.primary
            }
        };
    }
}

class FrozenStructSchemaIndex/*Definition*/ {
    public final state : IdxState;
    public final schema : FrozenStructSchema;

    public function new(schema, state) {
        this.schema = schema;
        this.state = state;
    }

    @:keep public function toString() {
		return 'FrozenIndex(name=${state.name}, type=${state.type}, algo=${state.algorithm}, kind=${state.kind})';
    }

    public function sanityCheck(?schema: FrozenStructSchema) {
        var a = pm.Assert.assert;
        var path:Null<DotPath> = null, expr:Null<ValueExpr> = null;

        switch this.state.kind {
            case Simple(dp):
                path = dp;

            case Expression(e)://=(isIndexableExpr(_)=>indexable)):
                var indexable = isIndexableExpr(e);
                trace(
                    ''.append(indexable ? ' ' : '<#F00>NOT</> ')
                    .append('INDEXABLE:\n<bold><#00F> - </>')
                    .append(e.print(false))
                    .append('\n</>')
                );
                expr = e;
                throw new pm.Error.NotImplementedError('Evaluation of expressions by the schema is not yet implemented. This API is merely a stub');
        }

        switch [state.name, state.type, state.kind, state.algorithm] {
            case [name, _, Simple(dp=_.path.length=>1), _]: 
                a(name == dp.pathName);

            case [name, _, Simple(dp), _]:
                //TODO

            default:
                //
        }

        //Beginnings of a thorough sparseness validation algorithm
        /*
        if (schema != null) {
            if (path != null) {
                var sparseness = false;
                var i = 0;
                var cp = path.path[i];
                var cpt = schema.field(cp);
                a(cpt != null);
                if (cpt.isOmittable()) sparseness = true;

                do {
                    var p1 = cp;
                    cp = '$cp.${path.path[++i]}';
                    //Console.examine(p1, cp);

                }
            }
        }
        */
    }

    static function isIndexableExpr(e: ValueExpr):Bool {
        return true;
    }


    // static function STDocument():StructType {throw 0;}
}

typedef FrozenStructSchemaIndexState = {
	final name:String;
	final type:DataType;
	final algorithm:IndexAlgo;
	final kind:IndexType;
};
private typedef IdxState = FrozenStructSchemaIndexState;

typedef IndexDefInit = {?name:String, ?type:DataType, ?algorithm:IndexAlgo, ?kind:IndexType};
private typedef IdxInit = IndexDefInit;

private enum Prop {
    PField(f: FrozenStructSchemaField);
    PSub(f: pmdb.ql.ts.DataType.Property);
}

private enum StructType {
    /**
     * `StructType.STAnonymous`
     * A regular-old JSON object structure, with type safety and constraint validation courtesy of PmDB
     */
    STAnonymous;
    
    /**
	 * `StructType.STDocument`
	 * A Collection Document (or Table Row, if you prefer) object.
	 */
    STDocument;

    /**
     * `StructType.STNested`
     * How the structure-scheme is expressed for object fields which themselves hold objects for which a schema definition is desired.
     */
    STNested(t:StructType, within:FrozenStructSchema);
}