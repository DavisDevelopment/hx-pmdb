package pmdb.ql.hsn;

import hscript.Expr;
import hscript.Parser;
import hscript.Interp;
import hscript.Printer;

import haxe.Constraints.Function;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.TypeExpr;
import pmdb.ql.ast.QlCommand;
import pmdb.core.Error;
import pmdb.core.Arch;
import pmdb.core.StructSchema;
//import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.ASTError;

import pmdb.ql.ast.Value.ValueExprDef as Ve;
import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.PredicateExpr.PatternExpr as Ptn;
import pmdb.ql.ast.UpdateExpr as Ue;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using hscript.Tools;
using pmdb.ql.hsn.Tools;

class QlParser {
    /* Constructor Function */
    public function new() {
        parser = new Parser();
        parser.allowMetadata = true;
        parser.allowTypes = true;
        parser.allowJSON = true;
        tree = null;
        state = new ParserCtx();

        //ql_functions = ql_functions.map(s -> s.before('('));

        commands = new Map();
        commands['select'] = readSelect;
        commands['find'] = readSelect;
        commands['update'] = readUpdateCmd;
    }

/* === Methods === */

    public static inline function run(code:String, ?schema:StructSchema) {
        return new QlParser()
            .apply(x -> schema != null ? x.useSchema(schema) : x)
            .parse( code );
    }

    public function useSchema(x: StructSchema):QlParser {
        schema = x;
        return this;
    }

    /**
      load the given String into the parser
     **/
    public inline function open(code: String) {
        return tree = parser.parseString(code, null);
    }

    /**
      functional parsing helper
     **/
    inline function fparse<T>(s:String, fn:Expr->T):T {
        return open( s ).passTo( fn );
    }

    /**
      parse [code] as a top-level command
     **/
    public function parse(code: String):QlCommand {
        return fparse(code, readCommand);
    }

    public function parsePredicate(code: String):PredicateExpr {
        return fparse(code, x->readPredicate(x));
    }

    public function parseValue(code: String):ValueExpr {
        return fparse(code, x->readValue(x));
    }

    public function parseUpdate(code: String):UpdateExpr {
        return fparse(code, x->readUpdate(x));
    }

    public function parseDataType(code: String):DataType {
        return fparse(code, x->readDataType(x));
    }

    /**
      parse [e] as a command
     **/
    function readCommand(e: Expr) {
        switch e {
            case ECall(EIdent(cmd), args):
                if (commands.exists(cmd)) {
                    return commands[cmd]( args );
                }
                else {
                    throw 'SyntaxError: $e';
                }

            case _:
                throw 'SyntaxError: $e';
        }
    }

    /**
      build an Update command expression
     **/
    function readUpdateCmd(args: Array<Expr>):QlCommand {
        return switch args {
            case [uops]: QlCommand.QlUpdate(readUpdateExpr(uops));
            case [uops, Expr.ECall(Expr.EIdent('where'), pred)]: QlCommand.QlUpdate(readUpdateExpr(uops), readFullPredicate(pred));
            case _:
                throw new Error('SyntaxError: ${Printer.toString(EBlock(args))}');
        }
    }

