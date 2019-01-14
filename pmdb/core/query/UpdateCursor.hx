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
import pmdb.ql.ast.nodes.update.Update;

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
@:access( pmdb.core.query.StoreQueryInterface )
class UpdateCursor<Item> extends QueryCursor<Item, Array<UpdateLog<Item>>> {
    public function new(store, mut:Mutation<Item>, ?check:Criterion<Item>, compileMutation=false, compileFilter=false, noInit=false) {
        super( store );
        _compile = {
            check: compileFilter,
            update: compileMutation
        };
        options = {
            multiple: true,
            insert: false
        };

        update = mut;
        //trace( update );
        updateNode = update.isStruct() ? null : store.q.updateNode( update );
        structure = update.isStruct() ? update.toStruct() : null;

        if (check != null)
            criterion = check;
        else
            criterion = new pmdb.ql.ast.nodes.NoCheck();
        checkNode = compileCriterion( criterion );

        this.mutator = function(ctx:QueryInterp, item:Item):Item {
            ctx.newDoc(d -> Arch.clone(d, JsonReparse));
            updateNode.eval( ctx );
            return cast ctx.flushNewDoc();
        }

        if ( !noInit )
            init();
    }

    override function init() {
        super.init();

        if ( _compile.check ) {
            this._filter = ((fn) -> (ctx) -> fn(ctx))(checkNode.compile());
            this.predicate = function(context, item:Item) {
                return _filter(context.setDoc(item.asObject()));
            }
        }

        if (structure != null) {
            compileStructure();
        }
        else if (_compile.update) {
            if (updateNode != null) {
                _update = ((fn) -> (ctx) -> fn(ctx))(updateNode.compile());
                this.mutator = function(context:QueryInterp, stale:Item):Item {
                    context.newDoc(d -> Arch.clone(d, ShallowRecurse));
                    _update( context );
                    return cast context.flushNewDoc();
                }
            }
        }

        /**
          wrap [mutator] to ensure that it is executed in "update" mode
         **/
        this.mutator = this.mutator.wrap(function(fn, c:QueryInterp, item:Item):Item {
            c.enterMode( Update );
            var res = fn(c, item);
            c.leaveMode();
            return res;
        });
    }

    private function compileStructure() {
        assert(structure != null, new Error('cannot compile [structure]! No value has been assigned to it'));

        var keys = structure.keys();
        var steps:Array<Object<Dynamic> -> Void> = new Array();
        steps.resize(keys.length);

        for (i in 0...keys.length) {
            steps[i] = (function(key:String, value:Dynamic) {
                if (key.has('.')) {
                    return function(doc: Object<Dynamic>) {
                        doc.dotSet(key, value);
                    }
                }
                else {
                    return function(doc: Object<Dynamic>) {
                        doc.set(key, value);
                    }
                }
            })(keys[i], structure[keys[i]]);
        }

        this.mutator = function(c:QueryInterp, doc:Item):Item {
            var newDoc:Item = Arch.clone_object(doc, ShallowRecurse);
            var docObject = newDoc.asObject();
            for (step in steps) {
                step( docObject );
            }
            return newDoc;
        }
    }

    static function _wfiltr<A, B>(u:UpdateCursor<A>):A->Bool {
        return u._filter.wrap(function(_, doc:A):Bool {
            return _(u.qi.ctx.setDoc(cast doc));
        });
    }

    public function multiple(?value: Bool):Bool {
        return value == null ? options.multiple : options.multiple = value;
    }

    public function insert(?value: Bool):Bool {
        return value == null ? options.insert : options.insert = value;
    }

    /**
      TODO implement as
     **/
    override function exec():Array<UpdateLog<Item>> {
        //TODO rollback entire update-operation if a commit fails
        var update: Array<UpdateLog<Item>>;
        if ( options.multiple ) {
            update = multiExec();
        }
        else {
            final log = singleExec();
            update = log == null ? [] : [log];
        }

        if (options.insert && update.length == 0 && structure != null) {
            if (store.schema.validateStruct( structure )) {
                store.insertOne(cast structure);
                update = [{
                    pre: null,
                    post: cast structure
                }];
            }
            else {
                throw new Error('Invalid document');
            }
        }

        return update;
    }

    private function singleExec():Null<UpdateLog<Item>> {
        var items = candidates();
        var update:Null<UpdateLog<Item>> = null;
        for (index in 0...items.length) {
            if (predicate(qi.ctx, items[index])) {
                final upre = items[index];
                final upost = mutator(qi.ctx, upre);
                update = {pre:upre, post:upost};
                break;
            }
        }

        switch commitUpdate( update ) {
            case Failure(error):
                throw new ValueError(error, 'Update Failed');

            case Success:
                return update;
        }
    }

    private function multiExec():Array<UpdateLog<Item>> {
        var items:Array<Item> = candidates();
        var updates:Array<Null<UpdateLog<Item>>> = new Array();
        updates.resize( items.length );

        for (index in 0...items.length) {
            if (predicate(qi.ctx, items[index])) {
                final upre = items[index];
                final upost = mutator(qi.ctx, upre);
                updates[index] = {
                    pre: upre,
                    post: upost
                };
            }
            else {
                updates[index] = null;
            }
        }

        var out:Array<UpdateLog<Item>> = new Array();
        for (index in 0...updates.length) {
            if (updates[index] == null)
                continue;

            final step = commitUpdate(updates[index]);
            switch ( step ) {
                case Failure(error):
                    throw new ValueError(error, 'Update failed');

                case Success:
                    out.push(updates[index]);
                    continue;
            }
        }

        return out;
    }

    //public function iterate():UpdateIteration<Item, UpdateStep<Item>> {
        //return new ApplyUpdateIteration( this );
    //}

    dynamic function _update(c: QueryInterp) {
        updateNode.eval( c );
    }

    dynamic function _filter(c: QueryInterp):Bool {
        return checkNode.eval( c );
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
    public var updateNode(default, null): Null<Update>;
    public var structure(default, null): Null<Object<Dynamic>>;

    private var options(default, null): {multiple:Bool, insert:Bool};

    var _compile(default, null):{check:Bool, update:Bool};
    var _filterc(default, null): Null<QueryInterp -> Bool> = null;
    var _updatec(default, null): Null<QueryInterp -> Void> = null;

    private var mutator(default, null): (c:QueryInterp, oldItem:Item) -> Item;
}

//class UpdateIteration<Item, T> {
//    public function new(cursor) {
//        this.cursor = cursor;
//        this.itr = cast cursor.caret.iterator();
//    }

//    public function hasNext():Bool {
//        return itr.hasNext();
//    }

//    public function next():T {
//        //return itr.next();
//        throw 'ni';
//    }

//    public var cursor(default, null): UpdateCursor<Item>;
//    public var itr(default, null): IndexItemCaretIterator<Item>;
//}

//class PassThroughUpdateIteration<T> extends UpdateIteration<T, T> {
//    override function next():T { return itr.next(); }
//}

//@:access(pmdb.core.query.UpdateCursor)
//class ApplyUpdateIteration<Item> extends UpdateIteration<Item, UpdateStep<Item>> {
//    public function new(c) {
//        super( c );
//    }

//    override function next():UpdateStep<Item> {
//        // apply the relevant mutation to [doc]
//        var logEntry = cursor.applyUpdate(itr.next());

//        // commit the mutation to the Store for journaling
//        var step = cursor.commitUpdate(logEntry);
//        //TODO (rollback entire transaction on errors)

//        return step;
//    }
//}

enum UpdateStep<T> {
    Success;
    Failure(err: Dynamic);
}
