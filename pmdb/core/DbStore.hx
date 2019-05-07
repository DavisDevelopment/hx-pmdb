package pmdb.core;

import pmdb.async.Executor;
import pmdb.core.Store;

import pm.async.*;

class DbStore<Item> extends Store<Item> {
    public var name(default, null): String;
    public var db(default, null): Database;

    public function new(name, db, options) {
        super( options );

        this.name = name;
        this.db = db;
    }

    override function _execKey():String return name;
    @:access(pmdb.core.Database)
    override function _updatePromise(promise: Promise<Store<Item>>) {
        return cast (db.loadedStores[name] = cast promise);
    }

/*
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
*/
}
