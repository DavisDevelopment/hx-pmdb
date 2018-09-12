package pmdb.ql.types;

import tannus.io.Byte;
import tannus.io.ByteArray;
import tannus.io.Char;
import tannus.io.RegEx;

// why does tannus.ds.* have so many useful types with four-letter names?
import tannus.ds.Anon;
import tannus.ds.Dict;
import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Uuid;
import tannus.ds.Ref ; // :c

import haxe.ds.Either;
import haxe.ds.Option;
import hscript.Expr.Const;

import tannus.math.TMath as M;

import pmdb.core.Arch;
import pmdb.core.Error;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

abstract DotPath (String) to String {
    /* Constructor Function */
    inline function new(s: String) {
        this = s;
    }

/* === Instance Methods === */

    public inline function follow(ctx: Dynamic):Dynamic {
        return Arch.getDotValue(ctx, this);
    }

/* === Factory Methods === */

    @:from
    public static inline function parse(s: String):DotPath {
        return new DotPath( s );
    }
}

