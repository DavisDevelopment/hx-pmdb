package pmdb.ql;

import haxe.ds.Option;
import haxe.extern.EitherType as Either;

import pmdb.core.Assert.assert;

using pmdb.core.Arch;
using pmdb.ql.ts.TypeCasts;
using pmdb.ql.ts.DataTypes;

/**
    TODO: define type-safe aliases to operator methods
**/
class Operators {
    public static function __add__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isString() || b.isString()) return '$a$b';
        if (a.isFloat()) {
            //assert(b.isFloat(), 'invalid type for $b');
            if (!b.isFloat()) 
                throw invalid('/', a, b);
            return (a.asFloat() + b.asFloat());
        }

        if (a.isArray() && b.isIterable()) {
            var a = a.asArray(), b = b.makeIterator();
            return a.concat([for (x in b) x]);
        }

        throw invalidArgs(a, b);
    }

    public static function __sub__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isFloat()) {
            //assert(b.isFloat(), 'invalid operation(-) on $a and $b');
            if (!b.isFloat())
                throw invalid('-', a, b);
            return (a.asFloat() - b.asFloat());
        }

        throw invalidArgs(a, b);
    }

    public static function __div__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isFloat()) {
            if (!b.isFloat()) 
                throw invalid('/', a, b);
            return (a.asFloat() / b.asFloat());
        }
        throw invalidArgs(a, b);
    }

    public static function __mult__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isFloat()) {
            if (!b.isFloat()) 
                throw invalid('*', a, b);
            return (a.asFloat() * b.asFloat());
        }
        throw invalidArgs(a, b);
    }

    static function invalid(op:String, a:Dynamic, b:Dynamic) {
        return new pm.Error('Invalid operation: ${a.dataTypeOf().print()} a $op ${b.dataTypeOf().print()} $b');
    }
    static function invalidArgs(a:Dynamic, b:Dynamic, ?pos:haxe.PosInfos) {
        return new pm.Error([
            'Invalid arguments: ${pos!=null?pos.methodName:''}',
            '(${a.dataTypeOf().print()} a, ${b.dataTypeOf().print()} $b)'
        ].join(''), pos);
    }
}

typedef TAddable = Either4<Float, String, Array<Dynamic>, Iterable<Dynamic>>;
private typedef Either3<A, B, C> = Either<A, Either<B, C>>;
private typedef Either4<A, B, C, D> = Either<Either<A, B>, Either<C, D>>;
