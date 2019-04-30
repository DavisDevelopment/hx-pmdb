package pmdb.core;

import pmdb.async.Executor;
import pmdb.core.Store;

import pm.async.*;

class DbStore<Item> extends Store<Item> {
    public var name(default, null): String;
    public function new(name, options) {
        super( options );

        this.name = name;
    }

    override function _compact():Promise<Store<Item>> {
        var fp = (() -> persistence.persistCachedDataStore( this ));
        return new Promise<Promise<Store<Item>>>(function(accept) {
            executor.exec(name, fp, function(prom: Promise<Store<Item>>) {
                accept( prom );
            });
        });
    }

    override function _load():Promise<Store<Item>> {
        var fp = (() -> persistence.loadDataStore( this ));
        return new Promise<Promise<Store<Item>>>(function(accept) {
            executor.exec(name, fp, function(prom: Promise<Store<Item>>) {
                accept( prom );
            });
        });
    }
}
