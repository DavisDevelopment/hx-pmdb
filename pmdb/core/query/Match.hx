package pmdb.core.query;

import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.QueryFilter;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

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
using pmdb.ql.types.DataTypes;
using pmdb.core.QueryFilters;

@:access( pmdb.core.QueryFilter )
class Match {
    /* Constructor Function */
    public function new(query: QueryFilter) {
        this.query = query;
    }

/* === Methods === */

    /**
      returns whether [this]'s QueryFilter matched the given document
     **/
    public function test(doc:Anon<Anon<Dynamic>>, ?store:Store<Any>):Bool {
        return query.ast.queryMatch(doc, store);
    }

/* === Variables === */

    var query: QueryFilter;
}
