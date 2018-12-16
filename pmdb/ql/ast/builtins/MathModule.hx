package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class MathModule extends BuiltinModule {
    /* Constructor Function */
    public function new() {
        super('math');
        add('abs', 'float->float', Math.abs.bind());
        add('floor', 'float->int', Math.floor.bind());
        add('ceil', 'float->int', Math.ceil.bind());
        add('round', 'float->int', Math.round.bind());
        add('ceil', 'float->int', Math.ceil.bind());
        add('sin', 'float->float', Math.sin.bind());
        add('cos', 'float->float', Math.cos.bind());
        add('sqrt', 'float->float', Math.sqrt.bind());
        add('pow', 'float->float->float', Math.pow.bind());
        add('random', 'void->float', Math.random.bind());
    }
}
