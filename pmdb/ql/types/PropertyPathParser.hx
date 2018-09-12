package pmdb.ql.types;

import tannus.io.Byte;
import tannus.io.ByteArray;
import tannus.io.Char;
import tannus.io.RegEx;

// why does tannus.ds.* have so many useful types with four-letter names?
import tannus.ds.Anon;
import tannus.ds.Dict;
import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Uuid;
import tannus.ds.Ref ; // :c

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.io.Input;
import hscript.Expr.Const;

import pmdb.ql.types.PropertyPath;

import tannus.math.TMath as M;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

class PropertyPathParser {
    /* Constructor Function */
    public function new() {
        text = null;
        expr = null;
    }

/* === Methods === */

    public static function runString(path: String):PropertyPathExpr {
        return (new PropertyPathParser().parseString( path ));
    }

    public function parseString(s: String):PropertyPathExpr {
        s = s.trim();
        if (s.length == 0)
            return null;
        text = s;
        expr = null;
        
        var parts = new Array();
        splitString(text, parts);
        return (!parts.empty() ? consumeParts(parts) : null);
    }

    static function splitString(s:String, acc:Array<String>):Void {
        switch s.indexOf('.') {
            case -1:
                acc.push( s );

            case end:
                acc.push(s.slice(0, end));
                return splitString(s.slice(end + 1), acc);
        }
    }

    inline function isSpecialPart(s: String):Bool {
        return false;
    }

    function consumeParts(parts: Array<String>):Null<PropertyPathExpr> {
        if (parts.empty()) return null;
        
        for (part in parts) {
            expr = readPart(part, expr);
        }

        return expr;
    }
    function consumeParts_(a:Array<String>):Null<PropertyPathExpr> {
        return switch (a.shift()) {
            case null: null;
            case part: readPart(part, (switch a.length {
                case 0: null;
                case _: consumeParts( a );
            }));
        }
        //return readPart(a[0], if (a.length >= 1) consumeParts(a.slice(1)) else null);
    }

    function readPart(s:String, ?e:PropertyPathExpr):PropertyPathExpr {
        if (s.length == 0) {
            throw 'Unexpected <eof>';
        }
        
        return (e != null ? Access(e, readPropertyLeaf(s)) : Property(readPropertyLeaf(s)));
    }

    function readPropertyLeaf(s: String):Null<PropertyLeaf> {
        if (s.length == 0) 
            return null;
        if (quoted_pattern.match( s ))
            return PLiteral(readConst(quoted_pattern.matched( 2 ), true));
        return PLiteral(readConst(s, false));
    }

    function readConst(s:String, forceString:Bool):Const {
        return
            if (!forceString && s.isNumeric()) CInt(Std.parseInt(s))
            else CString(s);
    }

/* === Variables === */

    var text: Null<String>;
    var expr: Null<PropertyPathExpr>;

    // ~//;
    static var quoted_pattern:EReg = ~/^("|')(.*)\1$/gm;
}
