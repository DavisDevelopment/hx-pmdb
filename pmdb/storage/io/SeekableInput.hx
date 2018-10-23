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

class SeekableInput extends Input {
    public function eof():Bool {
        return false;
    }

    public function tell():Int {
        return 0;
    }

    public function seek(p:Int, pos:Seek) {
        //
    }
}

/*
enum Seek {
    SeekBegin;
    SeekCur;
    SeekEnd;
}
*/
typedef Seek = sys.io.FileSeek;

