package pmdb.ql;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.core.ValType;
import pmdb.core.StructSchema;
import pmdb.ql.ast.BuiltinFunction;
import pmdb.ql.ast.BuiltinModule;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.QueryNode;
import pmdb.ql.ast.builtins.*;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.hsn.QlParser;
import pmdb.core.ds.*;
import pmdb.ql.ts.*;
import pmdb.core.Assert.assert;
import pmdb.core.Store;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.runtime.Operator;

import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;

import pmdb.core.ds.*;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

/**
  class which models the query interpreter engine
 **/
class QueryInterp {
    /* Constructor Function */
    public function new(?store:Store<Dynamic>, ?mode):Void {
        document = null;
        parameters = null;
        tree = null;
        this.modeStack = new LinkedStack();
        modeStack.push(Compute);
        this.store = store;

        initBuiltins();
        initOperators();
    }

/* === Methods === */

    public inline function hasSchema():Bool {
        return store != null && store.schema != null;
    }

    /**
      link the given QueryNode to [this]
     **/
    public inline function setTree(node: QueryNode):QueryInterp {
        this.tree = node;
        return this;
    }

    inline function _ascend() {
        while (tree.parentNode != null)
            tree = tree.parentNode;
    }

    /**
      assign the 'current' document to be used by [this]
     **/
    public inline function setDoc(o: Object<Dynamic>):QueryInterp {
        this.document = o;
        return this;
    }

    /**
      link the given Store with [this]
     **/
    public inline function setStore(store: Store<Dynamic>):QueryInterp {
        this.store = store;
        return this;
    }

    /**
      create a new document object, assign it to the [newDocument] register, and return it
     **/
    public function newDoc(?mk:Doc->Doc):Ref<Doc> {
        assert(document != null, "Cannot allocate new document while primary document register is empty");
        if (newDocument == null) {
            newDocument = Ref.to(
                if (mk != null)
                    mk( document )
                else
                    document.clone()
            );
        }

        return newDocument;
    }

    /**
      unlinks [newDocument] from [this]
     **/
    public inline function clearNewDoc() {
        newDocument = null;
    }

    /**
      apply [fn] to [newDocument]
     **/
    public inline function tapNewDoc(fn:Ref<Doc>->Void, unsafe=false):Ref<Doc> {
        fn(unsafe ? newDocument : newDoc());
        return newDocument;
    }

    /**
      unlinks and returns [newDocument] from [this]
     **/
    public function flushNewDoc():Null<Doc> {
        var res = null;
        if (newDocument != null) {
            res = newDocument.get();
            clearNewDoc();
        }
        return res;
    }

    public function getDoc(addr = 0):Null<Doc> {
        return switch ( addr ) {
            case 0: document;
            case 1: newDocument != null ? newDocument.get() : null;
            default:
                throw new ValueError(addr, 'register-address out of bounds');
        }
    }

    public inline function enterMode(m: InterpMode) {
        modeStack.push( m );
    }
    public inline function leaveMode() {
        modeStack.pop();
    }

    /**
      initialize query-functions and things
     **/
    inline function initBuiltins() {
        builtins = new Map();
        inline function init(b: BuiltinFunction)
            builtins[b.name] = b;
        //inline function imprt(m: BuiltinModule)
            //m.importInto( this );

        init(new Add());
        init(new Sub());
        init(new Mul());
        init(new Div());
        init(new Neg());

        //imprt(new MathModule());
        //imprt(new TypeCastModule());
    }

    /**
      initialize binary operators
     **/
    function initOperators() {
        binops = new Map();
        inline function op(n:String, f:Dynamic->Dynamic->Dynamic) {
            binops[n] = new BinaryOperator(n, f);
        }

        op('+', Operators.__add__);
        op('-', Operators.__sub__);

        unops = new Map();
        inline function op(n:String, f:Dynamic->Dynamic, pre=false) {
            return unops[n] = new UnaryOperator(n, f, pre);
        }
    }

/* === Properties === */

    private var compiler(get, never): QueryCompiler;
    inline function get_compiler():QueryCompiler return store != null ? store.q.compiler : null;

    private var parser(get, never): QlParser;
    inline function get_parser():QlParser return store != null ? store.q.parser : null;

    public var mode(get, never): InterpMode;
    inline function get_mode():InterpMode return modeStack.top();

/* === Fields === */

    public var store(default, null): Null<Store<Dynamic>>;

    public var document(default, null): Null<Object<Dynamic>>;
    public var newDocument(default, null): Null<Ref<Object<Dynamic>>>;
    public var parameters: Null<Array<Dynamic>>;

    public var modeStack(default, null): Stack<InterpMode>;

    public var builtins(default, null): Map<String, BuiltinFunction>;
    public var binops(default, null): Map<String, BinaryOperator<Dynamic, Dynamic, Dynamic>>;
    public var unops(default, null): Map<String, UnaryOperator<Dynamic, Dynamic>>;

    // the root-node for the Query-tree
    public var tree(default, null): Null<QueryNode>;
}

@:structInit
class UpdateLog<T> {
    public var pre: Null<T>;
    public var post: T;
}

enum InterpMode {
    Select;
    Update;
    Delete;

    Compute;
}

class InterpScope {
    private var parent(default, null): Null<InterpScope> = null;
    //public var defined(default, null): Map<String, Interp;
    public function new(?parent) {
        this.parent = parent;
    }
}

