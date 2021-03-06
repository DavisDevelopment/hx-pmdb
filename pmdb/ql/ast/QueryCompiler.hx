package pmdb.ql.ast;

import pmdb.core.ds.Lazy;
import pm.Pair;
// import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.TypeExpr;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.StructSchema;
import pmdb.core.ValType;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.TypedValue;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExprDef as Ve;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.value.*;
import pmdb.ql.ast.nodes.check.*;

import haxe.Constraints.Function;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

using StringTools;
using pm.Arrays;
using pm.Functions;
using pmdb.core.ds.tools.Options;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

/**
  used to compile enum-based syntax representations into hierarchical Syntax Trees
 **/
class QueryCompiler {
    /* Constructor Function */
    public function new():Void {
        //
    }

/* === Methods === */

    public function use(schema: StructSchema):QueryCompiler {
        this.schema = schema;
        return this;
    }

    public function with(ctx: Null<QueryInterp>):QueryCompiler {
        this.context = ctx;
        return this;
    }

    /**
      compile the given QlCommand into a QueryRootNode
     **/
    public function compileQueryCommand<T>(cmd: QlCommand):QueryRootNode<T> {
        throw 'Betty';
    }

    /**
      compile the given UpdateExpr into an Update node
     **/
    public function compileUpdate(e: UpdateExpr) {
        e = preprocessUpdate( e );

        var cu = compileUpdateExpr( e );

        return cu;
    }

    /**
      compiles the given update-expr to an update-node
     **/
    function compileUpdateExpr(e: UpdateExpr):Update {
        switch e {
            case UpdateExpr.UNoOp:
                return new NoUpdate(e);

            case UpdateExpr.UStruct(fields):
                throw new Error('Unexpected $e');

            case UpdateExpr.UAssign(left, right):
                return new AssignUpdate(vnode(left), vnode(right), e);

            case UpdateExpr.UIncr(_, _), UpdateExpr.UDecr(_, _):
                throw new Error('poop');

            case UpdateExpr.UDelete(col):
                return new DeleteUpdate(vnode(col), e);

            case UpdateExpr.UPush(left, right):
                return new PushUpdate(vnode(left), vnode(right), e);

            case UpdateExpr.UBlock(subs):
                return new BlockUpdate(subs.map(sub -> compileUpdateExpr(sub)), e);
        }
    }

    /**
      perform pre-compilation transformations on the update expression
     **/
    public function preprocessUpdate(e: UpdateExpr):UpdateExpr {
        return e;
    }

    /**
      compile the Predicate Expression given into a Check node
     **/
    public function compilePredicate(e: PredicateExpr):Check {
        e = preprocessPredicate( e );

        var ce = compilePredExpr( e );

        return ce;
    }

    /**
      perform pre-compilation transforms on the predicate expression
     **/
    public function preprocessPredicate(e: PredicateExpr):PredicateExpr {
        return e;
    }

    /**
      compile the given PredicateExpression
     **/
    private function compilePredExpr(pe: PredicateExpr):Check {
        return switch pe {
            case Pe.POpBoolAnd(left, right):
                new ConjunctionCheck(compilePredExpr(left), compilePredExpr(right), pe);

            case Pe.POpBoolOr(left, right):
                new DisjunctionCheck(compilePredExpr(left), compilePredExpr(right), pe);

            case Pe.POpBoolNot(check):
                new NegatedCheck(compilePredExpr(check), pe);

            case Pe.PNoOp:
                new NoCheck( pe );

            case Pe.POpEq(left, right):
                var eq;
                if (left.type != null && right.type != null && left.type.unify(right.type)) {
                    eq = left.type.getTypedEquator();
                }
                else {
                    eq = Equator.anyEq();
                }
                new EqCheck(eq, vnode(left), vnode(right), pe);

            case Pe.POpNotEq(left, right):
                new NEqCheck(null, vnode(left), vnode(right), pe);

            case Pe.POpIn(left, right):
                new InCheck(null, vnode(left), vnode(right), pe);

            case Pe.POpNotIn(left, right):
                new NInCheck(null, vnode(left), vnode(right), pe);

            case Pe.POpContains(left, right):
                new ContainsCheck(null, vnode(left), vnode(right), pe);

            case Pe.POpGt(l, r):
                new ComparisonCheck(null, vnode(l), vnode(r), 'gt', pe);

            case Pe.POpGte(l, r):
                new ComparisonCheck(null, vnode(l), vnode(r), 'gte', pe);

            case Pe.POpLt(l, r):
                new ComparisonCheck(null, vnode(l), vnode(r), 'lt', pe);

            case Pe.POpLte(l, r):
                new ComparisonCheck(null, vnode(l), vnode(r), 'lte', pe);

            case Pe.POpExists(col):
                new ExistsCheck(vnode(col), pe);

            case Pe.POpRegex(l, r):
                new RegexpCheck(vnode(l), vnode(r), pe);

            case Pe.POpElemMatch(arr, sub, greedy):
                new ElemMatchCheck(vnode(arr), compilePredicate(sub), greedy, pe);

            case other:
                throw 'Unexpected $other';
        }
    }

