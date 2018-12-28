package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.QueryIndex;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.Index;
import pmdb.core.Store;

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

class ComparisonCheck extends BinaryCheck {
    /* Constructor Function */
    public function new(?comp:Null<Comparator<Dynamic>>, l, r, kind:ComparisonType, ?e, ?pos):Void {
        super(l, r, e, pos);

        this.comparator = comp;
        this.comparison = kind;
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
        return Type.createInstance(Type.getClass(this), [untyped comparator, left.clone(), right.clone(), expr, position]);
        //return new ComparisonCheck(comparator, left, right, expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep:Bool=false):QueryNode {
        return Type.createInstance(Type.getClass(this), [untyped 
            comparator,
            safeNode(fn(left), ValueNode),
            safeNode(fn(right), ValueNode),
            expr, position
        ]);
    }

    override function eval(ctx: QueryInterp):Bool {
        var l = left.eval( ctx ),
        r = right.eval( ctx );
        return compCheck(l, r, compare(l, r));
    }

    override function compile():QueryInterp->Bool {
        return ((compare, checkDiff, getLeft, getRight) -> 
          ((c: QueryInterp) -> checkDiff(compare(getLeft(c.document, c.parameters), getRight(c.document, c.parameters))))
        )(
          compileComparison(),
          compileCompCheck(),
          left.compile(),
          right.compile()
        );
    }

    public function compileComparison():Dynamic->Dynamic->Int {
        return (c -> (a, b) -> c.compare(a, b))(ecomp());
    }

    public function compileCompCheck():Int->Bool {
        return switch comparison {
            case Gt: rel -> rel > 0;
            case Gte: rel -> rel >= 0;
            case Lt: rel -> rel < 0;
            case Lte: rel -> rel <= 0;
            case Eq: rel -> rel == 0;
        }
    }

    public function compCheck(a:Dynamic, b:Dynamic, rel:Int):Bool {
        return switch comparison {
            case Gt: rel > 0;
            case Gte: rel >= 0;
            case Lt: rel < 0;
            case Lte: rel <= 0;
            case Eq: rel == 0;
        }
    }

    /**
      compare the two given values numerically
     **/
    public inline function compare(a:Dynamic, b:Dynamic):Int {
        if (comparator == null) {
            comparator = Comparator.cany();
        }

        return comparator.compare(a, b);
    }

    inline function ecomp<T>():Comparator<T> {
        return
            if (comparator != null)
                cast comparator;
            else
                cast comparator = Comparator.cany();
    }

    //override function getIndexToUse(store: Store<Dynamic>) {
        //if (left.hasLabel('column')) {
            //var col = (left.label('column'):String);
            //if (store.indexes.exists( col )) {
                //var qi = new QueryIndex(store.index(col), null);

                //if (right.hasLabel('const')) {
                    //qi.filter = ICKey(right.label('const'));
                //}

                //return qi;
            //}
        //}
        //return null;
    //}

/* === Variables === */

    public var comparator(default, null): Null<Comparator<Dynamic>>;
    public var comparison(default, null): ComparisonType;
}

enum abstract ComparisonType (String) from String to String {
    var Lt = 'lt';
    var Lte = 'lte';
    var Eq = 'eq';
    var Gt = 'gt';
    var Gte = 'gte';
}
