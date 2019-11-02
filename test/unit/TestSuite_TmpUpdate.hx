package unit;

import pm.Noise;
import pm.async.Promise;
import pm.Object;
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
using pm.Strings;
using pm.Functions;
using pm.Helpers;
using haxe.macro.ExprTools;

/**
	TODO also write some scaffolding for running benchmarks
**/
@:keepSub
@:dce("no")
class TestSuite {
	function new(r:TestRunner) {
		cases = [];
		caseMap = new Map();

		_subtests_();
	}

	public function setup() {}

	public function tearDown() {}

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
		if (!caseMap.exists(test)) {
			throw new Error('No such test-case "$test"', pos);
		}
		return caseMap[test].exe();
	}

	public function setupCase(name:String) {
		//
	}

	public function tearDownCase(name:String) {
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

	private var useConsole(default, null):Bool = false;

	public function line<T>(x:T) {
		if (useConsole) {
			trace(x);
		} else {
			if (output != null) {
				output.writeString(Std.string(x));
			} else {
				Sys.println(x);
			}
		}
	}

	public inline function lines<T>(x:Array<T>) {
		line(x.join('\n'));
	}

	/**
		load all 'sub-tests' into [cases]
	**/
	private function _subtests_() {
		var m:Object<Object<Array<Dynamic>>> = cast haxe.rtti.Meta.getFields(Type.getClass(this));
		var names = Type.getInstanceFields(Type.getClass(this));
		var testMethods = [];
		var middlewares = [];
		middlewares.push(function(flags:TestMetaInit, entry:{name:String, ?value:Dynamic}):Bool {
			Console.log(flags);
			Console.log('$name=${Std.string(value)}');
			return false;
		});
		middlewares.pop();

		for (field => meta in m) {
			if (meta.exists('test')) {
				var testMeta = meta.get('test');
				var flags:TestMetaInit = {
					async: false,
					benchmark: {
						args: ([] : Array<Dynamic>),
						minCycles: 1,
						maxCycles: 100
					}
				};
				flags.benchmark = null;

				if (testMeta != null)
					for (metaArg in testMeta) {
						if (metaArg == 'async') {
							flags.async = true;
						}
						if ((metaArg is String)) {
							var entry = {name: '', value: null};
							var metaStr:String = Std.string(metaArg);
							var hasValueReg = ~/([\w_][\w\d]*)=(.+)/gi;
							if (hasValueReg.match(metaStr)) {
								var name = hasValueReg.matched(1).trim(),
									value:Dynamic = hasValueReg.matched(2).trim();
								try {
									value = haxe.Json.parse('$value');
								} catch (e:Dynamic) {
									//
								}
								// entry.with(_.name = name);
								entry.name = name;
								entry.value = value;
							} else {
								entry.name = metaStr.trim();
								entry.value = true;
							}

							for (m in middlewares) {
								var doNext = m(flags, entry);
								if (!doNext)
									break;
							}
						} else {
							var vt = Type.typeof(metaArg);
							throw 'Unexpected $vt value';
						}
					}

				new TestCase(this, field, tcwrap(function() {
					var args:Array<Dynamic> = [];
					switch flags {
						case {async: true, benchmark: null}:
					}
					Reflect.callMethod(this, Reflect.field(this, field),)
				}))
			}
		}
		var names = names.filter(x -> x.startsWith('test'));
		cases = new Array();
		caseMap = new Map();

		for (name in names) {
			cases.push(caseMap[name] = new TestCase(this, name, tcwrap(function() {
				Reflect.callMethod(this, Reflect.field(this, name), []);
			})));
		}
	}

	private static inline function tcwrap(f:Void->Void):Void->TestCaseResult {
		return function():TestCaseResult {
			return new TestCaseResult(measure(f), null);
		}
	}

	private var cases(default, null):Array<TestCase>;
	private var caseMap(default, null):Map<String, TestCase>;
	private var output(default, null):Null<haxe.io.Output> = null;
}

