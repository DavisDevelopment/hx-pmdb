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

/**
  
 **/
class Input {
    public function close():Void {
        return ;
    }

    public function readUInt8():Int {
        throw new NotImplementedError('pmdb.format.io.Input::readUInt8');
    }

    public function readByte():Byte {
        return new Byte(readUInt8());
    }

    private function set_bigEndian(v: Bool):Bool {
        bigEndian = v;
        return bigEndian;
    }

    public function readBytes(s:Bytes, pos:Int, len:Int):Int {
        var k = len;
        var b = #if (js || hl) @:privateAccess s.b #else s.getData() #end;
        if (pos < 0 || len < 0 || pos + len > s.length)
            throw new IoOutsideBounds();
        try {
            while (k > 0) {
                #if neko
                untyped __dollar__sset(b, pos,readUInt8());
                #elseif php
                b.set(pos, readUInt8());
                #elseif cpp
                b[pos] = untyped readUInt8();
                #else
                b[pos] = cast readUInt8();
                #end
                pos++;
                k--;
            }
        }
        catch (eof: EndOfInput) {}
        return len - k;
    }

    public function readAll(?bufsize: Int):Bytes {
        if (bufsize == null)
            #if php
            bufsize = 8192; // default value for PHP and max under certain circumstances
            #else
            bufsize = (1 << 14); // 16 Ko
            #end

        var buf = Bytes.alloc(bufsize);
        var total = new haxe.io.BytesBuffer();
        try {
            var len;
            while ( true ) {
                len = readBytes(buf, 0, bufsize);
                if (len == 0)
                    throw new IoBlocked();
                total.addBytes(buf, 0, len);
            }
        }
        catch (e : EndOfInput) { }
        return total.getBytes();
    }

    public function readFullBytes(s:Bytes, pos:Int, len:Int):Void {
        while (len > 0) {
            var k = readBytes(s, pos, len);
            if (k == 0)
                throw new IoBlocked();
            pos += k;
            len -= k;
        }
    }

    public function read(nbytes: Int):Bytes {
		var s = Bytes.alloc( nbytes );
		var p = 0;
		while (nbytes > 0) {
			var k = readBytes(s, p, nbytes);
			if (k == 0)
			    throw new IoBlocked();
			p += k;
			nbytes -= k;
		}
		return s;
    }

    public function readBytesUntil(end: Byte):Bytes {
		var buf = new BytesBuffer();
		var last : Int;
		while ((last = readUInt8()) != end)
			buf.addByte( last );

		return buf.getBytes();//.toString();
    }

    public function readUntil(end: Byte):String {
        return readBytesUntil(end).toString();
    }

    public inline function freadBytesUntil(fn:Byte -> Bool):Bytes {
        var buf = new BytesBuffer();
        var last: Int;
        while (!fn(last = readByte()))
            buf.addByte( last );
        return buf.getBytes();
    }

    public inline function freadUntil(fn:Byte->Bool):String {
        return freadBytesUntil( fn ).toString();
    }

    public function readLine():String {
        var buf = new BytesBuffer();
        var last:Int;
        var s;
        try {
			while ((last = readUInt8()) != 10)
				buf.addByte( last );
			s = buf.getBytes().toString();
			// if the last char in [s] is a 13
			if (s.charCodeAt(s.length - 1) == 13) 
			    // trim off the last char
			    s = s.substr(0, -1);
        }
        catch (e: EndOfInput) {
            s = buf.getBytes().toString();
            if (s.length == 0)
				#if neko neko.Lib.rethrow #else throw #end (e);
        }
        return s;
    }

	public function readInt8():Int {
		var n = readUInt8();
		if (n >= 128)
			return n - 256;
		return n;
	}

	public function readInt16():Int {
		var ch1 = readUInt8();
		var ch2 = readUInt8();
		var n = 
		    if (bigEndian) ch2 | (ch1 << 8)
            else ch1 | (ch2 << 8);
		if (n & 0x8000 != 0)
			return n - 0x10000;
		return n;
	}

	public function readUInt24():Int {
		var ch1 = readUInt8();
		var ch2 = readUInt8();
		var ch3 = readUInt8();
		return 
            if ( bigEndian )
                (ch3 | (ch2 << 8) | (ch1 << 16))
            else 
                (ch1 | (ch2 << 8) | (ch3 << 16));
    }

    public function readInt24():Int {
        var n = readUInt24();
		if (n & 0x800000 != 0)
			return n - 0x1000000;
		return n;
    }

	public function readInt32():Int {
		var ch1 = readUInt8();
		var ch2 = readUInt8();
		var ch3 = readUInt8();
		var ch4 = readUInt8();

    #if (php || python)
		var n = bigEndian ? ch4 | (ch3 << 8) | (ch2 << 16) | (ch1 << 24) : ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
		if (n & 0x80000000 != 0)
			return (n | 0x80000000);
		else return n;
    #elseif lua
		var n = bigEndian ? ch4 | (ch3 << 8) | (ch2 << 16) | (ch1 << 24) : ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
		return lua.Boot.clamp(n);
    #else
		return bigEndian ? ch4 | (ch3 << 8) | (ch2 << 16) | (ch1 << 24) : ch1 | (ch2 << 8) | (ch3 << 16) | (ch4 << 24);
    #end
	}

	public function readUInt32():Int {
	    return (readInt32() >>> 0);
	}

    public function readString(len: Int):String {
        var b = Bytes.alloc( len );
        readFullBytes(b, 0, len);
        #if neko
        return neko.Lib.stringReference(b);
        #else
        return b.getString(0, len/*, encoding*/);
        #end
	}

	public function readFloat():Float {
	    return FPHelper.i32ToFloat(readInt32());
	}

	public function readDouble():Float {
		var i1 = readInt32();
		var i2 = readInt32();
		return bigEndian
		    ? FPHelper.i64ToDouble(i2, i1) 
		    : FPHelper.i64ToDouble(i1, i2);
	}

/* === Fields === */

    public var bigEndian(default, set): Bool;
}
