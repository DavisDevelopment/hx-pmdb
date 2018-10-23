
package pmdb.storage.io;

import tannus.io.Byte;

import haxe.io.Bytes;
import haxe.io.Input as HxInput;

import sys.io.FileInput;

import pmdb.storage.io.SeekableInput;

import pmdb.core.Error;
import pmdb.core.Assert.assert;
import pmdb.storage.io.IoException;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class HxFileInputShim extends SeekableInput {
    public function new(i: FileInput):Void {
        input = i;
        #if python
        bigEndian = true;
        #else
        bigEndian = input.bigEndian;
        #end
    }

    override function readUInt8():Int {
        try {
            return input.readByte();
        }
        catch (e: haxe.io.Eof) {
            throw new EndOfInput();
        }
        catch (e: haxe.io.Error) {
            throw switch e {
                case haxe.io.Error.Blocked: new IoBlocked();
                case haxe.io.Error.Overflow: new IoOverflow();
                case haxe.io.Error.OutsideBounds: new IoOutsideBounds();
                case haxe.io.Error.Custom(err): new IoException(IoErrorCode.Custom(err));
            }
        }
    }

    override function close() {
        input.close();
    }

    override function eof():Bool {
        return input.eof();
    }

    override function tell():Int {
        return input.tell();
    }

    override function seek(p:Int, pos:Seek) {
        input.seek(p, s2fs(pos));
    }

    static inline function s2fs(s: Seek):sys.io.FileSeek {
        return s;
    }

    public var input: FileInput;
}