    /**
      convert the given Expr to an UpdateExpr
     **/
    function readUpdateExpr(e: Expr):UpdateExpr {
        switch ( e ) {
            // simple value assignment
            case Expr.EBinop('=', left, right):
                return Ue.UAssign(readValue(left), readValue(right));

            // transform "x += 1" => "x = x + 1"
            case Expr.EBinop(binop, left, right) if (binop.endsWith('=')):
                var lv = readValue(left);
                var rv = readValue(Expr.EBinop(binop.before('='), left, right));
                return Ue.UAssign(lv, rv);

            /**
              TODO add support for dedicated increment/decrement operators
             **/
            // transform "--x" => "x = x - 1"
            case Expr.EUnop('--', _, expr):
                return readUpdateExpr(Expr.EBinop('-=', expr, EConst(Const.CInt(1))));

            // transform "++x" => "x = x + 1"
            case Expr.EUnop('++', _, expr):
                return readUpdateExpr(Expr.EBinop('+=', expr, EConst(Const.CInt(1))));

            case Expr.EMeta('delete', null, attr) | Expr.ECall(EIdent('delete'), [attr]):
                return Ue.UDelete(readValue( attr ));

            case Expr.ECall(EIdent('push'), [list, value]):
                return Ue.UPush(readValue(list), readValue(value));

            /* transform o.f(p...) => f(o, p...) */
            case Expr.ECall(EField(oexpr, method), args): 
                return readUpdateExpr(Expr.ECall(Expr.EIdent(method), [oexpr].concat(args)));

            case Expr.EObject(fields):
                var ufields:Array<UpdateStructField> = fields.map(function(field):UpdateStructField {
                    return {
                        field: field.name,
                        value: readValue( field.e )
                    };
                });
                return Ue.UStruct( ufields );

            case Expr.EBlock(subs):
                switch subs {
                    case []: 
                        return UNoOp;
                    case [a]: 
                        return readUpdateExpr( a );
                    case _:
                        return Ue.UBlock(subs.map(x -> readUpdateExpr(x)));
                }

            default:
                throw new Error('SyntaxError: ${Printer.toString(e)} is not a valid update-operator');
        }
    }

    public function readUpdate(e: Expr):UpdateExpr {
        return readUpdateExpr( e );
    }

    /**
      read an array of dot-path components
     **/
    function readDotPath(e: Expr):Array<String> {
        return switch e {
            case EIdent(n): [n];
            case EField(e, n): readDotPath(e).concat([n]);
            case EArray(e, i=EConst(CInt(idx))): readDotPath(e).concat(['$idx']);
            case EParent(e): readDotPath(e);
            default: throw new Error('SyntaxError: ${Printer.toString(e)} is not a valid property path');
        }
    }

    /**
      parse out a SELECT statement
     **/
    function readSelect(args: Array<Expr>):QlCommand {
        var f3 = args.splice(0, 4);
        return switch f3 {
            case [EIdent(tableName)|ECall(EIdent('table'), [EIdent(tableName)|EConst(CString(tableName))]), _, ECall(EIdent('where'), predicate)]:
                return QlCommand.QlSelect(tableName, null, readFullPredicate(predicate));

            case [ECall(EIdent('where'), predicate)]:
                return QlCommand.QlFind(readFullPredicate(predicate));

            case _:
                throw 'SyntaxError: $args';
        }
    }

    /**
      read out the full predicate expression
     **/
    function readFullPredicate(exprs:Array<Expr>, ?joinOp:EvBinop):PredicateExpr {
        if (joinOp == null)
            joinOp = OpAnd;
        var tokens:Array<Expr> = exprs.copy();
        if (tokens.empty()) {
            return PNoOp;
        }
        else if (tokens.length == 1) {
            return readPredicate(exprs[0]);
        }
        else {
            var res = readPredicate(tokens.shift());
            while (tokens.length > 0) {
                res = (switch joinOp {
                    case OpAnd: PredicateExpr.POpBoolAnd;
                    case OpOr : PredicateExpr.POpBoolOr;
                    case _: throw new Error('$joinOp is not a valid joiner for predicates');
                })(res, readPredicate(tokens.shift()));
            }
            return res;
        }
    }

