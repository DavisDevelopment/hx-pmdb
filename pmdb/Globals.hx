package pmdb;

import tannus.io.*;
import tannus.ds.*;
import tannus.async.*;

import haxe.PosInfos;
import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using tannus.math.TMath;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.ds.SortingTools;
using tannus.ds.AnonTools;
using tannus.FunctionTools;
using tannus.async.Asyncs;

class Globals {
    /**
      get most accurate possible timestamp
     **/
    public static inline function timestamp(?pos: PosInfos):Float {
        #if nodejs
        //return switch (js.Node.process.hrtime()) {
            //case [_ * 1e3 => msl, _ / 1e6 => msr]: msl + msr;
            //case _: throw 'wtf';
        //}
        var tmp = js.Node.process.hrtime();
        return tmp[0] * 1e3 + tmp[1] / 1e6;

        #elseif python

        return python.Syntax.code('{0}.perf_counter() * 1e3', python.lib.Time);

        #else

        return (1000.0 * Sys.time());

        #end
    }

    public static inline function measure(func: Void -> Void, ?pos:PosInfos):Float {
        var start = timestamp( pos );
        func();
        return (timestamp(pos) - start);
    }

    public static var DKEY = '_id';
    public static var METAKEYPRE = "$$";
}
