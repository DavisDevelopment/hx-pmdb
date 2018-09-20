package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Cursor;
import pmdb.core.QueryFilter;

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

/**
  model of alterations to be made to an object
 **/
class Alter<T> {
    /* Constructor Function */
    public function new() {
        stack = [];
        mut = null;
    }

/* === Methods === */

    public function apply(doc:T, store:Store<T>):Void {
        if (mut == null) {
            compile();
        }

        //TODO further streamline where possible

        mut
        .withStore( store )
        .apply( doc );
    }

    public function compile():Void {
        if (mut != null)
            return ;

        mut = Mutator.passThrough();
        for (tk in stack) {
            //if (mut == null) {
                //mut = Mutator.compileToken( tk );
            //}
            //else {
                mut = mut.append(Mutator.compileToken( tk ));
            //}
        }

        //if (mut == null)
            //throw new Error("Cannot compile. Alter is empty!");
    }

    public function set(fk:String, v:Dynamic):Alter<T> {
        return tk("$set", fk, v);
    }
    
    public function unset(fk: String):Alter<T> {
        return tk("$unset", fk);
    }

    public function push(fk:String, v:Dynamic):Alter<T> {
        return tk("$push", fk, v);
    }

    public function pull(fk:String, v:Dynamic):Alter<T> {
        return tk("$pull", fk, v);
    }

    public function addToSet(fk:String, v:Dynamic):Alter<T> {
        return tk("$addToSet", fk, v);
    }

    public function pop(fk:String, v:Int):Alter<T> {
        return tk("$pop", fk, v);
    }

    /**
      appends a new update-token to [this]
     **/
    private function tk(op:String, fn:String, ?v:Dynamic):Alter<T> {
        stack.push({
            type: op,
            fieldName: fn,
            value: v
        });
        if (mut != null)
            mut = null;
        return this;
    }

/* === Variables === */

    private var stack(default, null): Array<UpdTok>;
    private var mut(default, null): Null<Mutator<T, Dynamic>>;
}

@:structInit
class UpdTok {
    public var type(default, null): String;
    public var fieldName(default, null): String;
    @:optional public var value(default, null): Dynamic;
}

//enum Tok {
    //TkSet(field:String, value:Dynamic);
    //TkUnset(field: String);
    //TkPush(field:String, value:Dynamic);
    //TkAddToSet(field:String, value:Dynamic);
    //TkPull(field:String, value:Dynamic);

    //TkPush(field:String, value:Dynamic);
    //TkPop(field:String, flag:Int);
//}
