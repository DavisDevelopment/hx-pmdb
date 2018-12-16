package pmdb.core.ds.macro;

final class TCell<TValue, TNext> {
    /* Constructor Function */
    public function new(v, nxt) {
        _v = v;
        _n = nxt;
    }

    public var v(get, never):TValue;
    inline function get_v() return _v;

    public var next(get, never):TNext;

    inline function get_next() return _n;

    @:final private var _n(default, null):TNext;
    @:final private var _v(default, null):TValue;
}
