package pmdb.core.query;

import tannus.ds.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.LazyItr;
import pmdb.core.query.IndexItemCaret;
import pmdb.core.Store;

import pmdb.ql.*;
import pmdb.ql.QueryInterp;
import pmdb.ql.ast.*;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.ASTError;
import pmdb.ql.ts.TypeSystemError;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.QueryIndex;
import pmdb.ql.hsn.QlParser;
import pmdb.core.Error;

import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import pmdb.Macros.*;
import pmdb.Globals.*;
import Slambda.fn;
import Std.is as isType;
import pmdb.core.Assert.assert;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using pmdb.ql.ast.Predicates;
using pmdb.core.ds.Outcome;

@:access( pmdb.core.Store )
class UpdateCursor<Item> extends QueryCursor<Item, Array<UpdateLog<Item>>> {
    public function new(q, mut:Mutation<Item>, ?check:Criterion<Item>, compileMutation=false, compileFilter=false, noInit=false) {
        super( q );
        _compile = {
            check: compileFilter,
            update: compileMutation
        };

        update = mut;
        if (check != null)
            filter = check;
        else
            filter = new pmdb.ql.ast.nodes.NoCheck();
        filter = ensureFilter( filter );

        if ( !noInit )
            init();
    }

    override function init() {
        super.init();

        if ( _compile.check ) {
            //_filterc = filter.compile();
            _filter = ((fn) -> (ctx) -> fn(ctx))(ensureFilter(filter).compile());
        }

        if ( _compile.update ) {
            //_updatec = update.compile();
            _update = ((fn) -> (ctx) -> fn(ctx))(update.compile());
        }
    }

    inline function _all():Array<Item> {
        return searchIndex.index.getAll();
    }

    inline function candidates():Array<Item> {
        return _all().filter(_wfiltr(this));//x -> _filter(x));
    }

    static function _wfiltr<A, B>(u:UpdateCursor<A>):A->Bool {
        return u._filter.wrap(function(_, doc:A):Bool {
            return _(u.qi.ctx.setDoc(cast doc));
        });
    }

    override function exec():Array<UpdateLog<Item>> {
        //TODO rollback entire update-operation if a commit fails
        var items = candidates();
        var out = [];
        for (item in items) {
            out.push(applyUpdate( item ));
        }
        return out;
    }

    public function iterate():UpdateIteration<Item, UpdateStep<Item>> {
        return new ApplyUpdateIteration( this );
    }

    dynamic function _update(c: QueryInterp) {
        update.eval( c );
    }

    dynamic function _filter(c: QueryInterp):Bool {
        return ensureFilter( filter ).eval( c );
    }

    function applyUpdate(doc: Item):UpdateLog<Item> {
        // save reference to [doc] 
        var upre = doc, upost = null;

        // execute the update-operation on [doc]
        _update(qi.ctx.setDoc(cast doc));

        // obtain reference to the newly-mutated [doc]
        upost = qi.ctx.flushNewDoc();
        assert(upost != null, "QueryInterp.flushNewDoc returned NULL");

        return {pre:upre, post:cast upost};
    }

    /**
      "commit"s the given update to the Store object
     **/
    function commitUpdate(u: UpdateLog<Item>):UpdateStep<Item> {
        try {
            store.updateIndexes(u.pre, u.post);
            //...
            return Success;
        }
        catch (err: Dynamic) {
            // by the time [err] is caught here, all changes associated with this update have been rolled back
            return Failure( err );
        }
    }

/* === Fields === */

    public var update(default, null): Mutation<Item>;

    var _compile(default, null):{check:Bool, update:Bool};
    var _filterc(default, null): Null<QueryInterp -> Bool> = null;
    var _updatec(default, null): Null<QueryInterp -> Void> = null;
}

class UpdateIteration<Item, T> {
    public function new(cursor) {
        this.cursor = cursor;
        this.itr = cast cursor.caret.iterator();
    }

    public function hasNext():Bool {
        return itr.hasNext();
    }

    public function next():T {
        //return itr.next();
        throw 'ni';
    }

    public var cursor(default, null): UpdateCursor<Item>;
    public var itr(default, null): IndexItemCaretIterator<Item>;
}

class PassThroughUpdateIteration<T> extends UpdateIteration<T, T> {
    override function next():T { return itr.next(); }
}

@:access(pmdb.core.query.UpdateCursor)
class ApplyUpdateIteration<Item> extends UpdateIteration<Item, UpdateStep<Item>> {
    public function new(c) {
        super( c );
    }

    override function next():UpdateStep<Item> {
        // apply the relevant mutation to [doc]
        var logEntry = cursor.applyUpdate(itr.next());

        // commit the mutation to the Store for journaling
        var step = cursor.commitUpdate(logEntry);
        //TODO (rollback entire transaction on errors)

        return step;
    }
}

enum UpdateStep<T> {
    Success;
    Failure(err: Dynamic);
}
