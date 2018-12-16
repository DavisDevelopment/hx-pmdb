package pmdb.core.ds.map;

import haxe.Constraints.IMap;
import haxe.ds.BalancedTree;

@:forward
abstract Hash<K, V> (HashType<K, V>) from HashType<K, V> to HashType<K, V> {
    /* Constructor Function */
    public function new(cmp: Comparator<K>) {
        this = new HashType( cmp );
    }

    @:arrayAccess
    public inline function get(key: K):Null<V> return this.get( key );

    @:arrayAccess
    public inline function set(key:K, value:V):V {
        this.set(key, value);
        return value;
    }

    @:from
    public static inline function fromComparator<K, V>(c: Comparator<K>):Hash<K, V> {
        return new Hash<K, V>( c );
    }

    public static var type(default, null) = HashType;
}

class HashType<K, V> extends BalancedTree<K, V> {
    public function new(c) {
        super();

        comparator = c;
    }

    override function copy() {
        var hash:Hash<K, V> = new Hash( comparator );
        for (key in keys()) {
            hash.set(key, get(key));
        }
        return hash;
    }

    override function compare(left:K, right:K):Int {
        return comparator.compare(left, right);
    }

    private var comparator(default, null): Comparator<K>;
}
