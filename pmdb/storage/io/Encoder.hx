package pmdb.storage.io;

import tannus.io.Byte;

import haxe.io.Bytes;
import haxe.io.Input as HxInput;
import haxe.io.Output;
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

class Encoder {
    public function new() {
        cache = new Array();
        shash = new Map();
        scount = 0;

        output = new BytesBuffer();
    }

/* === Methods === */

    

/* === Variables === */

    var output: BytesBuffer;

    var cache: Array<Dynamic>;
    var shash: Map<String, Int>;
    var scount: Int;
}

@:enum
abstract TypeCode (Int) from Int to Int {
    var CArray = 0x0061;
    var CHash = 0x0062;
    var CClassInstance = 0x0063;
    var CFloat = 0x0064;
    var CEnd = 0x0065;
    var CFalse = 0x0066;
    var CStructEnd = 0x0067;
    var CInt = 0x0068;
    // 'j'(0x0069)
    var CNaN = 0x0070;
    // 'l'(0x0071)
    var CNegInf = 0x0072;
    var CNull = 0x0073;
    var CObject = 0x0074;
    var CPosInf = 0x0075;
    // 'q' (0x0076)
    var CRef = 0x0077;
    var CBytes = 0x0078;
    var CTrue = 0x0079;
    // 'u' (0x0080)
    var CDate = 0x0081;
    var CEnumValue = 0x0082;
    var CException = 0x0083;
    var CString = 0x0084;
    var CZero = 0x0085;
    var CClass = 0x0041;
    var CEnum = 0x0042;
    var CCustom = 0x0043;
}