    public function readPredicate(e: Expr):PredicateExpr {
        switch e {
            // a block of predicate expressions
            case EBlock(subs): 
                return readFullPredicate( subs );

            case EParent(e): 
                return readPredicate( e );

            case ECall(EIdent('is'|'eq'|'equals'), [l, r]) | EBinop('==', l, r):
                return POpEq(readValue(l), readValue(r));

            case ECall(EIdent('neq'|'nequals'), [l, r]) | EBinop('!=', l, r):
                return POpNotEq(readValue(l), readValue(r));

            case ECall(EIdent('gt'), [l, r]) | EBinop('>', l, r):
                return POpGt(readValue(l), readValue(r));

            case ECall(EIdent('gte'), [l, r]) | EBinop('>=', l, r):
                return POpGte(readValue(l), readValue(r));

            case ECall(EIdent('lt'), [l, r]) | EBinop('<', l, r):
                return POpLt(readValue(l), readValue(r));

            case ECall(EIdent('lte'), [l, r]) | EBinop('<=', l, r):
                return POpLte(readValue(l), readValue(r));

            case ECall(EIdent('isIncluded'|'isIn'|'within'), [l, r]):
                return POpIn(readValue(l), readValue(r));

            case ECall(EIdent('between'|'in_range'), [val, min, max]):
                return POpInRange(readValue(val), readValue(min), readValue(max));

            case EBinop('=>', left, EMeta('in'|':in', _, right)):
                switch (right) {
                    case EBinop('...', min, max):
                        return POpInRange(readValue(left), readValue(min), readValue(max));

                    case container:
                        return POpIn(readValue(left), readValue(container));
                }

            case EBinop('&&', EBinop('>', val1, min), EBinop('<', val2, max)) if (val1.equals(val2)):
                return POpInRange(readValue(val1), readValue(min), readValue(max));
            
            case Expr.ECall(Expr.EIdent('notin'), [l, r]):
                return POpNotIn(readValue(l), readValue(r));

            case Expr.EUnop('!', true, e=(readPredicate(_) => POpIn(col, seq))):
                return POpNotIn(col, seq);

            case Expr.ECall(EIdent('exists'), [EIdent(column)]): 
                return POpExists(mkv(Ve.ECol(column)));

            case Expr.ECall(EIdent('exists'), [path=EField(_, _)|EArray(_, _)]): 
                return POpExists(mkv(Ve.ECol(readDotPath(path).join('.'))));

            case Expr.ECall(EIdent('match'), [left, right]):
                return POpRegex(readValue(left), readValue(right));

            case Expr.EMeta('match'|':match', [value], pattern):
                return POpMatch(readValue(value), readPattern(pattern));
            
            case Expr.ECall(EIdent('has'|'contains'|'includes'), [left, right]): 
                return POpContains(readValue(left), readValue(right));

            /* transform o.f(p...) => f(o, p...) */
            case Expr.ECall(EField(oexpr, method), args): 
                return readPredicate(Expr.ECall(Expr.EIdent(method), [oexpr].concat(args)));

            /**
              [= Scope-Modification Expression =]
             **/
            case Expr.EMeta('with'|':with', [scopeCtx], check):
                switch ( scopeCtx ) {
                    case EMeta('every'|':every', null, EBinop('=>', iterableExpr, itemExpr)):
                        return POpElemMatch(readValue(iterableExpr), readPredicate(check.replace(itemExpr, EIdent('this'))), true);

                    case EBinop('=>', iterableExpr, itemExpr):
                        return POpElemMatch(readValue(iterableExpr), readPredicate(check.replace(itemExpr, EIdent('this'))), false);

                    default:
                        return POpWith(readValue(scopeCtx), readPredicate(check));
                }
                
            case Expr.EBinop('&&', left, right): 
                return POpBoolAnd(readPredicate(left), readPredicate(right));

            case Expr.EBinop('||', left, right): 
                return POpBoolOr(readPredicate(left), readPredicate(right));

            case Expr.EUnop('!', true, sub): 
                return POpBoolNot(readPredicate( sub ));

            default:
                throw new Error('Unexpected $e');
        }
    }

    /**
      read/parse a Pattern expression
     **/
    function readPattern(expr: Expr):PatternExpr {
        return switch ( expr ) {
            //TODO
            default:
                throw new Unexpected( expr );
        }
    }