    /**
      get the DataType of the column referenced by [col]
     **/
    private function coltype(col: String):ValType {
        return ((
        if (schema != null)
            (
             try
                Some(schema.fieldType( col ))
            catch (err: Dynamic)
                None
            )
        else
            None
        ) : Option<ValType>)
        .or(TNull(TMono(null)))
        .extract('What the fuck?');
    }


    /**
      convert a ValueExpr to a ValueNode
     **/
    private function vnode(e: ValueExpr):ValueNode {
        final node = switch e.expr {
            case Ve.EConst(constant):
                cnode(e, constant);

            case Ve.EThis:
                new ThisNode( e );

            case Ve.EAttr(o, n):
                new AttrAccessNode(vnode(o), n, e);

            case Ve.ECol(column):
                new ColumnNode(column.split('.'), coltype(column));

            case Ve.EReificate(n):
                new ParameterNode(n, e);

            case Ve.EList(values):
                new ListNode(values.map(x -> vnode(x)), e);

            case Ve.ECall(fname, args):
                new BuiltinCallNode(fname, args.map(x -> vnode(x)), e);

            case Ve.ECast(expr, type):
                new AssertTypeNode(vnode(expr), compileConcreteTypeExpr(type), e);

            case Ve.EBinop(op, left, right):
                var oper = switch op {
                    case EvBinop.OpAdd: '+';
                    case EvBinop.OpSub: '-';
                    case EvBinop.OpMult: '*';
                    case EvBinop.OpDiv: '/';
                    case _: '?';
                };
                if (context == null)
                    throw new Error('QueryCompiler.context must be provided');
                if (!context.binops.exists(oper))
                    throw new Error('Operator($oper) not found');
                new ValueBinaryOperatorNode(vnode(left), vnode(right), context.binops[oper], e);

            case Ve.EUnop(EvUnop.UNeg, value):
                new ValueUnaryOperatorNode(vnode(value), context.unops['-'], e);

            case Ve.EArrayAccess(value, index):
                new ArrayAccessNode(vnode(value), vnode(index), e);

            //TODO implement EObject(...)
            case Ve.EObject(fields):
                new ObjectNode(fields.map(function(f) {
                    return {
                        field: f.k,
                        value: vnode(f.v)
                    };
                }), e);
                //throw new NotImplementedError();

            case Ve.ERange(_, _):
                throw new NotImplementedError();

            case Ve.EVoid:
                throw new NotImplementedError();
        }

        node._context = context;

        return node;
    }

    private function cnode(e:ValueExpr, constant:ConstExpr):ConstNode {
        return switch constant {
            case ConstExpr.CNull:
                new ConstNode(null, te(null, TVoid), TNull(TUnknown), e);

            case ConstExpr.CBool(b):
                new ConstNode(b, te(b, TScalar(TBoolean)), e.type, e);

            case ConstExpr.CFloat(n):
                new ConstNode(n, te(n, TScalar(TDouble)), e.type, e);

            case ConstExpr.CInt(n):
                new ConstNode(n, te(n, TScalar(TInteger)), e.type, e);

            case ConstExpr.CString(s):
                new ConstNode(s, te(s, TScalar(TString)), e.type, e);

            case ConstExpr.CRegexp(re):
                new ConstNode(re, te(re, TClass(EReg)), e.type, e);

            case ConstExpr.CCompiled(typedValue):
                new ConstNode(typedValue.value, typedValue, typedValue.type, e);
        }
    }

