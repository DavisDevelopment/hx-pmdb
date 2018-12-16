package pmdb.storage.io;

import tannus.io.Byte;

import haxe.io.Bytes;
import haxe.io.Input as HxInput;
import haxe.io.BytesBuffer;
import haxe.io.FPHelper;

import pmdb.core.Error;
import pmdb.core.Assert.assert;
import pmdb.storage.io.IoException;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class ParserBase <Tk> {
    public function new() {
        //initialize variables
    }

/* === Methods === */

    inline function readByte():Byte {
        return try input.readByte() catch (e: Dynamic) 0;
    }

/* === Variables === */

    var input(default, null): Input;
    var char(default, null): Int = -1;
}
