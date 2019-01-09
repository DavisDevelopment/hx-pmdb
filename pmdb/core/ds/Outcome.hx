package pmdb.core.ds;

@:using(pmdb.core.ds.Outcome.Outcomes)
enum Outcome<Result, Error> {
    Success(result: Result);
    Failure(error: Error);
}

class Outcomes {
    /**
      check if the given Outcome is a success
     **/
    public static inline function isSuccess<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Success(_));
    }

    /**
      check if the given Outcome is a failure
     **/
    public static inline function isFailure<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Failure(_));
    }

    /**
      if [o] is a success Outcome, return its value
      else if [o] is a failure Outcome, throw its value
     **/
    public static inline function manifest<T, Err>(o: Outcome<T, Err>):T {
        switch ( o ) {
            case Success( value ): 
                return value;

            case Failure( error ):
                throw error;
        }
    }
}
