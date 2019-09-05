package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.*;
import pmdb.ql.ast.nodes.Check;
import pmdb.ql.QueryIndex;

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

/**
  checks that [right] can be said to contain/include [left]
 **/
class InCheck extends BinaryCheck {
    /* Constructor Function */
    public function new(?eq:Equator<Dynamic>, l, r, ?e, ?pos) {
        super(l, r, e, pos);

        this.equator = eq;

        //computeTypeState();
    }

/* === Methods === */

    /**
      determine internal state regarding operand-types
     **/
    override function computeTypeInfo() {
        super.computeTypeInfo();

        computeContainerState();
        computeValueState();
    }

    function computeValueState() {
        if ((left is ConstNode)) {
            var cr = cast(left, ConstNode);
            valueConst = cr.value;
        }
        else if (left.hasLabel('const')) {
            valueConst = left.label('const');
        }
        else {
            valueConst = null;
        }

        if (valueConst != null) {
            valueType = valueConst.dataTypeOf();
        }
        else {
            valueType = left.type;
        }
    }

    inline function computeContainerState() {
        if ((right is ConstNode)) {
            var cr = cast(right, ConstNode);
            if (!cr.type.match(TAny)) {
                containerType = cr.type;
            }
            containerConst = cr.value;
        }
        else if ((right is ListNode) && right.hasLabel('const')) {
            var cr = cast(right, ListNode);
            if (cr.constValues != null) {
                containerType = cr.type;
                containerConst = cr.constValues;
            }
        }
        else if (right.hasLabel('const')) {
            containerConst = right.label('const');
            containerType = containerConst.dataTypeOf();
        }
        else {
            containerConst = null;
            containerType = null;
        }
    }

    /**
      create and return a deep-copy of [this]
     **/
    override function clone():Check {
        return new InCheck(equator, left.clone(), right.clone(), expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new InCheck(equator, safeNode(fn(left), ValueNode), safeNode(fn(right), ValueNode), expr, position);
    }

    /**
      evaluate [this] Check
      TODO needs SEVERE optimization
     **/
    override function eval(ctx: QueryInterp):Bool {
        inline function tv(t:Null<DataType>, v:Null<Dynamic>):Null<{t:DataType, v:Dynamic}> {
            return switch [t, v] {
                case [null, null]: null;
                case [null, _]: {v:v, t:v.dataTypeOf()};
                case [_, _]: {v:v, t:t};
            }
        }

        switch ([tv(containerType, containerConst), tv(valueType, valueConst)]) {
            case [null, null]:
                return full_eval( ctx );

            //case [[TScalar(TString), (_ : String)=>text], [null, null]]:
            case [{t:TScalar(TString), v:(_:String)=>text}, null]:
                return in_str(left.eval( ctx ), text);

            //case [[TArray(elemType), (_ : Array<Dynamic>)=>array], [null|TAny, null]]:
            case [{t:TArray(elemType), v:(_ : Array<Dynamic>)=>array}, {t:null|TAny, v:null}|null]:
                return in_arr(left.eval(ctx), array);

            //case [[TArray(elemType), (_ : Array<Dynamic>)=>array], [_, null]]:
            case [{t:TArray(elemType), v:(_ : Array<Dynamic>)=>array}, {t:_, v:null}]:
                return elemType.unify(valueType) && in_arr(left.eval(ctx), array);

            default:
                return full_eval( ctx );
        }
    }

    public inline function full_eval(ctx: QueryInterp):Bool {
        var container:Dynamic = right.eval( ctx );
        var value:Dynamic = this.left.eval( ctx );

        if (Arch.isArray( container )) {
            return in_arr(value, cast(container, Array<Dynamic>));
        }
        else if (Arch.isString( container )) {
            return in_str(value, cast(container, String));
        }
        else if (Arch.isIterable( container )) {
            return in_itr(value, cast container);
        }
        else if (Arch.isObject( container )) {
            return in_object_safe(value, cast container);
        }
        else {
            return false;
        }
    }

    public inline function in_str(val:Dynamic, str:String):Bool {
        return str.has(Std.string( val ));
    }

    public function in_object_safe(val:Dynamic, o:Object<Dynamic>):Bool {
        if (Arch.isString( val )) {
            var sval:String = cast(val, String);
            for (key in o.keys()) {
                if (check(sval, key)) {
                    return true;
                }
            }
            return false;
        }
        else return false;
    }

    public function in_object(val:String, o:Object<Dynamic>):Bool {
        for (key in o.keys()) {
            if (check(val, key)) {
                return true;
            }
        }
        return false;
    }

    public function in_arr(val:Dynamic, arr:Array<Dynamic>):Bool {
        for (x in arr)
            if (check(val, x))
                return true;
        return false;
    }

    public function in_itr(left:Dynamic, seq:Iterable<Dynamic>):Bool {
        for (right in seq) {
            if (check(left, right)) {
                return true;
            }
        }
        return false;
    }

    public function check(l:Dynamic, r:Dynamic):Bool {
        if (equator != null) {
            return equator.equals(l, r);
        }
        else {
            return Arch.areThingsEqual(l, r);
        }
    }

    override function compile():QueryInterp->Bool {
        return ((function(check, left, right) {
            return (function(c: QueryInterp):Bool {
                return check(left(c.document, c.parameters), right(c.document, c.parameters));
            });
        })(
          compileIterableCheck(compileCheck()),
          left.compile(),
          right.compile()
        ));
    }

    function compileCheck():Dynamic->Dynamic->Bool {
        if (equator != null) {
            return (a, b) -> equator.equals(a, b);
        }
        else {
            return (a, b) -> Arch.areThingsEqual(a, b);
        }
    }

    function compileIterableCheck(check: Dynamic->Dynamic->Bool):Dynamic->Iterable<Dynamic>->Bool {
        return (function(value:Dynamic, container:Iterable<Dynamic>):Bool {
            for (rv in container) {
                if (check(value, rv)) {
                    return true;
                }
            }
            return false;
        });
    }

    function compileArrayCheck(check: Dynamic->Dynamic->Bool):Dynamic->Array<Dynamic>->Bool {
        return (function(value:Dynamic, container:Array<Dynamic>):Bool {
            for (rv in container) {
                if (check(value, rv)) {
                    return true;
                }
            }
            return false;
        });
    }

    override function getIndexToUse(store: Store<Dynamic>) {
        if (left.hasLabel('column')) {
            var col = (left.label('column'):String);
            if (store.indexes.exists( col )) {
                var qi = new QueryIndex(store.index(col), null);

                if (right.hasLabel('const')) {
                    qi.filter = ICKeyList(cast(right.label('const'), Array<Dynamic>));
                }

                return qi;
            }
        }
        return null;
    }

    override function getExpr() {
        return PredicateExpr.POpIn(left.getExpr(), right.getExpr());
    }

/* === Variables === */

    public var equator(default, null): Null<Equator<Dynamic>> = null;

    public var containerConst(default, null): Null<Dynamic> = null;
    public var containerType(default, null): Null<DataType> = null;
    public var valueConst(default, null): Null<Dynamic> = null;
    public var valueType(default, null): Null<DataType> = null;
}
