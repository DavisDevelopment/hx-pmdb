package pmdb.core.ds;

import pmdb.core.Assert.assert;

/**
  Generates unique, unsigned integer keys
 **/
class HashKey {
    static var _counter:
        #if (js || neko || python || php)
            Null<Int>;
        #else
            Int;
        #end

    /**
      Returns the next integer in a list of unique, unsigned integer keys.
     **/
    public static function next():Int {
        #if (js || neko || python || php || eval)
            if (_counter == null) {
                _counter = 0;
            }
        #end

        assert(_counter < _counter + 1);

        return _counter++;
    }
}
