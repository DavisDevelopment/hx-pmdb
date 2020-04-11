package pmdb.storage;

import haxe.ds.Option;
import haxe.io.*;
import pm.*;
import pm.strings.HashCode.*;

#if (sys || hxnodejs)
import Sys as I;
#end

using pm.Arrays;
using StringTools;
using pm.Strings;
using pm.strings.HashCodeTools;
using pm.Iterators;
using pm.Maps;
using pm.Path;

class System {
    #if (sys || hxnodejs)
    
    #end

    static var _isWindows:Null<Bool> = null;

    public static inline function isWindows():Bool {

    }

    public static inline function getCwd():Path {
        return #if (sys || hxnodejs) new Path(I.getCwd()) #else new Path('/') #end;
    }
}