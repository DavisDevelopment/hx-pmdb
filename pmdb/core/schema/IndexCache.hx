package pmdb.core.schema;

import pmdb.core.StructSchema;
import pmdb.core.ds.index.IIndex;
import pmdb.core.schema.Types;

import pm.map.OrderedDictionary;

using pm.Arrays;
using pm.Iterators;
using pm.Functions;

class IndexCache<Item> {
    public var indexes: OrderedDictionary<IndexType, IIndex<Any, Item>>;

    public function new() {
        this.indexes = new OrderedDictionary();
    }
}