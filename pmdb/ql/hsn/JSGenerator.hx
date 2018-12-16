package pmdb.ql.hsn;

import tannus.ds.Set;

import hscript.Expr;
import hscript.Parser;
//import hscript.Interp;

import haxe.Template;
import haxe.Json;
import haxe.io.BytesBuffer;
import haxe.Constraints.Function;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.aif.UpdateOperation;

import pmdb.core.Error;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class JSGenerator {
    /* Constructor Function */
    public function new() {
        //super();
        ctx = new JSGenCtx();
        keywords = new Set();
        keywords.pushMany([
            "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
            "debugger", "default", "delete", "do", "double", "else", "enum", "export", "extends", "false", "final",
            "finally", "float", "for", "function", "goto", "if", "implements", "import", "in", "instanceof", "int",
            "interface", "long", "native", "new", "null", "package", "private", "protected",
            "public", "return", "short", "static", "super", "switch", "synchronized", "this", "throw", "throws",
            "transient", "true", "try", "typeof", "var", "void", "volatile", "while", "with",
            "arguments", "break", "case", "catch", "class", "const", "continue",
            "debugger", "default", "delete", "do", "else", "enum", "eval", "export", "extends", "false",
            "finally", "for", "function", "if", "implements", "import", "in", "instanceof",
            "interface", "let", "new", "null", "package", "private", "protected",
            "public", "return", "static", "super", "switch", "this", "throw",
            "true", "try", "typeof", "var", "void", "while", "with", "yield"
        ]);
    }

/* === Methods === */

    public function generateExpr(e: Expr):String {
        return switch e {
            case EConst(c): generateConstant( c );
            case EIdent(v): generateIdent( v );
        }
    }

    public function generateIdent(n: String):String {
        return n;
    }

    public function generateVar(n:String, t:Null<CType>, e:Expr):String {
        
    }

    public function generateConstant(c: Expr.Const):String {
        return switch c {
            case Const.CFloat(n): Std.string( n );
            case Const.CInt(n): Std.string( n );
            case Const.CString(s): Json.stringify( s );
        }
    }

/* === Variables === */

    public var keywords: Set<String>;

    private var ctx: JSGenCtx;
}

class JSGenCtx {
    /* Constructor Function */
    public function new(?parent) {
        //initialize variables
        this.parentCtx = parent;
        declared = new Map();
        accessors = new Map();
    }

/* === Instance Methods === */

    public inline function descend():JSGenCtx {
        return new JSGenCtx( this );
    }

/* === Instance Fields === */

    public var parentCtx: Null<JSGenCtx> = null;
    public var es6: Bool = true;
    public var declared(default, null): Map<String, Null<CType>>;
    public var accessors(default, null): Map<String, Expr->String>;
}
