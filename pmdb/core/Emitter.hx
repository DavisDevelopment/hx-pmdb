package pmdb.core;

import haxe.ds.Option;
import pm.async.Callback;
import pm.async.Signal;
import pm.*;
import pm.concurrent.RunLoop;

import haxe.Constraints.IMap;

using pm.Functions;

@:generic
class Emitter<Evt, Info> {
    public var _signals:IMap<Evt, Signal<Info>>;
    public var requireEventDeclaration(default, null):Bool = true;
    public var isAsync(default, null):Bool = true;

    public function new() {
        _signals = null;
    }

    public function addEvent(event: Evt) {
        _signals.set(event, new Signal());
    }

    function getSignal(event: Evt):Maybe<Signal<Info>> {
        if (_signals.exists(event)) {
            return _signals.get(event);
        }
        else if (!requireEventDeclaration) {
            var res:Signal<Info> = new Signal();
            _signals.set(event, res);
            return res;
        }
        else {
            return None;
        }
    }

    public function emit(event:Evt, data:Info) {
        switch getSignal(event) {
            case Some(signal):
                if (isAsync) {
                    defer(signal.broadcast.bind(data));
                }
                else {
                    signal.broadcast(data);
                }

            case None:
                if (requireEventDeclaration) {
                    throw new pm.Error('Event($event) not found');
                }
        }
    }

    public function listen(event:Evt, listener:Callback<Info>, ?prepend:Bool, ?once:Bool):CallbackLink {
        switch getSignal(event) {
            case Some(signal):
                return signal.listen(listener, prepend, once);

            case None:
                throw new pm.Error('Event($event) not found');
        }
    }
    public function on(event:Evt, listener:Callback<Info>, ?prepend:Bool):CallbackLink {
        return listen(event, listener, prepend);
    }
    public function once(event:Evt, listener:Callback<Info>, ?prepend:Bool):CallbackLink {
        return listen(event, listener, prepend, true);
    }
}