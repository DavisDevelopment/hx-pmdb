package pmdb.storage;

import pmdb.storage.IStorage;

import haxe.io.*;

import pm.async.*;
import pm.async.impl.*;
import pm.Outcome;

using pm.Functions;

class AsyncStorageAdapter implements IStorage {
    public var storage(default, null): IStorageSync;
    
    function new(s) {
        storage = s;
    }

    public static function make(s: IStorageSync) {
        return new AsyncStorageAdapter( s );
    }

    public function exists(path: String):Promise<Bool> {
        return Promise.resolve(storage.exists( path ));
    }
    public function size(path:String):Promise<Int> {
        return Promise.resolve(storage.size(path));
    }

    public function rename(n1:String, n2:String):Promise<Bool> {
        return doo(function() {
            storage.rename(n1, n2);
        });
    }

    public function writeFileBinary(path:String, data:Bytes):Promise<Bool> {
        return doo(function() {
            storage.writeFileBinary(path, data);
        });
    }

    public function readFileBinary(path: String):Promise<Bytes> {
        return prom(storage.readFileBinary.bind(path));
    }

    public function appendFileBinary(path:String, data:Bytes):Promise<Bool> {
        return doo(function() {
            storage.appendFileBinary(path, data);
        });
    }

     public function writeFile(path:String, data:String):Promise<Bool> {
        return doo(function() {
            storage.writeFile(path, data);
        });
    }

    public function readFile(path: String):Promise<String> {
        return prom(storage.readFile.bind(path));
    }

    public function appendFile(path:String, data:String):Promise<Bool> {
        return doo(function() {
            storage.appendFile(path, data);
        });
    }

    public function unlink(path:String):Promise<Bool> {
        return doo(() -> storage.unlink(path));
    }

    public function mkdirp(path: String):Promise<Bool> {
        return doo(storage.mkdirp.bind(path));
    }

    public function flushToStorage(options: {filename:String, ?isDir:Bool}):Promise<Bool> {
        return doo(storage.flushToStorage.bind(options));
    }

    public function ensureDatafileIntegrity(path: String):Promise<Bool> {
        return doo(storage.ensureDatafileIntegrity.bind(path));
    }

    public function crashSafeWriteFile(path:String, data:Bytes):Promise<Bool> {
        return doo(storage.crashSafeWriteFile.bind(path, data));
    }

    public function ensureFileDoesntExist(path: String):Promise<Bool> {
        return doo(storage.ensureFileDoesntExist.bind( path ));
    }

	static function doo2(f:Void->Void, ?config:{forceAsync:Bool, discardException:Bool, safe:Bool}) {
        if (config == null) {
            config = {
                forceAsync: false,
                discardException: false,
                safe: true
            };
        }
        /*
        // var outcome: Outcome<Bool, Dynamic>, ctor:(o: Outcome<Bool, Dynamic>)->Promise<Bool>;
        // switch [config.forceAsync, config.safe] {
        //     case [true, false]: ctor = o -> {
        //         Promise.asyncNiladUnsafe(function(dun) {
        //             haxe.Timer.delay(function() {
        //                 trace('pre:doo/callback');
        //                 dun();
        //             }, 2);
        //         })
        //         .inspect()
        //         .transform(o -> switch o {
        //             case Success(_): Success(true);
        //             case Failure(x) if (config.discardException): Success(false);
        //             case Failure(e): Failure(e);
        //         });
        //     };

        //     case [true, true]:
        //         ctor=o->Promise.async(function(resolve) {
        //             Defer.defer(function() {
        //                 try {
        //                     fn();
        //                     resolve(Success(true));
        //                 }
        //                 catch (e: Dynamic) {
        //                     resolve(Failure(e));
        //                 }
        //             });
        //         });

        //     // case [false, _]:
        //     //     var nilad = fn;
        //     //     var fn:Void->Bool = function() {
        //     //         nilad();
        //     //         return true;
        //     //     }
        //     //     Promise.sync()

        //     default:

        // }
        */
        throw 0;
    }

    //TODO
    static function doo(fn:Void->Void, ?config:{forceAsync:Bool, discardException:Bool, safe:Bool}):Promise<Bool> {
        var bfn = nn(config)&&config.safe ? (() -> try {fn();true;} catch (err: Dynamic) false) : (() -> {fn(); true;});
        // return Promise.sync()
        return Promise.async(function(res) {
            // throw 'FixMe';
            try {
                fn();
                res(Success(true));
            }
            catch (e: Dynamic) {
                res(Failure(e));
            }
        });
    }

    static function mk<T>(ctor:(cb:(o:Outcome<T,Dynamic>)->Void)->Void, ?options):Promise<T> {
        if (options == null) options = {
            safe: false,
            forceAsync: true
        };
        if (options.forceAsync) {
            var tmp = ctor;
            ctor = (cb) -> {
                Defer.defer(function() {
                    tmp(cb.wrap(function(_, o:Outcome<T, Dynamic>) {
                        trace('${o}');
                        _.call(o);
                    }));
                });
            };
        }
        var promise = Promise.async(ctor);
        $type(promise);
        promise.validate(true);
        return promise;
    }

    static function prom<T>(fn: Void -> T, ?config:{}):Promise<T> {
        return Promise.async(function(done) {
            done(try Success(fn()) catch (e: Dynamic) Failure(e));
        });
    }
}
