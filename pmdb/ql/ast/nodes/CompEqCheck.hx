package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.Index;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class CompEqCheck extends BinaryCheck {
    /* Constructor Function */
    public function new(?comp:Null<Comparator<Dynamic>>, ?eq:Equator<Dynamic>, l, r, ?e, ?pos):Void {
        super(l, r, e, pos);

        this.comparator = comp;
        this.equator = eq;
    }

/* === Methods === */

    override function attachInterp(c: QueryInterp) {
        super.attachInterp( c );
        left.attachInterp( c );
        right.attachInterp( c );

        comparator = (try left.type.getTypedComparator() catch (e: Dynamic) right.type.getTypedComparator());

        if (left.hasLabel('index')) {
            var idx = cast(left.label('index'), Index<Dynamic, Dynamic>);

            addLabel('index', idx);
        }
    }

    override function clone():Check {
        //return new CompEqCheck(comparator, equator, left, right, expr, position);
        return Type.createInstance(Type.getClass(this), [untyped comparator, equator, left.clone(), right.clone(), expr, position]);
    }

    override function map(fn: QueryNode->QueryNode, deep:Bool=false):QueryNode {
        return Type.createInstance(Type.getClass(this), [untyped 
            comparator,
            equator,
            safeNode(fn(left), ValueNode),
            safeNode(fn(right), ValueNode),
            expr, position
        ]);
    }

    /**
      evaluate [this] Node
     **/
    override function eval(ctx: QueryInterp):Bool {
        var l = left.eval( ctx ),
        r = right.eval( ctx );
        return (compCheck(l, r, compare(l, r)) || eqCheck(l, r));
    }

    /**
      compile [this] Node into a lambda
     **/
    override function compile():QueryInterp->Bool {
        return (function(eq, comp, lv, rv, ctx:QueryInterp):Bool {
            var l = lv(ctx), r = rv(ctx);
            return (comp(l, r) || eq(l, r));
        })
        .bind(eqCheck.bind(_, _), _, left.compile(), right.compile(), _)
        .bind((function(comp:Dynamic->Dynamic->Int, check:Dynamic->Dynamic->Int->Bool) {
            return (a:Dynamic, b:Dynamic) -> check(a, b, comp(a, b));
        })(compare.bind(_, _), compCheck.bind(_, _, _)), _);
    }

    public function eqCheck(a:Dynamic, b:Dynamic):Bool {
        return
            if (equator == null)
                Arch.areThingsEqual(a, b);
            else
                equator.equals(a, b);
    }

    public function compCheck(a:Dynamic, b:Dynamic, rel:Int):Bool {
        return (rel == 0);
    }

    /**
      compare the two given values numerically
     **/
    public function compare(a:Dynamic, b:Dynamic):Int {
        return 
            if (comparator != null)
                comparator.compare(a, b);
            else
                Arch.compareThings(a, b);
    }

/* === Variables === */

    public var comparator(default, null): Null<Comparator<Dynamic>>;
    public var equator(default, null): Null<Equator<Dynamic>>;
}
