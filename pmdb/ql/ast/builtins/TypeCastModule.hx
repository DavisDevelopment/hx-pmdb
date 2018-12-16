package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.TypeChecks;
import pmdb.ql.ts.TypeCasts;
import pmdb.ql.ast.BuiltinFunction;
import haxe.Constraints.Function;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class TypeCastModule extends BuiltinModule {
    /* Constructor Function */
    public function new() {
        super('type_casts');

        //addMethod('bool', (a: Array<TypedData>) -> switch a {
            //case [val]: switch val {
                //case DNull: DBool(false);
                //case DFloat(n): DBool(n != 0);
                //case DInt(i): DBool(i != 0);
                //case DArray()
            //}
        //})

        //addMethod('bool', [
            //'bool -> bool' => FunctionTools.identity,
            //'float -> bool' => n -> n == 0.0 ? false : true,
            //'string -> bool' => (x: String) -> switch x {
                //case 'true': true;
                //case 'false': false;
                //case _: !x.empty();
            //},
            //'?Any -> Bool' => (x: Null<Dynamic>) -> (x != null)
        //]);

        //addMethod('float', [
            //'float -> float' => (FunctionTools.identity:Function),
            //'bool -> float' => (x: Bool) -> x ? 1.0 : 0.0,
            //'Date -> float' => ((x: Date) -> x.getTime():Function),
            //'String -> float' => ((x: String) -> Std.parseFloat( x ):Function)
        //]);
    }
}
