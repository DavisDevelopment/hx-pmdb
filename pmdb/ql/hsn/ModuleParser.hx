package pmdb.ql.hsn;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import hscript.Expr;
import hscript.Parser;
import hscript.Interp;

import haxe.Constraints.Function;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;

import pmdb.core.Error;

using Slambda;
using tannus.ds.ArrayTools;

class ModuleParser {
    /* Constructor Function */
    public function new() {
        parser = new Parser();
        parser.allowMetadata = true;
        parser.allowTypes = true;
        parser.allowJSON = true;
        ast = null;
        //schema = new DocumentSchema();
        types = new Map();
    }

    public static function run(text: String):DocumentSchema {
        return new ModuleParser().parse( text );
    }

    @:access( hscript.Interp )
    private function eval(e:Expr, ?prep:Interp->Void):Dynamic {
        var ctx = new Interp();
        if (prep != null)
            prep( ctx );
        return ctx.expr( e );
    }

    @:access( hscript.Interp )
    private function compileFunc(func:FunctionDecl, ?prep:Interp->Void):Function {
        var e:Expr = Expr.EFunction(func.args, func.expr, null, func.ret);
        var ctx:Interp;
        var f:Function = eval(e, function(i: Interp) {
            ctx = i;
        });
        var wf:Function = Reflect.makeVarArgs(function(args: Array<Dynamic>):Dynamic {
            var self = ctx.variables['this'] = {};
            Reflect.callMethod(self, f, args);
            return self;
        });
        return wf;
    }

    public function loadSource(text: String) {
        ast = parser.parseModule( text );
    }

    public function parse(?code: String):DocumentSchema {
        if (code != null)
            loadSource( code );

        switch ast {
            case [DClass(doc)]:
                return parseClassDecl( doc );

            case [DTypedef(doc)]:
                parseTypeDecl( doc );

            case other:
                imports = new Array();
                for (decl in other) {
                    parseModuleDecl( decl );
                }
                if (main == null) {
                    throw "Missing @:export class";
                }
                parseClassDecl( main );
        }

        return schema;
    }

    private function parseModuleDecl(d: ModuleDecl) {
        switch d {
            case ModuleDecl.DPackage(path):
                packageName = path.join('.');

            case ModuleDecl.DImport(path, null|false):
                imports.push({path:path, all:false});

            case DImport(path, true):
                imports.push({path:path, all:true});

            case ModuleDecl.DTypedef(type):
                declareType(type.name, type.t);

            case DClass(type):
                if (type.meta.any(m -> (m.name == 'export' || m.name == ':export'))) {
                    main = type;
                }
                else {
                    types[type.name] = TClass(type);
                }
        }
    }

    private function declareType(name:String, type:CType) {
        switch type {
            case CType.CTAnon(fields):
                types[name] = TAnon({fields: cast fields});
            case CType.CTParent(t):
                declareType(name, t);
            case _:
                null;
        }
    }

    private function resolveTType(name: String):Null<TType> {
        return types[name];
    }

    private function parseClassDecl(type: ClassDecl):DocumentSchema {
        schema = new DocumentSchema(type.name);
        methods = new Array();

        var dtnew = null;

        for (field in type.fields) {
            parseClassField(field, type, schema);
        }

        for (m in methods) {
            //
        }

        schema.normalize();
        return schema;
    }

    private function parseTypeDecl(type: TypeDecl) {
        
    }

    private function parseClassField(field:FieldDecl, c:ClassDecl, schema:DocumentSchema) {
        switch field.kind {
            case FieldKind.KFunction(func):
                func.args.unshift({
                    name: 'self',
                    t: CType.CTPath([c.name])
                });
                methods.push( func );

            case FieldKind.KVar(prop): 
                var dprop:DocumentProperty = new DocumentProperty(field.name, TAny);
                if (prop.type != null) {
                    dprop.setType(parseCType(prop.type));
                }

                for (flag in field.access) {
                    switch flag {
                        case APrivate:
                            dprop.annotations.push(ANoIndex);

                        case _:
                            continue;
                    }
                }

                for (entry in field.meta) {
                    switch entry.name {
                        case ':ignore'|'ignore':
                               dprop.annotations.push(ANoIndex);

                        case ':id'|'id':
                               dprop.annotations.push(APrimary);

                        case ':optional'|'optional':
                               dprop.setSparse( true );

                        case ':unique'|'unique':
                               dprop.setUnique( true );

                        case other:
                               trace('"$other" metadata unrecognized');
                    }
                }

                switch dprop.type {
                    case TNull(_):
                        dprop.setSparse( true );

                    case _:
                        //
                }

                schema.properties.push( dprop );
        }
    }

    private function parseCType(type: CType):DataType {
        return switch type {
            case CTPath(_.join('.')=>fullName, null):
                switch fullName {
                    case 'Bool': TScalar(TBoolean);
                    case 'Float': TScalar(TDouble);
                    case 'Int': TScalar(TInteger);
                    case 'String': TScalar(TString);
                    case 'Bytes'|'ByteArray': TScalar(TBytes);
                    case 'Date': TScalar(TDate);
                    case _: TAny;
                }

            //case CTPath(['UId'], [CTPath([''])])
            case CTPath(['Array'|'List'], [elem]): TArray(parseCType(elem));
            case CTPath(['Null'], [value]): TNull(parseCType(value));
            case CTPath(['Either'|'EitherType'], [left, right]): TUnion(parseCType(left), parseCType(right));
            case CTPath(['Either'|'EitherType'], multiple): 
                multiple.map(parseCType).compose((l, r) -> TUnion(l, r), x->x);
            case CTParent(type): parseCType(type);
            case CTAnon(fields): TAnon(parseCTAnon( fields ));
            case CTPath(path=_.join('.')=>name, _):
                if (types.exists(name)) {
                    switch types[name] {
                        case TType.TDataType(t): t;
                        case TType.TAnon(t):
                            var dt: DataType;
                            types[name] = TDataType(dt = TAnon(parseCTAnon(cast t.fields)));
                            dt;
                        case _: throw new Error('Unknown type "$name"');
                    }
                }
                else throw new Error('Unknown type "$name"');
            case _: throw new Error('Unsupported type "$type"');
        }
    }

    private function parseCTAnon(fields: Array<{t:CType, name:String, meta:Metadata}>):CObjectType {
        return new CObjectType(fields.map(function(field) {
            return new Property(field.name, parseCType(field.t));
        }));
        //CType.CTAnon(
    }

    var ast: Null<Array<ModuleDecl>> = null;
    var parser:Parser;
    var schema: DocumentSchema;
    var methods: Array<FunctionDecl>;

    var main: Null<ClassDecl> = null;
    var types: Map<String, TType>;
    var imports: Null<Array<{path:Array<String>, all:Bool}>>;
    var packageName: Null<String>;
}

enum TType {
    TDataType(type: DataType);

    TAnon(type: AnonDecl);
    TClass(type: ClassDecl);
    TLazy(f: Void->TType);
}

typedef AnonFieldDecl = {t:CType, name:String, ?meta:hscript.Metadata};

typedef AnonDecl = {
    fields: Array<AnonFieldDecl>
};
