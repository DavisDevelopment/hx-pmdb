package pmdb.ql.ts;


import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Error;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.CallStack;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import tannus.math.TMath as M;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

using pmdb.core.Utils;
using pmdb.ql.ts.DataTypes;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

/**
  not really "casts", per se; more like coercions
 **/
class TypeCasts {

}
