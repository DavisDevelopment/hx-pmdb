package pmdb.storage;

import pm.async.Async.VoidAsyncs;
import pm.Lazy;
import pm.Outcome;
import pm.async.*;
import haxe.ds.Option;
using pm.Options;
using StringTools;
using pm.Strings;
// using haxe.io.Path;
using pm.Functions;
using pman.sys.path.Path;
using pman.sys.path.PathStrings;

import haxe.io.Bytes;
import haxe.PosInfos;

/**
  mixin module which implements some high-level methods of IStorage abstractly, as well as providing other general utility functions
 **/
class IStorageMethods {

    public static function mkdirp(storage:IStorage, path:String):Promise<Bool> {
        if (path == "") return false;

        return Promise.reject(new pm.Error('Eat my ass'));
    }

    /**
      [TODO] nothing
     **/
    private static function isFileOrDirectoryNotFoundError(error: Dynamic):Bool {
		var message:String = '';
		if ((error is String)) 
            message = cast(error, String);
        else {
            try {
                message = Std.string(error);
            }
            catch (e: Dynamic) {
                return false;
            }
        }

		if (message.empty()) 
            return false;
        
		var enoent:EReg = (~/ENOENT: no such file or directory/gmi);
		if (enoent.match(message)) 
            return true;
		else 
            return false;
    }

	/**
		[TODO] nothing
	**/
	private static function isFileOrDirectoryAlreadyExistsError(error: Dynamic):Bool {
		var message:String = '';
		if ((error is String))
			message = cast(error, String);
		else {
			try {
				message = Std.string(error);
			} catch (e:Dynamic) {
				return false;
			}
		}

		if (message.empty())
			return false;

		var enoent:EReg = (~/EEXIST: file already exists/gmi);
		if (enoent.match(message))
			return true;
		else
			return false;
	}
}