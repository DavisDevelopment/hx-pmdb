package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.DocumentSchema;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;

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
using pmdb.ql.ast.Predicates;

class RegexpCheck extends BinaryCheck {
    /* Constructor Function */
    public function new(l, r, ?e, ?pos):Void {
        super(l, r, e, pos);

        this.pattern = right.label("const");
    }

/* === Methods === */

    override function init() {
        if ((right is ConstNode)) {
            this.pattern = switch cast(right, ConstNode).typed {
                case DClass(EReg, (_ : EReg) => re): cast(re, EReg);
                case DClass(String, (_ : String) => re): new EReg(re, '');
                case other: 
                    throw new Error('Invalid Regexp pattern ${other}');
            }
        }
    }

    override function attachInterp(c: QueryInterp) {
        left.attachInterp( c );
        right.attachInterp( c );

        this.pattern = right.label('const');
    }

    override function clone():Check {
        return new RegexpCheck(left.clone(), right.clone(), expr, position);
    }

    override function map(fn:QueryNode->QueryNode, deep=false):QueryNode {
        return new RegexpCheck(cast(fn(left), ValueNode), cast(fn(right), ValueNode), expr, position);
    }

    override function eval(ctx: QueryInterp):Bool {
        var l:Dynamic = left.eval( ctx ),
        r:Dynamic = right.eval( ctx );

        return match((pattern != null ? pattern : asEReg( r )), l);
    }

    override function compile():QueryInterp->Bool {
        return (function(val:QueryInterp->Dynamic, re:EReg, match:EReg->Dynamic->Bool) {
            return (c: QueryInterp) -> match(re, val( c ));
        })(left.compile(), pattern, compileMatch());
    }

    public function compileMatch():EReg->Dynamic->Bool {
        return (function(re:EReg, val:Dynamic):Bool {
            if (Arch.isArray( val ))
                return match_arr(re, cast val);
            else
                return match_str(re, '' + val);
        });
    }

    public function match(re:EReg, val:Dynamic):Bool {
        if (Arch.isArray( val )) {
            return match_arr(re, cast(val, Array<Dynamic>));
        }
        else {
            return match_str(re, Std.string( val ));
        }
    }

    public inline function match_str(re:EReg, s:String):Bool {
        return re.match( s );
    }

    public function match_arr(re:EReg, a:Array<Dynamic>):Bool {
        for (x in a) {
            if (match_str(re, Std.string(x))) {
                return true;
            }
        }
        return false;
    }

    public function match_itr(re:EReg, seq:Iterable<Dynamic>):Bool {
        for (x in seq) {
            if (match(re, x)) {
                return true;
            }
        }
        return false;
    }

    private function asEReg(x: Dynamic):EReg {
        if (Arch.isRegExp( x )) {
            return cast(x, EReg);
        }
        else if (Arch.isString( x )) {
            return Arch.compileRegexp( x );
        }
        else {
            throw new Error('Cannot coerce $x to a RegExp');
        }
    }

/* === Variables === */

    //public var equator(default, null): Null<Equator<Dynamic>>;
    public var pattern(default, null): Null<EReg>;
}
