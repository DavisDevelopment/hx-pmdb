package pmdb.async;

import pmdb.core.Error.NotImplementedError;
import pmdb.core.ds.Noise;
import pmdb.core.ds.Outcome;

import pmdb.async.Callback;
import pmdb.async.Deferred;

class Promise<Val, Err> {
    var d(default, null): Deferred<Val, Err>;

    var ss:{v:Signal<Val>, e:Signal<Err>} = null;
    var _o:Null<Outcome<Val, Err>> = null;
    //var 

    public function new(base: Deferred<Val, Err>):Void {
        this.d = base;
        var needSigs = true;
        this.d.handle(function(r: DeferredResolution<Val, Err>) {
            switch ( r ) {
                case Result(x):
                    _o = Success( x );
                    if (ss != null) 
                        ss.v.broadcast( x );

                case Exception(x):
                    _o = Failure( x );
                    if (ss != null)
                        ss.e.broadcast( x );
            }

            needSigs = false;
        });

        if (_o == null) {
            ss = {v:new Signal<Val>(), e:new Signal<Err>()};
        }
    }

    public function catchException(onErr: Err -> Void) {
        if (ss != null) {
            ss.e.listen( onErr );
        }
        else if (_o != null) {
            switch _o {
                case Failure(e):
                    onErr( e );
                case _:
                    //
            }
        }
        else {
            throw new WTFError();
        }
    }

    public function then(onRes:Val->Void, ?onErr:Err->Void) {
        //d.handle(_handleCb(onRes, onErr));
        if (ss != null) {
            ss.v.listen(onRes);
            if (onErr != null)
                ss.e.listen(onErr);
        }
        else if (_o != null) {
            switch ( _o ) {
                case Success(x):
                    onRes( x );

                case Failure(x):
                    if (onErr != null)
                        onErr( x );
            }
        }
        else { 
            trace( this );
            throw new WTFError();
        }
    }

    //static function _handleCb<V,E>(v:V->Void, ?e:E->Void):DeferredResolution<V, E>->Void {
        //return function(res: DeferredResolution<V, E>) {
            //switch ( res ) {
                //case Result(x):
                    //v( x );

                //case Exception(x) if (e != null):
                    //e( x );

                //default:
                    //return ;
            //}
        //}
    //}
}
