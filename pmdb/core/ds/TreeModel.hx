package pmdb.core.ds;

import tannus.ds.Pair;
import haxe.ds.Option;

import tannus.math.TMath as Math;

import pmdb.core.Comparator;

import Slambda.fn;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using tannus.async.OptionTools;

@:forward
abstract TreeModel<K, V> (ITreeModel<K, V>) from ITreeModel<K, V> {
/* === Factory Methods === */

    public static function create<K, V>(compare:K->K->Int, ?equals:V->V->Bool):TreeModel<K, V> {
        return new OptTreeModel({compareKeys:compare, checkValueEquality:equals});
    }

    public static function of<K, V>(comp:Comparator<K>, eq:Equator<V>):TreeModel<K, V> {
        return create(comp.compare.bind(), eq.equals.bind());
    }
}

class TreeModelBase<K, V> implements ITreeModel<K, V> {
/* === Instance Methods === */

    public function compareKeys(x:K, y:K):Int {
        throw 'NotImplemented';
    }

    public function checkValueEquality(x:V, y:V):Bool {
        return x == y;
    }
}

class OptTreeModel<K, V> extends TreeModelBase<K, V> {
    /* Constructor Function */
    public function new(o: {compareKeys:K->K->Int, ?checkValueEquality:V->V->Bool}) {
        ck = o.compareKeys;
        cve = o.checkValueEquality;
    }

    override function compareKeys(x, y):Int {
        return ck(x, y);
    }

    override function checkValueEquality(x, y):Bool {
        return super.checkValueEquality(x, y) || (cve != null ? cve(x, y) : false);
    }

    var ck(default, null): K->K->Int;
    var cve(default, null): Null<V->V->Bool>;
}

interface ITreeModel<K, V> {
    function compareKeys(x:K, y:K):Int;
    function checkValueEquality(x:V, y:V):Bool;
}
