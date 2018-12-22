package pmdb.core.ds.tools;

import pmdb.core.Assert.assert;

#if cpp
import cpp.NativeArray;
#end

class ArrayTools {
    public static inline function alloc<T>(len:Int):Array<T> {
        assert(len >= 0, "invalid allocation size");
        var a: Array<T>;

        #if flash
            a = untyped __new__(Array, len);
            return a;

        #elseif js
            #if (haxe_ver >= 4.000)
                a = js.Syntax.construct(Array, len);
            #else
                a = untyped __new__(Array, len);
            #end
            return a;

        #elseif cpp
            //a = new Array<T>();
            //a.setSize( len );
            //return a;
            return NativeArray.create( len );
        
        #elseif java
            return untyped Array.alloc(len);
        
        #elseif cs

            return cs.Lib.arrayAlloc(len);
        
        #else
            a = new Array<T>();
            a.resize( len );
            return a;
        
            //#if neko
                //a[len - 1] = cast null;
            //#end
            
            //for (i in 0...len)
                //a[i] = cast null;
            //return a;
        #end
    }

    /**
      Copies `n` elements from `src`, beginning at `srcPos` to `dst`, beginning at `dstPos`.

      Copying takes place as if an intermediate buffer was used, allowing the destination and source to overlap.
     **/
    public static function blit<T>(src:Array<T>, srcPos:Int, dst:Array<T>, dstPos:Int, n:Int) {
        if (n > 0) {
            assert(srcPos < src.length, "srcPos out of range");
            assert(dstPos < dst.length, "dstPos out of range");
            assert(srcPos + n <= src.length && dstPos + n <= dst.length, "n out of range");

            #if cpp
                cpp.NativeArray.blit(dst, dstPos, src, srcPos, n);

            #else
            if (src == dst) {
                if (srcPos < dstPos) {
                    var i = srcPos + n;
                    var j = dstPos + n;
                    for (k in 0...n) {
                        i--;
                        j--;
                        src[j] = src[i];
                    }
                }
                else if (srcPos > dstPos) {
                    var i = srcPos;
                    var j = dstPos;
                    for (k in 0...n) {
                        src[j] = src[i];
                        i++;
                        j++;
                    }
                }
            }
            else {
                if (srcPos == 0 && dstPos == 0) {
                    for (i in 0...n) 
                        dst[i] = src[i];
                }
                else
                    if (srcPos == 0) {
                        for (i in 0...n)
                            dst[dstPos + i] = src[i];
                    }
                    else
                        if (dstPos == 0) {
                            for (i in 0...n)
                                dst[i] = src[srcPos + i];
                        }
                        else {
                            for (i in 0...n)
                                dst[dstPos + i] = src[srcPos + i];
                        }
            }
            #end
        }
    }
}

