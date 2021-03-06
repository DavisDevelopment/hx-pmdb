package pmdb.core.ds;

class Incrementer {
    public function new(state:Int = 0):Void {
        this.state = state;
    }

/* === Methods === */

    public inline function next():Int {
        return ++state;
    }

    public inline function current():Int {
        return state;
    }

    public inline function reset():Int {
        return state = 0;
    }

/* === Variables === */

    private var state(default, null): Int;
}
