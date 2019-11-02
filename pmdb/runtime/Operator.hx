package pmdb.runtime;

class Operator<Fn:haxe.Constraints.Function> {
    // the textual representation of the operator
    public final s: String;

    // the function which performs the operator
    public final f: Fn;

    // the number of operands the operator takes
    public final arity: Int;

    public function new(name, arity, func) {
        this.s = name;
        this.arity = arity;
        this.f = func;
    }
}

class BinaryOperator<A, B, C> extends Operator<(left:A, right:B)->C> {
    public function new(name, func) {
        super(name, 2, func);
    }
    public function toString():String {
        return 'A $s B';
    }
}

class UnaryOperator<A, B> extends Operator<A -> B> {
    @:keep
    public var prefix : Bool;
    public function new(name, func, prefix=false) {
        super(name, 1, func);
        this.prefix = prefix;
    }

    public function toString():String {
        return prefix ? '${s}A' : 'A$s';
    }
}
