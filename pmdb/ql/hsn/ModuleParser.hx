package pmdb.ql.hsn;

import hscript.Expr;
import hscript.Parser;
import hscript.Interp;

import haxe.Constraints.Function;

import pmdb.ql.ts.DataType;
import pmdb.core.ValType;
import pmdb.core.StructSchema;

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

        hsvm = null;

        ast = null;
        //schema = new DocumentSchema();
        schema = new StructSchema();
        types = new Map();
    }

    public static function run(text: String) {
        return new ModuleParser().parse( text );
    }

    private function initVm():Interp {
        hsvm = new Interp();
    }

    @:access( hscript.Interp )
    private function evaluate(expression: Expr):Dynamic {
        var ctx = hsvm == null ? initVm() : hsvm;

        return ctx.expr( expression );
    }

    //@:access( hscript.Interp )
    //private function compileClosure(f: FunctionDecl):Function {
       
    //}

    /**
      
     **/
    @:access( hscript.Interp )
    private function compileFunc(func:FunctionDecl, ?prep:Interp->Void):Function {
        var expr:Expr = Expr.EFunction(func.args, func.expr, null, func.ret);
        var fun:Function = evaluate( expr );
        var wrapped:Function = Reflect.makeVarArgs(function(args: Array<Dynamic>):Dynamic {
            var ret = Reflect.callMethod(self, f, args);
            return self;
        });
        return wf;
    }

    public function loadSource(text: String) {
        ast = parser.parseModule( text );
    }

    /**
      parse, process and return schema from the given String data
     **/
    public function parse(?code: String):StructSchema {
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
                types[name] = TAnon({
                    fields: cast fields
                });

            case CType.CTParent(t):
                declareType(name, t);

            case _:
                null;
        }
    }

    private function resolveTType(name: String):Null<TType> {
        return types[name];
    }

    private function parseClassDecl(type: ClassDecl):StructSchema {
        schema = new StructSchema();
        methods = new Array();

        var dtnew = null;

        for (field in type.fields) {
            parseClassField(field, type, schema);
        }

        for (m in methods) {
            //
        }

        return schema;
    }

    /**
      parse out a type declaration, sha
     **/
    private function parseTypeDecl(type: TypeDecl) {
        //TODO
    }

    private function parseClassField(field:FieldDecl, c:ClassDecl, schema:StructSchema) {
        //switch field.kind {
        //    case FieldKind.KFunction(func):
        //        func.args.unshift({
        //            name: 'self',
        //            t: CType.CTPath([c.name])
        //        });
        //        methods.push( func );

        //    case FieldKind.KVar(prop): 
        //        var dprop:DocumentProperty = new DocumentProperty(field.name, TAny);
        //        if (prop.type != null) {
        //            dprop.setType(parseCType(prop.type));
        //        }

        //        for (flag in field.access) {
        //            switch flag {
        //                case APrivate:
        //                    dprop.annotations.push(ANoIndex);

        //                case _:
        //                    continue;
        //            }
        //        }

        //        for (entry in field.meta) {
        //            switch entry.name {
        //                case ':ignore'|'ignore':
        //                       dprop.annotations.push(ANoIndex);

        //                case ':id'|'id':
        //                       dprop.annotations.push(APrimary);

        //                case ':optional'|'optional':
        //                       dprop.setSparse( true );

        //                case ':unique'|'unique':
        //                       dprop.setUnique( true );

        //                case other:
        //                       trace('"$other" metadata unrecognized');
        //            }
        //        }

        //        switch dprop.type {
        //            case TNull(_):
        //                dprop.setSparse( true );

        //            case _:
        //                //
        //        }

        //        schema.properties.push( dprop );
        //}
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

    /**
      parse out a CTAnon struct definition
     **/
    private function parseCTAnon(fields: Array<{t:CType, name:String, meta:Metadata}>):CObjectType {
        return new CObjectType(fields.map(function(field) {
            return new Property(field.name, parseCType(field.t));
        }));
    }

/* === Fields === */

    var ast: Null<Array<ModuleDecl>> = null;
    var hsvm: Null<Interp> = null;
    var parser:Parser;
    var schema: StructSchema;

    var main: Null<ClassDecl> = null;
    var methods: Null<Array<FunctionDecl>> = null;

    var types: Map<String, TType>;
    var imports: Null<Array<{path:Array<String>, all:Bool}>> = null;
    var packageName: Null<String> = null;
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
