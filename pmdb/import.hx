
import pm.Error;
//import pmdb.ql.ts.TypeSystemError;
import pmdb.core.Arch;
import pm.Assert.assert;

import pmdb.Globals.*;

#if !macro
import pmdb.Macros.*;
#end

using StringTools;
using Lambda;
using pmdb.utils.Tools;

#if ((java || neko))
import pm.utils.LazyConsole as Console;
#end
