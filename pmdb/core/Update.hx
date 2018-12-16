package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

class Update<T> {
    /* Constructor Function */
    public function new(?update:DocumentUpdate<T>, ?options: UpdateOptions<T>) {
        //this.pattern = null;
        
        if (options == null)
            options = {};
        if (options.multi == null)
            options.multi = false;
        if (options.upsert == null)
            options.upsert = false;
        this.options = options;

        this.du = null;
        if (update != null)
            du = update;
    }

/* === Methods === */

    //public function where(pattern: QueryFilter):Update<T> {
        //this.pattern = pattern;
        //return this;
    //}

    public function update(uq: DocumentUpdate<T>):Update<T> {
        this.du = uq;
        return this;
    }

/* === Variables === */

    //public var pattern(default, null): Null<QueryFilter>;
    public var du(default, null): Null<DocumentUpdate<T>>;
    public var options(default, null): UpdateOptions<T>;
}

typedef UpdateOptions<T> = {
    ?multi: Bool,
    ?upsert: Bool
}

enum EDocumentUpdate<T> {
    DModify(m: Alter<T>);
    DReplace(m: T);
}

@:forward
abstract DocumentUpdate<T> (EDocumentUpdate<T>) from EDocumentUpdate<T> to EDocumentUpdate<T> {
    @:from public static function fgenAlt<T>(fn: Alter<T> -> Alter<T>):DocumentUpdate<T> {
        return fromAlter(fn(new Alter<T>()));
    }

    @:from public static function vfgenAlt<T>(fn: Alter<T> -> Void):DocumentUpdate<T> {
        var tmp = new Alter<T>();
        fn( tmp );
        return fromAlter( tmp );
    }

    @:from
    public static inline function fromAlter<T>(a: Alter<T>):DocumentUpdate<T> {
        return DModify( a );
    }

    @:from
    public static inline function overwrite<T>(v: T):DocumentUpdate<T> {
        return DReplace( v );
    }
}
