package pmdb;

import pm.concurrent.RunLoop;
import haxe.PosInfos;

//using StringTools;
//using pm.Strings;
//using pm.Numbers;
//using pm.Functions;

class Globals {
    /**
      get most accurate possible timestamp
     **/
    public static function timestamp(?pos: PosInfos):Float {
        #if (js && (hxnodejs || nodejs || node))
        var tmp = js.Node.process.hrtime();
        return tmp[0] * 1e3 + tmp[1] / 1e6;
        #elseif js
        return js.Browser.window.performance.now();
        #elseif python
        return python.Syntax.code('{0}.perf_counter() * 1e3', python.lib.Time);
        #else
        return (1000.0 * Sys.time());
        #end
    }

    public static function measure(func: Void -> Void, ?pos:PosInfos):Float {
        var start = timestamp( pos );
        func();
        return (timestamp() - start);
    }

    public static inline function nn<T>(v: Null<T>):Bool
        return v != null;
    
    public static inline function nor<T>(a:Null<T>, b:Null<T>):Null<T> {
        return nn(a) ? a : b;
    }
    public static inline function defer(f: Void->Void) {
        RunLoop.current.work(f);
    }

    public static var DKEY = '_id';
    public static var METAKEYPRE = "$$";
}
