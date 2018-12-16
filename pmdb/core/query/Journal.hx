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

class Journal<T> {}

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

enum AlterJournalEntryType<T> {
    //TODO
}

class InsertJournalEntry<T> {
    public var doc(default, null): T;
    public function new(doc) {
        this.doc = doc;
    }
}

class UpdateJournalEntry<T> {
    public var oldDoc(default, null): T;
    public var newDoc(default, null): T;

    public function new(nDoc, pDoc) {
        newDoc = nDoc;
        oldDoc = pDoc;
    }
}

class DeleteJournalEntry<T> extends InsertJournalEntry<T> {
    public function new(doc) {
        super( doc );
    }
}
