package pmdb.ql;

import haxe.ds.Option;
import haxe.extern.EitherType as Either;

import pmdb.core.Assert.assert;

using pmdb.core.Arch;
using pmdb.ql.ts.TypeCasts;

class Operators {
    public static function __add__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isString() || b.isString()) return '$a$b';
        if (a.isFloat()) {
            assert(b.isFloat(), 'invalid type for $b');
            return (a.asFloat() + b.asFloat());
        }
        if (a.isArray() && b.isIterable()) {
            var a = a.asArray(), b = b.makeIterator();
            return a.concat([for (x in b) x]);
        }
        throw 'Invalid arguments ($a, $b)';
    }

    public static function __sub__(a:Dynamic, b:Dynamic):Dynamic {
        if (a.isFloat()) {
            assert(b.isFloat(), 'invalid operation(-) on $a and $b');
            return (a.asFloat() - b.asFloat());
        }
        throw 'Invalid arguments ($a, $b)';
    }
}

typedef TAddable = Either4<Float, String, Array<Dynamic>, Iterable<Dynamic>>;
private typedef Either3<A, B, C> = Either<A, Either<B, C>>;
private typedef Either4<A, B, C, D> = Either<Either<A, B>, Either<C, D>>;
