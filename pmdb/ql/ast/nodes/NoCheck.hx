package pmdb.ql.ast.nodes;

//import tannus.ds.Lazy;
//import tannus.ds.Pair;
//import tannus.ds.Set;

//import pmdb.ql.ts.DataType;
//import pmdb.ql.ts.DocumentSchema;
//import pmdb.ql.ts.DataTypeClass;
//import pmdb.ql.ast.Value;
//import pmdb.ql.ast.ValueResolver;
//import pmdb.ql.ast.PredicateExpr;
//import pmdb.ql.ast.UpdateExpr;
//import pmdb.core.Error;
//import pmdb.core.Object;
//import pmdb.core.Index;
//import pmdb.core.Store;

import pmdb.ql.ast.PredicateExpr as Pe;
//import pmdb.ql.ast.Value.ValueExpr as Ve;

//import haxe.ds.Either;
//import haxe.ds.Option;
//import haxe.PosInfos;
//import haxe.extern.EitherType;

//import pmdb.core.Arch.isType;

//using StringTools;
//using tannus.ds.StringUtils;
//using Slambda;
//using tannus.ds.ArrayTools;
//using tannus.FunctionTools;
//using pmdb.ql.ts.DataTypes;
//using pmdb.ql.ast.Predicates;

class NoCheck extends Check {
    public function new(?expr, ?pos) {
        //initialize variables
        super(expr, pos);
    }

    override function clone():Check {
        return new NoCheck(expr, position);
    }

    override function eval(i: QueryInterp):Bool {
        return true;
    }

    override function compile():QueryInterp->Bool {
        return (c -> true);
    }
}
