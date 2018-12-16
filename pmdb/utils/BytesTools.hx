package pmdb.utils;

import tannus.io.Byte;
import tannus.io.Char;
import tannus.io.Chunk;
import tannus.ds.Ref;
import tannus.ds.Lazy;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesData;
import haxe.io.ArrayBufferView;
import haxe.io.UInt8Array;
//import haxe.io.UInt16Array;
//import haxe.io.UInt32Array;
//import haxe.io.Float32Array;
//import haxe.io.Float64Array;
import haxe.io.Input;

import pmdb.core.Error;

import tannus.math.TMath.*;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.math.TMath;
using tannus.async.OptionTools;
using tannus.FunctionTools;

class BytesTools {
    public static function concat(a:Bytes, b:Bytes):Bytes {
        //TODO
        throw new Error();
    }
}