    /**
      parse a Value expression
     **/
    public function readValue(e: Expr):ValueExpr {
        return switch (e) {
            case Expr.EParent(e): readValue(e);

            /* [= CONSTANTS =] */
            //TODO make Null(Any) Null(Unknown)
            case Expr.EIdent('null'): 
                mkv(Ve.EConst(ConstExpr.CNull), TNull(TAny));

            case Expr.EIdent('true'):
                mkv(Ve.EConst(ConstExpr.CBool(true)), TScalar(TBoolean));

            case Expr.EIdent('false'): 
                mkv(Ve.EConst(ConstExpr.CBool(false)), TScalar(TBoolean));

            case Expr.EIdent('_'):
                mkv(Ve.EVoid);
            
            case Expr.EIdent('this'):
                mkv(Ve.EThis);

            case Expr.EIdent( name ):
                //TODO lookup column type when known
                mkv(Ve.ECol(name));

            case Expr.EField(ve, n):
                //|Expr.EArray(ve, n=isExprOfString(_)=>true):
                mkv(Ve.EAttr(readValue(ve), n));

            case Expr.EConst( c ): 
                switch c {
                    case Const.CFloat(n): 
                        mkv(Ve.EConst(ConstExpr.CFloat(n)), TScalar(TDouble));
                    case Const.CInt(i): 
                        mkv(Ve.EConst(ConstExpr.CInt(i)));
                    case Const.CString(s):
                        mkv(Ve.EConst(ConstExpr.CString(s)));
                }
                
            /* [= DECLARATIONS =] */
            case Expr.EObject(fields): 
                mkv(Ve.EObject(fields.map(f -> {k:f.name, v:readValue(f.e)})));

            case Expr.EArrayDecl(values):
                mkv(Ve.EList([for (v in values) readValue(v)]));
            
            case Expr.EFunction(args, expr=isLambdaExpr(_)=>true, null, _):
                throw 'Lambda expressions not yet implemented';

            /* [= PARAMETER INTERPOLATION =] */
            case Expr.ECall(EIdent('arg'), [Expr.EConst(CInt(n))])
                |Expr.EMeta('arg'|':arg'|'param'|':param', [], Expr.EConst(CInt(n)))
                |Expr.EArray(EIdent('arguments'), Expr.EConst(CInt(n))):
                    mkv(Ve.EReificate( n ));

            /* [= UNARY OPERATORS =] */
            case Expr.EUnop('-', true, e): 
                mkv(Ve.EUnop(EvUnop.UNeg, readValue(e)));

            /* [= BINARY OPERATORS =] */
            case Expr.EBinop('+', l, r): mkv(Ve.EBinop(EvBinop.OpAdd, readValue(l), readValue(r)));
            case Expr.EBinop('-', l, r): mkv(Ve.EBinop(EvBinop.OpSub, readValue(l), readValue(r)));
            case Expr.EBinop('*', l, r): mkv(Ve.EBinop(EvBinop.OpMult, readValue(l), readValue(r)));
            case Expr.EBinop('/', l, r): mkv(Ve.EBinop(EvBinop.OpDiv, readValue(l), readValue(r)));
            case Expr.EBinop('=', l, r): mkv(Ve.EBinop(EvBinop.OpAssign, readValue(l), readValue(r)));
            case Expr.EBinop('&', l, r): mkv(Ve.EBinop(EvBinop.OpAnd, readValue(l), readValue(r)));
            case Expr.EBinop('|', l, r): mkv(Ve.EBinop(EvBinop.OpOr, readValue(l), readValue(r)));
            case Expr.EBinop('<<', l, r): mkv(Ve.EBinop(EvBinop.OpShl, readValue(l), readValue(r)));
            case Expr.EBinop('>>', l, r): mkv(Ve.EBinop(EvBinop.OpShr, readValue(l), readValue(r)));
            case Expr.EBinop('>>>', l, r): mkv(Ve.EBinop(EvBinop.OpUShr, readValue(l), readValue(r)));
            case Expr.EBinop('...', l, r): mkv(Ve.ERange(readValue(l), readValue(r)));
            case Expr.EBinop('=>', l, r): mkv(Ve.EBinop(EvBinop.OpArrow, readValue(l), readValue(r)));

            case Expr.ECheckType(expr, ctype): mkv(Ve.ECast(readValue(expr), readCType(ctype)));

            /* [= FUNCTION CALLS =] */
            case Expr.ECall(EIdent(fname), args): readFCall(fname, args);
            case Expr.ECall(EField(oexpr, method), args): readFCall(method, [oexpr].concat(args));

            /* [= ARRAY ACCESS =] */
            case Expr.EArray(item, index): 
                mkv(Ve.EArrayAccess(readValue(item), readValue(index)));

            /* [= FIELD ACCESS =] */
            //case Expr.EField(_, _): 
                //mkv(Ve.ECol(readDotPath( e ).join('.')));

            default:
                throw new Error('Unexpected $e');
        }
    }

