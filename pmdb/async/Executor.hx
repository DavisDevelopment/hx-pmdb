package pmdb.async;

import pm.async.*;

using pm.Functions;

class Executor {
    public function new() {
        //
    }

    static function nextTick(fn: Void->Void):Promise<Float> {
        return new Promise(function(yes, no) {
            Callback.defer(function() {
                var begin = timestamp();
                fn();
                var took = (timestamp() - begin);
                yes( took );
            });
        });
    }
}
