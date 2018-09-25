package pmdb.ql.ts;

import tannus.ds.Dict;

import hscript.Parser;
import hscript.Expr;

import pmdb.core.Error;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;

class DataTypeClass {
    /* Constructor Function */
    public function new(name:String, options:DTCOptions) {
        this.name = name;
        this.parameters = parameters.copy();
        this.conversions = new Dict();
        this.options = options;

        this.construct = options.construct;
        this.tester = options.test;
    }

/* === Methods === */

    public inline function addConversion(signature:TypeConversion, convert:Dynamic->Dynamic) {
        conversions[signature] = convert;
    }

    public inline function isInstance(value: Dynamic):Bool {
        return tester( value );
    }

    public inline function make(args: Array<Dynamic>):Dynamic {
        return construct( args );
    }

    //@:access( hscript.Parser )
    //public static function parseDataType(expr: String):DataType {
        //var names = expr.split('|').map.fn(_.trim().nullEmpty()).compact();
        //var parser = new Parser();
        //parser.allowTypes = true;

        //for (name in names) {
            //parser.allowJSON 
        //}
    //}

/* === Variables === */

    public var name(default, null): String;
    public var parameters(default, null): Array<DbTypeParam>;
    public var conversions(default, null): Dict<TypeConversion, Dynamic->Dynamic>;

    public var options(default, null): DTCOptions;

    private var construct(default, null): Array<Dynamic> -> Dynamic;
    private var tester(default, null): Dynamic -> Bool;
}

@:structInit
class DbTypeParam {
    public var name: String;
}

enum TypeConversion {
    ConvertFrom(type: DataType);
    ConvertTo(type: DataType);
}

typedef DTCOptions = {
    construct: Array<Dynamic> -> Dynamic,
    test: Dynamic -> Bool,
    //conversions: Dynamic<{to:Dynamic->Dynamic, from:Dynamic->Dynamic}>
}

typedef DataField = {};
