package pmdb.core.ds;

enum Outcome<Result, Error> {
    Success(result: Result);
    Failure(error: Error);
}

class Outcomes {
    public static inline function isSuccess<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Success(_));
    }

    public static inline function isFailure<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Failure(_));
    }

    public static inline function manifest<T, Err>(o: Outcome<T, Err>):T {
        return switch ( o ) {
            case Success(x): x;
            case Failure(e): throw e;
        }
    }
}