class TestCase {
	public var suite(default, null):TestSuite;
	public var name(default, null):String;
	public var config:{
		async:Bool,
		measure:Bool,
		benchmark:Null<{}>
	};

	public var _exe(default, null):Null<Void->Promise<TestCaseResult>> = null;
	public var _spawn(default, null):Null<TestCaseStatus->Void> = null;

	// public var _spawn(default, null): Null<Void -> Promise<TestCaseResult>> = null;

	public function new(suite:TestSuite, name:String) {
		this.suite = suite;
		this.name = name;
		// this._exe = f;
	}

	public var executor(get, set):Dynamic;

	private function get_executor():Null<Dynamic> {
		if (_exe != null)
			return _exe;
		if (_spawn != null)
			return _spawn;

		return null;
		// throw new pm.Error('No TestCase.executor value assigned');
	}

	public function set_executor(f:Dynamic) {
		if (config.async) {
			this._spawn = f;
			this._exe = null;
		} else {
			this._exe = f;
			this._spawn = null;
		}
	}

	public function setup() {
		suite.setupCase(name);
	}

	public function tearDown() {
		suite.tearDownCase(name);
	}

	public inline function exe_sync():TestCaseResult {
		setup();
		var result = _exe();
		tearDown();
		return result;
	}

	private function executeAsync():Promise<TestCaseResult> {
		var f:Dynamic = this.executor;
		var args:Array<Dynamic> = [], tailOps = [];

		var _cb_status:TestCaseStatus->Void, _cb:TestCaseResult->Void;
		var _cbp = new Promise(function(_return:TestCaseStatus->Void) {
			_cb_status = _return;
			trace('`_cb` bound');
		});
		_cbp.then(function(status) switch status {
			case Failed((_ is Array<Dynamic>) && cast(_, Array<Dynamic>) => arr):
				Console.warn('Test failed with ${arr.length} errors');
				throw arr;

			case Failed(error):
			//

			case Passed(null):
		}) var callback:Dynamic = Reflect.makeVarArgs(function(args:Array<Dynamic>) {

			if (args.empty())
				return _cb(TestCaseStatus.Passed(null));
			else if (args.length == 1) {
				var arg:Dynamic = args[0];
				if ((arg is TestCaseStatus))
					return _cb(cast(arg, TestCaseStatus));
				// else if ((arg ))
			}
			if (args.length >= 2 && Std.is(args[0], String)) {
				switch (Std.string(args[0]).toLowerCase()) {
					case 'pass' | 'success':
						_cb(TestCaseStatus.Passed(args.slice(1)));

					case 'fail', 'throw', 'failure':
						_cb(TestCaseStatus.Failed(args.slice(1)));

					case verb:
						// TODO allow custom extended verbs to be implemented
						throw new pm.Error('Unhandled verb ${verb.toUpperCase()}');
				}
			}
			throw new pm.Error.NotImplementedError('callback(${args})');
		});

		var invoke:Void->Void = function() {
			Console.error('well this sucks');
		};

		if (config.async && Reflect.compareMethods(_spawn, f)) {
			tailOps.push(() -> {
				args.push(callback);
			});
			invoke = function() {
				var ff = () -> _spawn(status -> {})
			}
		} else if (Reflect.compareMethods(_exe, f)) {}
	}
}

class TestCaseResult {
	/* Constructor Function */
	public function new( /*tc:TestCase, */ exeTime:Float, ?err:Dynamic) {
		this.exeTime = exeTime;
		// testCase = tc;
		this.exception = err;
	}

	public var failed(get, never):Bool;

	inline function get_failed():Bool
		return (exception != null);

	// public var testCase(default, null): TestCase;
	public var exception(default, null):Null<Dynamic>;
	public var exeTime(default, null):Float;
}

enum TestCaseStatus {
	Passed(extras:Dynamic);
	Failed(error:Dynamic);
}

@:structInit
class TestMetaInit {
	public var async:Bool;
	public var benchmark:Null<Dynamic>;
}