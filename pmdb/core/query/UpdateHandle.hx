package pmdb.core.query;

import pmdb.core.ds.HashKey;
import pmdb.ql.QueryInterp.UpdateLog;
import pmdb.core.Store;

import pmdb.core.Assert.assert;

class UpdateHandle<T> {
    public var key(default, null): Int = HashKey.next();
    public var store(default, null): Null<Store<T>>;
    public var logs(default, null): Null<Array<UpdateLog<T>>>;
    private var disposed: Bool = false;

    public inline function new(store, logs:Array<UpdateLog<T>>) {
        this.logs = logs.copy();
        this.store = store;
    }

    public inline function dispose() {
        assert(!disposed, 'Cannot dispose of UpdateHandle multiple times');
        store = null;
        logs = null;
        disposed = true;
    }

    public function rollback() {
        store.pluralUpdateIndexes(logs.map(u -> {pre:u.post, post:u.pre}));
    }
}
