package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
//import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class LteCheck extends CompEqCheck {
    //override function compCheck(a, b, rel:Int):Bool {
    override function compCheck(a:Dynamic, b:Dynamic, rel:Int):Bool {
        return (rel <= 0);
    }
}