    function mkv(d:ValueExprDef, ?type:DataType):ValueExpr {
        return {expr:d, type:type};
    }

    function isExprOfString(e: Expr) {
        return switch e {
            case EConst(CString(_)): true;
            case Expr.ECheckType(_, CType.CTPath(['String'], null)): true;
            case Expr.ECall(EIdent('cast'), [_, EIdent('String')]): true;
            case EParent(e): isExprOfString(e);
            case EBinop('+', isExprOfString(_)=>l, isExprOfString(_)=>r): (l || r);
            default: false;
        }
    }

    function isLambdaExpr(e: Expr) {
        return e.match(EBlock([EReturn(_)])|EReturn(_));
    }

    /**
      parse the given CType as a TypeExpr
     **/
    public function readCType(ctype: CType):TypeExpr {
        switch (ctype) {
            case CType.CTParent(t):
                return readCType( t );

            case CType.CTPath(path, null):
                return TypeExpr.TEPath(TypePath.ofArray( path ));

            case CType.CTPath(path, params):
                var tpath = TypePath.ofArray( path );
                tpath.params = params.map(t -> readCType(t));
                return TypeExpr.TEPath(tpath);

            case CType.CTAnon(fields):
                return TypeExpr.TEAnon(fields.map(f -> {name:f.name, t:readCType(f.t)}));

            case other:
                throw new Error('Unexpected $other');
        }
    }

    /**
      parse the given Expr as a TypeExpr
     **/
    public function readDataType(type: Expr):DataType {
        return switch (type) {
            case Expr.EIdent(oid=(_.toLowerCase() => id)): switch id {
                case 'any'|'dynamic': DataType.TAny;
                case 'object'|'anon': DataType.TAnon(null);
                case 'bool'|'boolean': DataType.TScalar(TBoolean);
                case 'float'|'number'|'double': DataType.TScalar(TDouble);
                case 'int'|'integer'|'short'|'long': DataType.TScalar(TInteger);
                case 'string'|'text': DataType.TScalar(TString);
                case 'date'|'datetime': DataType.TScalar(TDate);
                case 'bytes'|'bytearray': DataType.TScalar(TBytes);
                default: switch (Type.resolveClass(oid)) {
                    case null:
                        throw new Unexpected(type);
                    case classType: DataType.TClass(classType);
                }
            }
            case Expr.ECall(Expr.EIdent(_.toLowerCase() => id), args): switch ([id, args]) {
                case ['array', [type]]: DataType.TArray(readDataType(type));
                case ['null', [type]]: DataType.TNull(readDataType(type));
                case ['either'|'eithertype', [a, b]]: DataType.TUnion(readDataType(a), readDataType(b));
                case ['anyof', types]: types.map(x -> readDataType(x)).reduceInit((x, y) -> TUnion(x, y));
                default: 
                    throw new Unexpected(type);
            }
            case Expr.EField(_,_): switch (Type.resolveClass(readDotPath(type).join('.'))) {
                case null:
                    throw new Unexpected(type);
                case classType: DataType.TClass(classType);
            }
            case Expr.EArrayDecl([type]): DataType.TArray(readDataType(type));
            case Expr.EArray(type, EConst(Const.CInt(size))): DataType.TArray(readDataType(type));
            case Expr.EObject([]): DataType.TAnon(null);
            case Expr.EObject(fields): DataType.TAnon(new CObjectType(fields.map(field -> new Property(field.name, readDataType(field.e)))));
            case Expr.EBinop('|', left, right): DataType.TUnion(readDataType(left), readDataType(right));
            case Expr.EParent(type): readDataType(type);
            default:
                throw new Unexpected(type);
        }
    }

