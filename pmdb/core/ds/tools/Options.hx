package pmdb.core.ds.tools;

import haxe.ds.Option;

import pmdb.core.ds.Lazy;
import pmdb.core.Error;

class Options {
    public static function isSome<T>(o: Option<T>):Bool {
        return o.match(Some(_));
    }

    public static function isNone<T>(o: Option<T>):Bool {
        return o.match(None);
    }

    public static function map<A, B>(o:Option<A>, fn:A -> B):Option<B> {
        return switch o {
            case None: None;
            case Some(a): Some(fn(a));
        }
    }

    public static function flatMap<A, B>(o:Option<A>, fn:A -> Option<B>):Option<B> {
        return switch o {
            case Some(a): fn(a);
            case None: None;
        }
    }

    public static function filter<T>(o:Option<T>, fn:T -> Bool):Option<T> {
        return flatMap(o, x -> fn(x) ? Some(x) : None);
    }

    public static function or<T>(o:Option<T>, defaultValue:T):Option<T> {
        return switch o {
            case None: Some( defaultValue );
            default: o;
        }
    }

    public static function lazyOr<T>(o:Option<T>, defaultValue:Lazy<T>):Option<T> {
        return switch o {
            case None: Some(defaultValue.get());
            default: o;
        }
    }

    public static function getValue<T>(o: Option<T>):Null<T> {
        return switch o {
            case Some(value): value;
            case None: null;
        }
    }

    public static function extract<T>(o:Option<T>, error:Lazy<Dynamic>):T {
        return switch o {
            case Some(v): v;
            case None: throw error.get();
        }
    }
}