    private static function te(value: Dynamic, ?type:DataType):TypedValue {
        return new TypedValue(value, type == null ? value.dataTypeOf() : type);
    }

    public function typeofValueExpr(expr:ValueExpr, ?expected:ValType):Null<ValType> {
        return switch expr.expr {
            case Ve.EConst(constant):
                switch constant {
                    case ConstExpr.CNull:
                        //new ConstNode(null, TypedValue.DNull, e);
                        TMono(expected);

                    case ConstExpr.CBool(b):
                        //new ConstNode(b, TypedValue.DBool(b), e);
                        TScalar(TBoolean);

                    case ConstExpr.CFloat(n):
                        //new ConstNode(n, TypedValue.DFloat(n), e);
                        TScalar(TDouble);

                    case ConstExpr.CInt(n):
                        //new ConstNode(n, TypedValue.DInt(n), e);
                        TScalar(TInteger);

                    case ConstExpr.CString(s):
                        //new ConstNode(s, TypedValue.DClass(String, s), e);
                        TScalar(TString);

                    case ConstExpr.CRegexp(re):
                        //new ConstNode(re, TypedValue.DClass(EReg, re), e);
                        TClass(EReg);

                    case ConstExpr.CCompiled(typedValue):
                        typedValue.type;
                }

            case Ve.ECol(column):
                if (schema != null) {
                    try schema.fieldType(column) catch (err: Dynamic) TNull(TAny);
                }
                else expected;

            case Ve.EList(values):
                TArray(TMono(null));

            case Ve.EVoid: TAny;
            
            default: expected;
        }
    }

    public function compileValueExpr(e: ValueExpr):ValueNode {
        return vnode( e );
    }

    /**
      compile type expression
     **/
    public function compileConcreteTypeExpr(e: TypeExpr):DataType {
        return switch e {
            case TEPath(path): switch ([path.pack, path.name, path.params]) {
                case [[], root, null]: switch (root) {
                    case 'Any'|'Dynamic': DataType.TAny;
                    case 'Bool'|'Boolean': DataType.TScalar(TBoolean);
                    case 'Float'|'Double'|'Number': DataType.TScalar(TDouble);
                    case 'Int'|'Integer': DataType.TScalar(TInteger);
                    case 'String': DataType.TScalar(TString);
                    case 'Date'|'Datetime': DataType.TScalar(TDate);
                    case 'Bytes'|'Bytearray'|'ByteArray'|'Binary': DataType.TScalar(TBytes);
                    case 'EReg'|'Regexp': DataType.TClass(EReg);
                    case other: throw new Error('Unknown type $other');
                }

                case [[], 'Null'|'Maybe', [t]]: DataType.TNull(compileConcreteTypeExpr(t));
                case [[], 'Array', [t]]: DataType.TArray(compileConcreteTypeExpr(t));
                case [[], 'Either'|'EitherType', [a, b]]: DataType.TUnion(compileConcreteTypeExpr(a), compileConcreteTypeExpr(b));
                case [pack, name, _]:
                    var id = pack.withAppend(name).join('.');
                    switch Type.resolveClass(id) {
                        case null:
                            //return DataType.TEnum(Type.resolveEnum( id ));
                            throw new Error('Type $id not found');

                        case cl: DataType.TClass( cl );
                    }
            }

            case TEAnon(fields):
                DataType.TAnon(
                    new CObjectType(fields.map(f -> new Property(f.name, compileConcreteTypeExpr(f.t))))
                );
            case TEResolved(type): type;
        }
    }

/* === Variables === */

    private var schema(default, null): Null<StructSchema> = null;
    private var context(default, null): Null<QueryInterp> = null;
}

enum TypingResult {
    Unknown;
    Concrete(type: ValType);
}
