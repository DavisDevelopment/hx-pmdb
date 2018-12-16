package pmdb.ql.ast;

import tannus.ds.Lazy;
import tannus.ds.Ref;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSystemError;
import pmdb.ql.ast.nodes.QueryNode;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.core.Assert.*;
import pmdb.Macros.*;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class ASTError<Node> extends Error {
    /* Constructor Function */
    public function new(node:Lazy<Node>, ?msg, ?pos) {
        super(msg, pos);

        this.name = 'ASTError';
        this._node = node;
    }

/* === Methods === */

    override function defaultMessage() {
        return '';
    }

/* === Properties === */

    public var node(get, never): Node;
    inline function get_node():Node return _node.get();

/* === Variables === */

    private var _node(default, null): Lazy<Node>;
}

class PmQlError<Expression> extends ASTError<Expression> {
    public function new(expr, ?msg, ?pos) {
        super(expr, msg, pos);
    }
}

class SyntaxError<T> extends PmQlError<T> {
    public function new(badSyntax, ?msg, ?pos):Void {
        super(badSyntax, msg, pos);
        name = 'SyntaxError';
    }

    override function defaultMessage():String {
        return super.defaultMessage();
    }

    override function toString():String {
        return [
            super.toString(),
            prettyPrintStackTrace()
        ].join('\n');
    }
}

class Unexpected<T> extends SyntaxError<T> {
    override function defaultMessage():String {
        return 'Unexpected $node';
    }
}

class QueryTreeError<Node:QueryNode> extends PmQlError<Node> {
    /* Constructor Function */
    public function new(node, ?msg, ?pos) {
        super(node, msg, pos);
        name = 'QueryTreeError';
    }
}

enum QueryTreeErrorType {
    Runtime;
    Compilation(type: QueryCompilerErrorType);
    Custom(err: Dynamic);
}

enum QueryCompilerErrorType {
    Typing;
    InterpreterUnlinked;
    StoreUnlinked;
}

class QueryExeption<Node:QueryNode> extends QueryTreeError<Node> {
    /* Constructor Function */
    public function new(node, code, ?msg, ?pos) {
        super(node, msg, pos);

        this.code = code;
        name = 'Query${code.getName()}Exception';
    }

/* === Variables === */

    public var code(default, null): QueryTreeErrorType;
}
