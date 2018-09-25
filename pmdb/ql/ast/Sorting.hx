package pmdb.ql.ast;

import tannus.ds.Dict;

@:forward
abstract Sorting (Map<String, SortOrder>) from Map<String, SortOrder> to Map<String, SortOrder> {
    /* Constructor Function */
    public inline function new() {
        this = new Map();
    }
}

@:enum
abstract SortOrder (Int) from Int to Int {
    var Asc = 1;
    var Desc = -1;
}
