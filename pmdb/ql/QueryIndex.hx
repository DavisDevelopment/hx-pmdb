package pmdb.ql;

import pmdb.ql.ast.BoundingValue;
import pmdb.core.Index;

class QueryIndex<K, T> {
    /* Constructor Function */
    public function new(idx, ?constraint: IndexConstraint<K, T>) {
        index = idx;
        filter = switch constraint {
            case null: ICNone;
            case _: constraint;
        }
    }

/* === Methods === */

    public function toString() {
        return 'QueryIndex(${index.fieldType.print()} ${index.fieldName}, $filter)';
    }

/* === Variables === */

    public var index: Index<K, T>;
    public var filter: IndexConstraint<K, T>;
}

enum IndexConstraint <Key, T> {
    ICNone;
    ICKey(key: Key);
    ICKeyList(keys: Array<Key>);
    ICKeyRange(?min:BoundingValue<Key>, ?max:BoundingValue<Key>);
}
