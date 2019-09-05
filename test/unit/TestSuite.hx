package unit;

import haxe.PosInfos;
import haxe.io.*;

import haxe.rtti.Meta;
import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Arch;
import pmdb.core.Assert.*;
import pmdb.Globals.*;
import pmdb.Macros.*;

using Slambda;
using pmdb.core.Error;
using StringTools;
using pm.Functions;

using haxe.macro.ExprTools;

/**
  TODO also write some scaffolding for running benchmarks
 **/
@:keepSub
@:dce("no")
class TestSuite {
    function new(r: TestRunner) {
        cases = [];
        caseMap = new Map();

        _subtests_();
    }

    public function setup() { }
    public function tearDown() { }

    public function run() {
        setup();
        var res = [];
        for (test in cases) {
            res.push({
                test: test,
                result: test.exe()
            });
        }
        tearDown();
        return res;
    }

    public function runTest(test:String, ?pos:PosInfos):TestCaseResult {
        if (!caseMap.exists( test )) {
            throw new Error('No such test-case "$test"', pos);
        }
        return caseMap[test].exe();
    }

    public function setupCase(name: String) {
        //
    }

    public function tearDownCase(name: String) {
        //
    }

    /**
      it may not be advisable to use methods that themselves need continuous testing
      in order to test the rest of the system, but it's convenient, so that's exactly what 
      I'm doing in <code>assertEq</code> and <code>assertNEq</code>
     **/
    @:keep
    inline function assertEq<A, B>(a:A, b:B, ?c:Dynamic, ?pos:haxe.PosInfos) {
        // trace('assertEq($a, $b)', pos);
        assert(Arch.areThingsEqual(a, b), c != null ? c : '$a == $b');
    }

    @:keep
    inline function assertNEq<A, B>(a:A, b:B, ?c:Dynamic) {
        assert(!Arch.areThingsEqual(a, b), c != null ? c : '$a == $b');
    }

    private var useConsole(default, null): Bool = false;
    public function line<T>(x: T) {
        if ( useConsole ) {
            trace( x );
        }
        else {
            if (output != null) {
                output.writeString(Std.string( x ));
            } 
            else {
                Sys.println( x );
            }
        }
    }

    public inline function lines<T>(x: Array<T>) {
        line(x.join('\n'));
    }


    /**
      load all 'sub-tests' into [cases]
     **/
    private function _subtests_() {
        var names = Type.getInstanceFields(Type.getClass(this));
        names = names.filter(x -> x.startsWith('test'));
        cases = new Array();
        caseMap = new Map();

        for (name in names) {
            cases.push(caseMap[name] = new TestCase(this, name, tcwrap(function() {
                Reflect.callMethod(this, Reflect.field(this, name), []);
            })));
        }
    }

    private static inline function tcwrap(f:Void -> Void):Void->TestCaseResult {
        return function():TestCaseResult {
            return new TestCaseResult(measure( f ), null);
        }
    }

    private var cases(default, null): Array<TestCase>;
    private var caseMap(default, null): Map<String, TestCase>;
    private var output(default, null): Null<haxe.io.Output> = null;
}

class TestCase {
    public var suite(default, null): TestSuite;
    public var name(default, null): String;
    public var _exe(default, null): Void->TestCaseResult;

    public function new(suite:TestSuite, name:String, f:Void->TestCaseResult) {
        this.suite = suite;
        this.name = name;
        this._exe = f;
    }

    public inline function setup() {
        suite.setupCase( name );
    }

    public inline function tearDown() {
        suite.tearDownCase( name );
    }

    public inline function exe():TestCaseResult {
        setup();
        var result = _exe();
        tearDown();
        return result;
    }
}

class TestCaseResult {
    /* Constructor Function */
    public function new(/*tc:TestCase, */exeTime:Float, ?err:Dynamic) {
        this.exeTime = exeTime;
        //testCase = tc;
        this.exception = err;
    }

    public var failed(get, never): Bool;
    inline function get_failed():Bool return (exception != null);

    //public var testCase(default, null): TestCase;
    public var exception(default, null): Null<Dynamic>;
    public var exeTime(default, null): Float;
}
