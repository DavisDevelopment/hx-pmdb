package pmdb.storage;

// package pmdb.storage;

import haxe.Constraints.Function;
import pmdb.Globals.log;

import pmdb.storage.IStorage;
import haxe.io.*;
import pm.async.*;
import pm.async.Callback;
import pm.async.Promise;
import pm.Outcome;

@:generic
class AsyncFromCallbackStorageAdapter<StorageImpl:ICbStorage> implements IStorage {
    public var storage: StorageImpl;
    public function new(s) {
        this.storage = s;
    }

    private function convert<T>(f:Cb<T>->Void, ?pos:haxe.PosInfos):Promise<T> {
        var exec:(Outcome<T,Dynamic>->Void)->Void = function(done) {
            f(function(error:Null<Dynamic>, result:T) {
                trace(error, result);
                done(nn(error)?Failure(error):Success(result));
            });
        }
        trace('wrapping .${pos.methodName} call...');
        return Promise.async(exec).failAfter(1000, 'method call timed out');
    }

    private function wrapConvert<Func:Function>(method:Func, ?pos:haxe.PosInfos):Dynamic {
        var varArgs = function(args:Array<Dynamic>):Promise<Dynamic> {
            trace( args );
            var innerArgs = args.copy();
            var trigger = Promise.trigger();
            var callback:Cb<Dynamic> = function(outcome: Outcome<Dynamic, Dynamic>) {
                trace('callback called with $outcome');
                trigger.trigger(outcome);
            };
            innerArgs.push(callback);
            var promise:Promise<Dynamic> = Promise.createFromTrigger(trigger);
            Reflect.callMethod(null, method, innerArgs);
            return promise;
        }
        return Reflect.makeVarArgs(varArgs);
    }

    private function mkp<T>(f: (done: Outcome<T, Dynamic>->Void)->Void):Promise<T> {
        return Promise.create(f);
    }

    /**
      [TODO] refactor all methods of this class in the same way that this one has been refactored
     **/
    public function exists(path: String):Promise<Bool> {
        return Promise.create(done -> storage.exists(path, function(o: Outcome<Bool, Dynamic>) {
            return done(o);
        }));
    }

	public function size(path: String):Promise<Int> {
        return convert(f -> storage.size(path, f));
    }

	public function rename(oldPath:String, newPath:String):Promise<Bool> {
        return convert(f->storage.rename(oldPath, newPath, f));
    }

	public function writeFileBinary(path:String, data:Bytes):Promise<Bool> {
		// return convert(f -> storage.writeFileBinary(path, data, f));
        return mkp(done -> storage.writeFileBinary(path, data, done.bind()));
    }

	public function readFileBinary(path:String):Promise<Bytes> {
		// return convert(f -> storage.readFileBinary(path, f)).inspect();
        return mkp(done -> storage.readFileBinary(path, done.bind()));
    }

	public function appendFileBinary(path:String, data:Bytes):Promise<Bool> {
		// return convert(f -> storage.appendFileBinary(path, data, f));
        return mkp(done -> storage.appendFileBinary(path, data, done.bind()));
    }

	public function writeFile(path:String, data:String):Promise<Bool> {
		// return convert(f -> storage.writeFile(path, data, f));
		return mkp(done -> storage.writeFile(path, data, done.bind()));
    }

	public function readFile(path:String):Promise<String> {
		// return convert(f -> storage.readFile(path, f));
		return mkp(done -> storage.readFile(path, done.bind()));
    }

	public function appendFile(path:String, data:String):Promise<Bool> {
		// return convert(f -> storage.appendFile(path, data, f));
		return mkp(done -> storage.appendFile(path, data, done.bind()));
    }

	public function unlink(path:String):Promise<Bool> {
		// return convert(f -> storage.unlink(path, f));
		return mkp(done -> storage.unlink(path, done.bind()));
    }

    public function mkdir(path:String):Promise<Bool> {
        // return convert(f -> storage.mkdir(path, f));
		return mkp(done -> storage.mkdir(path, done.bind()));
    }

	public function mkdirp(path:String):Promise<Bool> {
		// return convert(f -> storage.mkdirp(path, f));
		return mkp(done -> storage.mkdirp(path, done.bind()));
    }

	public function ensureFileDoesntExist(path:String):Promise<Bool> {
		return convert(f -> storage.ensureFileDoesntExist(path, f));
    }

	public function flushToStorage(options:{filename:String, ?isDir:Bool}):Promise<Bool> {
		return convert(f -> storage.flushToStorage(options, f));
    }

	public function crashSafeWriteFile(path:String, data:Bytes):Promise<Bool> {
		return convert(f -> storage.crashSafeWriteFile(path, data, f));
    }

	public function ensureDatafileIntegrity(filename:String):Promise<Bool> {
		return convert(f -> storage.ensureDatafileIntegrity(filename, f));
    }
}