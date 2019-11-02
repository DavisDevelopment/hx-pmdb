package pmdb.core.query;

import pmdb.ql.ast.Value.ValueExpr;
import pmdb.ql.ast.Value.ValueExprDef;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.ValueNode as Node;

import haxe.PosInfos;
import haxe.ds.Option;

using StringTools;
using pm.Strings;
using pm.Options;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;

@:forward
abstract Value (EValue) from EValue to EValue {
    public function isCompiled():Bool {
        return this.match(CompiledValue(_));
    }

    public function compile<T>(q: StoreQueryInterface<T>):Value {
        if (!isCompiled()) {
            return _compile(q, this);
        }
        return this;
    }

    public function getNode():Node {
        return switch this {
            case CompiledValue(node): node;
            default: throw 'Invalid call';
        }
    }

    @:access( pmdb.core.query.StoreQueryInterface )
    static function _compile<T>(q:StoreQueryInterface<T>, v:Value):Value {
        return switch v {
            case CompiledValue(node): CompiledValue(node);
            case StringValue(code): _compile(q, ValueExprValue(q.compileStringToValue(code)));
            case HScriptExprValue(expr): _compile(q, ValueExprValue(q.compileHsExprToValue(expr)));
            case ValueExprValue(expr): _compile(q, CompiledValue(q.compileValueExpr(expr)));
        }
    }

    @:from
    public static inline function fromString(s: String):Value {
        return StringValue( s );
    }

    @:from
    public static inline function fromHScriptExpr(e: hscript.Expr):Value {
        return HScriptExprValue( e );
    }

    @:from
    public static inline function fromValueExpr(s: ValueExpr):Value {
        return ValueExprValue( s );
    }

    @:from
    public static inline function fromNode(node: Node):Value {
        return CompiledValue( node );
    }
}

enum EValue {
    StringValue(value: String);
    HScriptExprValue(value: hscript.Expr);
    ValueExprValue(value: ValueExpr);

    CompiledValue(value: Node);
}
