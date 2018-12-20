package pmdb.ql.ast;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateOp;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

import haxe.Constraints.Function;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

enum ECheck {
    ECEquals(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECNotEquals(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECGt(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECLt(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECGte(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECLte(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECIn(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECRegex(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECLike(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECIs(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECExists(x: Lnk<Dynamic>);
    ECSizeEq(a:Lnk<Dynamic>, b:Lnk<Dynamic>);
    ECElemMatch(a:Lnk<Dynamic>, b:Lnk<Dynamic>);

    ENil;
}

