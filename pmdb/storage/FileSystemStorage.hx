package pmdb.storage;

import pmdb.core.ds.Lazy;
import pmdb.core.ds.Outcome;

import haxe.PosInfos;
import haxe.ds.Option;
import haxe.io.Bytes;
import sys.FileSystem;
import sys.io.File;

import pmdb.storage.IStorage;

using pm.Strings;
using pm.Path;
using pm.Arrays;

class FileSystemStorage implements IStorageSync {
    /* Constructor Function */
    public function new() {
        //
    }

/* === Methods === */

    public function exists(path: String):Bool {
        return inline FileSystem.exists( path );
    }

    public function size(path: String):Int {
        return FileSystem.stat(path).size;
    }

    public function rename(oname:String, nname:String) {
        return inline FileSystem.rename(oname, nname);
    }

    public function unlink(path: String) {
        return inline FileSystem.deleteFile( path );
    }

    public function readFile(path: String):String {
        return File.getContent( path );
    }

    public function readFileBinary(path: String):Bytes {
        return File.getBytes( path );
    }

    public function writeFile(path:String, data:String):Void {
        File.saveContent(path, data);
    }

    public function writeFileBinary(path:String, data:Bytes):Void {
        File.saveBytes(path, data);
    }

    public function appendFile(path:String, data:String):Void {
        #if js
        js.node.Fs.appendFileSync(path, data);
        #else
        final out:Null<sys.io.FileOutput> = File.append(path, false);
        out.writeString( path );
        out.close();
        #end
    }

    public function appendFileBinary(path:String, data:Bytes):Void {
        #if js
            js.node.Fs.appendFileSync(path, js.node.Buffer.from(data.getData()));
        #else
            final out:Null<sys.io.FileOutput> = File.append( path );
            out.writeString( path );
            out.close();
        #end
    }

    public function createDirectory(path: String) {
        FileSystem.createDirectory(path);
    }

    public function mkdirp(path: String):Void {
        var pieces:Array<String> = [];
        var p:String = path;
        do {
            pieces.push(p);
            p = p.directory();
        }
        while (!(p.empty() || p == '.' || p == '..'));

        try {
            FileSystem.createDirectory( path );
        }
        catch (err: Dynamic) {
            trace('createDirectory($path) error: $err');
            if (isNotFoundError(err)) {
                var i = pieces.length;
                while (i-- > 0) {
                    var part:String = pieces[i];
                    if (!exists(part)) {
                        createDirectory(part);
                    }
                }
                assert(exists(path), new pm.Error('Failed to create "$path"'));
            }
            else {
                throw err;
            }
        }
    }

    private function isNotFoundError(error: Dynamic) {
        var message:String = '';
        if ((error is String))
            message = cast(error, String);
        else {
            return false;
        }

        if (message.empty()) {
            return false;
        }
        var enoent:EReg = (~/ENOENT: no such file or directory/gmi);
        if (enoent.match(message)) {
            return true;
        }
        return false;
    }

    public function ensureFileDoesntExist(path: String):Bool {
        if (exists( path )) {
            unlink( path );
        }

        return true;
    }

    public function flushToStorage(options: {filename:String, ?isDir:Bool}) {
        throw new NotImplementedError('FileSystemStorage.flushToStorage');
    }

    public function crashSafeWriteFile(path:String, data:Bytes):Void {
        //throw new NotImplementedError('FileSystemStorage.crashSafeWriteFile');
        trace('TODO: crashSafeWriteFile');
        writeFileBinary(path, data);
    }

    public function ensureDatafileIntegrity(path: String):Void {
        throw new NotImplementedError('FileSystemStorage.ensureDatafileIntegrity');
    }

    private static var instance:FileSystemStorage = new FileSystemStorage();
    public static function make():FileSystemStorage {
        return instance;
    }
}
