package pmdb.core.query;

import pmdb.ql.ast.*;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.update.Update as Node;

import pmdb.Globals.timestamp;

import haxe.PosInfos;
import haxe.ds.Option;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;

/**
  represents a set of changes made to a data store
 **/
class JournalBase<T> {
    /* Constructor Function */
    public function new(?entryList: Iterable<JournalEntry<T>>) {
        this.entries = entryList != null ? entryList.array() : new Array();
        _sort();
    }

/* === Methods === */

    /**
      sort [this]'s entries
     **/
    private function _sort() {
        entries.sort(function(a, b) {
            return Reflect.compare(a.time.getTime(), b.time.getTime());
        });
    }

    private var entries(default, null): Array<JournalEntry<T>>;
}

class JournalEntry<T> {
    public var e(default, null): JournalEntryType<T>;
    public var time(default, null): Date;

    public inline function new(type, ?time) {
        this.e = type;
        this.time = time != null ? time : Date.now();
    }
}

enum JournalEntryType<T> {
    /**
      represents an alteration to the structure of the Store<?>
     **/
    JtAlter(e: AlterJournalEntry<T>);

    /**
      represents a change made to the content of the Store<?>
     **/
    JtModify(e: ModJournalEntry<T>);
}

enum ModJournalEntry<T> {
    JtInsert(e: InsertJournalEntry<T>);
    JtUpdate(e: UpdateJournalEntry<T>);
    JtDelete(e: DeleteJournalEntry<T>);
}

enum AlterJournalEntry<T> {

}

class InsertJournalEntry<T> {
    public final doc : T;

    public inline function new(doc) {
        this.doc = doc;
    }
}

class UpdateJournalEntry<T> {
    public final oldDoc : T;
    public final newDoc : T;

    public inline function new(nDoc, pDoc) {
        this.newDoc = nDoc;
        this.oldDoc = pDoc;
    }
}

class DeleteJournalEntry<T> {
    public final doc: T;

    public inline function new(doc) {
        this.doc = doc;
    }
}
