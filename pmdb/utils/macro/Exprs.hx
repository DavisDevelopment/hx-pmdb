package pmdb.utils.macro;

import pm.*;
import pm.Outcome;
import haxe.ds.Option;

using pm.Arrays;
using pm.Strings;
using pm.Functions;
using pm.Options;
using pmdb.utils.macro.Exprs;

class Exprs {
	public static function replace(e:Expr, what:Expr, with:Expr):Expr {
		if (e.expr.equals(what.expr)) {
			return macro @:pos(e.pos) $with;
		} else {
			return e.map(E.simpleReplace.bind(_, [what], with));
		}
	}

	public static function extract(e:Expr, pred:Expr->Bool) {
		var found = {e: (null : Null<Expr>)};
		try {
			e.iter(function finder(ex:Expr) {
				if (pred(ex)) {
					found.e = ex;
					throw found;
				}
				ex.iter(finder);
			});
		}
		catch (err: Dynamic) {
			if (err == found) {
				return Success( found.e );
			}
			else {
				//throw err;
				return Failure(err);
			}
		}
		return Failure(null);
	}
	public static function find(e:Expr, f:Expr->Bool) {
		return extract(e, f).toOption();
	}

	public static function has(e:Expr, pred:Expr->Bool):Bool {
		return e.find(pred).isSome();
	}

	public static inline function is(e:Expr, t:ComplexType):Bool {
		return true;
	}

	public static inline function at(e:ExprDef, ?pos:Position):Expr {
		return {expr: e, pos: pos.sanitize()};
	}

	static public function toFields(object:Dynamic<Expr>, ?pos:Position) {
		return EObjectDecl([
			for (field in Reflect.fields(object))
				{
					field: field,
					expr: untyped Reflect.field(object, field)
				}
		]).at(pos);
	}

	static public function toBlock(expressions:Array<Expr>, ?pos) {
		return EBlock(expressions).at(pos);
	}

	static public function field(e:Expr, f:String, ?pos) {
		return EField(e, f).at(pos);
	}

	static public function drill(parts:Array<String>, ?pos:Position, ?target:Expr) {
		if (target == null)
			target = at(EConst(CIdent(parts.shift())), pos);
		for (part in parts) {
			target = field(target, part, pos);
		}
		return target;
	}

	static public inline function resolve(s:String, ?pos) {
		return drill(s.split('.'), pos);
	}

    static public function getFunction(e:Expr) {
        return switch (e.expr) {
            case EFunction(_, func): Success(func);
            default: e.pos.makeFailure('NOT_A_FUNCTION');
        }
    }

	public static function reject(e:Expr, ?reason = 'cannot handle expression') {
		return e.pos.contextError(reason);
	}

	static public function typeof(expr:Expr, ?locals) {
		return
			try {
				//if (locals == null)
				//	locals = scopes[scopes.length - 1];
				if (locals != null) 
					expr = [EVars(locals).at(expr.pos), expr].toBlock(expr.pos);
				Success(Context.typeof( expr ));
			}
			catch (e: haxe.macro.Error) {
				e.pos.makeFailure(e.message);
			}
			catch (e: Dynamic) {
				expr.pos.makeFailure( e );
			}
	}
}

class Funcs {
	static public inline function asExpr(f:Function, ?name, ?pos) {
		return EFunction(name, f).at(pos);
	}

	static public inline function toArg(name:String, ?t, ?opt = false, ?value = null):FunctionArg {
		return {
			name: name,
			opt: opt,
			type: t,
			value: value
		};
	}

	static public inline function func(e:Expr, ?args:Array<FunctionArg>, ?ret:ComplexType, ?params, ?makeReturn = true):Function {
		return {
			args: args == null ? [] : args,
			ret: ret,
			params: params == null ? [] : params,
			expr: if (makeReturn) EReturn(e).at(e.pos) else e
		};
	}

	static public function getArgIdents(f:Function):Array<Expr> {
		var ret = [];
		for (arg in f.args)
			ret.push(arg.name.resolve());
		return ret;
	}
}

class Positions {
	public static function sanitize(pos:Position) {
		return if (pos == null)
			Context.currentPos();
		else
			pos;
	}

	public static function contextError(pos:Position, error:String):Dynamic {
		return Context.fatalError(error, pos);
    }

	static function abortTypeBuild(pos:Position, error:String):Dynamic {
		return throw new Error(error, pos);
    }

	static var errorFunc = contextError;

	static public inline function warning<A>(pos:Position, warning:Dynamic, ?ret:A):A {
		Context.warning(Std.string(warning), pos);
		return ret;
	}

	static public function makeFailure<A>(pos:Position, reason:String):Outcome<A, Error> {
		return Failure(new Error(reason, pos));
    }
} 

class Types {
	static public function asTypePath(s:String, ?params):TypePath {
		var parts = s.split('.');
		var name = parts.pop(), sub = null;
		if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
			sub = name;
			name = parts.pop();
			if (sub == name)
				sub = null;
		}
		return {
			name: name,
			pack: parts,
			params: params == null ? [] : params,
			sub: sub
		};
	}
}

// #if macro
class E {
	public static function toBlock(a:Array<Expr>, ?pos:Position):Expr {
		return EBlock(a).at(pos);
	}

	public static function transform(e:Expr, fn:Expr->Option<Expr>):Expr {
		//
		return e;
	}

	public static function simpleReplace(e:Expr, whats:Array<Expr>, with:Expr):Expr {
		for (what in whats) {
			if (e.expr.equals(what.expr)) {
				return macro @:pos(e.pos) ${with};
			}
		}

		return e.map(simpleReplace.bind(_, whats, with));
	}
}

typedef Bounce = pmdb.utils.macro.gen.Bouncer;

// #end
