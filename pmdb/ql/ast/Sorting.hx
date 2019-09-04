package pmdb.ql.ast;

@:forward
abstract Sorting (Map<String, SortOrder>) from Map<String, SortOrder> to Map<String, SortOrder> {
    /* Constructor Function */
    public inline function new() {
        this = new Map();
    }

    public static function simple(key:String, ordering:SortOrder = SortOrder.Asc):Sorting {
        var sort = new Sorting();
        sort.set(key, ordering);
        return sort;
    }
}

@:enum
abstract SortOrder (Int) from Int to Int {
    var Asc = 1;
    var Desc = -1;
}
