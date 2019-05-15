package pmdb.utils.macro.gen;

#if macro
  import haxe.macro.Context;
  import haxe.macro.Expr;
  
  using pmdb.utils.macro.Exprs;
  //using tink.macro.Exprs;
#end

@:exclude 
class Bouncer {
  #if macro
    static var idCounter = 0;
    static var bounceMap = new Map<Int, Void->Expr>();
    static var outerMap = new Map<Int, Expr->Expr>();
    
    static public function bounceExpr(e:Expr, transform:Expr->Expr) {
      var id = idCounter++,
        pos = e.pos;
      outerMap.set(id, transform);      
      return macro @:pos(e.pos) pmdb.utils.macro.gen.Bouncer.catchBounceExpr($e, $v{id});
    }

    static public function bounce(f:Void->Expr, ?pos:Position) {
      var id = idCounter++;
      pos = pos.sanitize();
      bounceMap.set(id, f);
      return macro @:pos(pos) pmdb.utils.macro.gen.Bouncer.catchBounce($v{id});
    }

    static public function outerTransform(e:Expr, transform:Expr->Expr) {
      var id = idCounter++,
        pos = e.pos;
      outerMap.set(id, transform);
      return macro @:pos(e.pos) pmdb.utils.macro.gen.Bouncer.makeOuter($e).andBounce($v{id});
    }

    static function doOuter(id:Int, e:Expr) {
      return
        if (outerMap.exists(id)) 
          outerMap.get(id)(e);
        else
          Context.currentPos().contextError('unknown id ' + id);  
    }

    static function doBounce(id:Int) {
      return
        if (bounceMap.exists(id)) 
          bounceMap.get(id)();
        else
          Context.currentPos().contextError('unknown id ' + id);  
    }

  #else
    @:noUsing 
    static public function makeOuter<A>(a:A):Bouncer 
      return null;
  #end
  
  @:noUsing 
  macro public function andBounce(ethis:Expr, id:Int) 
    return
      switch (ethis.expr) {
        case ECall(_, params): doOuter(id, params[0]);
        default: ethis.reject();
      }

  @:noUsing 
  macro static public function catchBounce(id:Int) 
    return doBounce(id);
  
  @:noUsing 
  macro static public function catchBounceExpr(e:Expr, id:Int)
    return doOuter(id, e);
}