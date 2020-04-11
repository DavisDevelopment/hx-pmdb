package pmdb.storage;

import haxe.io.*;
import pm.io.Chunk;
import pm.io.DataStream;

import haxe.ds.Option;

import UnicodeString;
import haxe.iterators.StringIterator;
import haxe.iterators.StringIteratorUnicode;
import haxe.iterators.StringKeyValueIterator;
import haxe.iterators.StringKeyValueIteratorUnicode;

import sys.io.FileSeek;
import sys.io.FileInput;
import sys.io.File;

#if (false && js && hxnodejs)
import js.node.Buffer as NodeBuffer;
import js.node.Fs as NodeFs;
// import js.node.stream.
#elseif sys
//
#end

/**
  [FINISH-ME-PLZ]
 **/

@:access(sys.io.FileInput)
class FileLines {
    static var chunkByteLength:Int = 2000;
    
    var __offset: Int = -1;
    public var fileOffset(get, set): Int;

    var fileReader: FileInput;
    var _chunk:#if hxnodejs NodeBuffer #else Bytes #end;

    public function new() {
        
    }

    private function get_fileOffset():Int return __offset;
    private function set_fileOffset(i: Int):Int {
        if (__offset == -1) {
            __offset = i;
        }
    }
}