    /**
      attempts to resolve the given name to a runtime type
     **/
    function resolveType(name: String):Option<Either<Class<Dynamic>, Enum<Dynamic>>> {
        return switch (Type.resolveClass( name )) {
            case null: switch (Type.resolveEnum( name )) {
                case null: None;
                case enumType: Some(Right(enumType));
            }
            case classType: Some(Left(classType));
        }
    }

    /**
      read a ValueExpr from a function-invokation
     **/
    function readFCall(name:String, args:Array<Expr>):ValueExpr {
        switch [name, args] {
            case ['re'|'regex', [EConst(CString(regex))]]:
                return mkv(Ve.EConst(CRegexp(Arch.compileRegexp(regex))), TClass(EReg));

            case ['re'|'regex', [EConst(CString(regex)), EConst(CString(flags))|EIdent(flags)]]:
                return mkv(Ve.EConst(CRegexp(Arch.compileRegexp(regex, flags))), TClass(EReg));

            case [_, _]:
                return mkv(Ve.ECall(name, args.map(readValue)));
        }
    }

    function isBuiltinName(id: String):Bool {
        return builtins[0].has( id ) || builtins[1].has( id );
    }

    function unpack(e: Expr):Array<Expr> {
        return switch e {
            case EBlock(a): a;
            case EParent(e): [e];
            case _: [e];
        }
    }

    function pack(e:Array<Expr>, flatten:Bool):Expr {
        if ( flatten ) {
            return EBlock(e.map(x -> unpack(x)).flatten());
        }
        else {
            return switch e {
                case [x]: x;
                case _: EBlock(e);
            }
        }
    }

/* === Variables === */

    var parser: Parser;
    var tree: Null<Expr>;
    var schema: Null<StructSchema> = null;
    var state: ParserCtx;

    public var builtins(default, null): Array<Array<String>>;

    //var ql_commands: Array<String> = ['SELECT', 'UPDATE', 'DELETE', 'CREATE', 'ALTER', 'DROP', 'INSERT'];
    //var ql_clauses: Array<String> = ['FROM', 'WHERE', 'PRIMARY', 'AUTO_INCREMENT', 'INTO', 'VALUES', 'ORDER', 'AS', 'SET'];
    //var ql_operators: Array<String> = [];
    //var ql_functions: Array<String> = [
        //'abs(n: Float)',
        //'max(x, y):Any',
        //'min(x, y):Any',
        //'hex(x):String',
        //'length(x):Int',
        //'random():Float',
        //'rtrim(x):Any',
        //'trim(x):Any',
        //'ltrim(x):Any',
        //'upper(x):String',
        //'like(column:Any, pattern:Pattern)',
        //'lower(x):String',
        //'typeof(x):String',
        //'instr(x:String, y:String):Bool',
        //'substr(x, y, z)'
    //];

    public var commands: Map<String, Array<Expr> -> QlCommand>;
}

enum Mask {
    MArray(values: Array<MaskValue>);
    MObject(fields: Array<{field:String, value:MaskValue}>);
}

enum MaskValue {
    MVColumn(c: String);
}

@:structInit
class ParserCtx {
    /* Constructor Function */
    public inline function new() {
        in_command = in_clause = false;
        current_command = current_clause = null;
    }

    @:optional
    public var in_command: Bool;
    @:optional
    public var current_command: Null<String>;
    @:optional
    public var in_clause: Bool;
    @:optional
    public var current_clause: Null<String>;
}

