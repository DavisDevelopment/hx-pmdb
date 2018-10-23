package pmdb.storage.io;

import tannus.io.Byte;

import haxe.io.Bytes;
import haxe.io.Input as HxInput;

import pmdb.core.Error;
import pmdb.core.Assert.assert;
import pmdb.storage.io.IoException;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class HxInputShim<T:HxInput> extends Input {
    public function new(i: T) {
        input = i;
        bigEndian = input.bigEndian;
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

    public var input: T;
}
