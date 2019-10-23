package pmdb.core.schema;

import haxe.DynamicAccess;
import haxe.ds.Option;
import pm.ImmutableList;
import pmdb.core.schema.Types.Struct;

import haxe.macro.Expr;
using haxe.macro.ExprTools;
using pmdb.utils.macro.Exprs;

using StringTools;
using pm.Strings;
using Lambda;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;

@:forward
abstract Path (ImmutableList<PathSegment>) from ImmutableList<PathSegment> {
	public inline function get(o: Struct):Dynamic {
		return _get(this, o);
	}

	public inline function set(o:Struct, value:Dynamic):Dynamic {
		return _set(this, o, value);
	}

    public inline function exists(o: Struct):Bool {
        return _exists(this, o);
    }

    public static function _exists(p:Path, o:Struct):Bool {
        if (o == null)
            return false;
        switch p {
            case Tl:
                throw 'unreachable';

            case Hd(segment, nxt):
                var isLast = nxt.match(Tl);
                if (o.exists(segment)) {
                    if (isLast)
                        return true;
                    return _exists(nxt, Struct.unsafe(o[segment]));
                }
                else return false;
        }
    }

	public static function _set(p:Path, o:Struct, value:Dynamic):Dynamic {
		if (o == null)
			throw 'Null pointer';

		switch p {
			case Hd(key, nxt):
				if (nxt == Tl) {
					o.set(key, value);
					return value;
				}

				var no:Struct = if (o.has(key)) Struct.unsafe(o.get(key)) else null;
				if (no == null) {
					o.set(key, no = {});
				}

				o = Struct.unsafe(no);
				return _set(nxt, o, value);

			case Tl:
				throw 'unexpected $p';
		}
	}

	public static function _get(p:Path, o:Struct):Dynamic {
		return switch p {
			case Hd(_, _) if (o == null):
				throw 'Null pointer error!';

			case ListRepr.Hd(key, nxt):
				var value:Dynamic = switch o.type() {
					case TNull:
						throw 'Null access';
					case TClass(Array):
						if (o.has(key))
							o.get(key);
						else
							_lget(p, (untyped o));

					default:
						o.get(key);
				};
				o = Struct.unsafe(value);
				_get(nxt, o);

			case ListRepr.Tl:
				o;
		}
	}

	public static function _lget(p:Path, o:Struct):Dynamic {
		var arr = (cast o : Array<Struct>);
		return switch p {
			case Tl: throw 'unreachable';
			case Hd(key, nxt): arr.map(x -> _get(p, x));
		}
	}

    @:to
    public function toArray():Array<String> {
        return this.toArray();
    }

	@:to
	public function toString():String {
		return (this : Array<String>).join('.');
	}

	@:from
	public static function parse(s:String):Path {
		return (s.split('.') : ImmutableList<String>);
	}
}

typedef PathSegment = String;

class KvItr {
	var o: Struct;
	var i: Iterator<String>;

	public function new(o) {
		this.o = o;
		this.i = o.keys().iterator();
	}

	public inline function hasNext():Bool
		return i.hasNext();

	public inline function next():{key:String, value:Dynamic} {
		var k = i.next();
		return {
			key: k,
			value: o[k]
		};
	}
}

private typedef Impl = #if js Dynamic #else Dynamic #end;