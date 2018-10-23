package pmdb.storage.io;

import pmdb.core.Error;

class IoException extends Error {
    /* Constructor Function */
    public function new(code, ?msg, ?pos) {
        super(msg, pos);

        this.code = code;
    }

    public inline function isCustom():Bool {
        return code.match(Custom(_));        
    }

    public function originalException():Null<Dynamic> {
        return switch code {
            case Custom(e): e;
            case _: null;
        }
    }

    public var code(default, null): IoErrorCode;
}

class EndOfInput extends IoException {
    public function new(?pos) {
        super(Eoi, null, pos);
    }
}

class IoBlocked extends IoException {
    public function new(?pos) {
        super(Blocked, null, pos);
    }
}

class IoOverflow extends IoException {
    public function new(?pos) {
        super(Overflow, null, pos);
    }
}

class IoOutsideBounds extends IoException {
    public function new(?pos) {
        super(OutsideBounds, null, pos);
    }
}

enum IoErrorCode {
    Eoi;
    Blocked;
    Overflow;
    OutsideBounds;
    Custom(e: Dynamic);
}
