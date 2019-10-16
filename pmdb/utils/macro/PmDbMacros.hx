package pmdb.utils.macro;

import pm.Pair;
import haxe.ds.Option;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

import pmdb.utils.macro.gen.*;
import pmdb.utils.macro.gen.ClassBuilder;

using haxe.macro.Tools;
using haxe.macro.PositionTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;

using pmdb.utils.macro.Exprs;

using StringTools;
//using tannus.ds.StringUtils;
using Lambda;
//using tannus.ds.ArrayTools;
using pm.Arrays;
using pm.Functions;

class PmDbMacros {
    public static function init() {
        var applySugar = true;
        if (Context.defined('no-pmdb-sugar'))
            applySugar = false;
        
        var args = Sys.args();
        MAIN = 
            switch [args.indexOf('-main'), args.indexOf('-x')] {
                case [-1, -1]: null;
                case [v, -1], [_, v]: args[v + 1];
            }
        
        classLevel.push(makeSyntax(exprLevel.appliedTo)/*, exprLevel.id*/);
        
        Context.onTypeNotFound(function(tp:String) {
            return null;
        });

        Compiler.addGlobalMetadata('', '@:build(pmdb.utils.macro.PmDbMacros.build())', true, true, false);
        Compiler.addGlobalMetadata('pm', '@:expose', true, true, false);
        PmDbMacros.exprLevel.inward.push(new FunctionalExprLevelSyntax(_shouldEnhance, _enhance));
    }

    static function _shouldEnhance(c: ClassBuilder):Bool {
        return true;
    }

    /**
      apply expression-level transforms
     **/
    static function _enhance(e: Expr):Expr {
        final enhanceSwitchStmts = false;

        return switchType( e );
        switch (e) {
            case {expr:expr}:
                switch (expr) {
                    case ExprDef.ESwitch(val, cases, edef) if (edef != null && enhanceSwitchStmts):
                        var newCases = new Array();
                        var defBlock = new Array();
                        for (c in cases) {
                            var newValues = [];
                            for (v in c.values) {
                                switch v {
                                    case macro ($i{name} : $type):
                                    var te = switch type {
                                        case TPath({ pack: parts, name: name, params: params, sub: sub}): 
                                        parts = parts.copy();
                                        parts.push(name);
                                        
                                        if (params != null)
                                            for (p in params)
                                            switch p {
                                                case TPType(macro : Dynamic):
                                                default: v.pos.contextError('Can only use `Dynamic` type parameters in type switching');
                                            }
                                        if (sub != null)
                                            parts.push(sub);
                                            
                                        (macro $p{parts});
                                            
                                        default: 
                                            v.pos.contextError('Invalid type for switching');
                                    }
                                        defBlock.push(macro @:mergeBlock {
                                            if (($val is $te)) {
                                                var $name:$type = cast $val;
                                                ${c.expr};
                                            }
                                        });

                                    case other:
                                        newValues.push( other );
                                }
                            }
                            if (!newValues.empty()) {
                                newCases.push({
                                    expr: c.expr,
                                    values: newValues,
                                    guard: c.guard
                                });
                            }
                        }
                        return ExprDef.ESwitch(val, newCases, macro @:mergeBlock $b{defBlock}).at();

                    case other:
                        return e;
                }

            case other:
                return other;
        }
    }

    static function switchType(e:Expr):Expr {
        return switch e.expr {
            case ESwitch(target, cases, def) if (cases.length > 0):
            switch cases[0].values {
                case [macro ($_: $_)]:
                if (def == null) target.reject('Type switches need default clause');
                for (c in cases) 
                    c.values = 
                    switch c.values {
                        case [macro ($pattern : $t)]:
                            var pos = c.values[0].pos;
                            
                            var te = switch t {
                                case TPath({ pack: parts, name: name, params: params, sub: sub}): 
                                    parts = parts.copy();
                                    parts.push(name);
                                    
                                    if (params != null)
                                        for (p in params)
                                        switch p {
                                            case TPType(macro : Dynamic):
                                            default: pos.contextError('Can only use `Dynamic` type parameters in type switching');
                                        }
                                    if (sub != null)
                                        parts.push(sub);
                                        
                                    (macro $p{parts});
                                
                                default: 
                                    pos.contextError('Invalid type for switching');
                            }
                        
                            [macro @:pos(pos) (if (Std.is(_, $te)) [(_ : $t)] else []) => [$pattern]];
                        
                        case [macro $i{ _ }]:
                            c.values;

                        case values:
                            trace(values);
                            var shouldMutate = values.every(function(e: Expr) {
                                return switch e {
                                    case macro ($pattern : $t): true;
                                    default: false;
                                }
                            });
                            if (shouldMutate) {
                                trace('should mutate');
                                var mutatedValues = values.map(function(e: Expr) {
                                    return switch e {
                                        case macro ($pattern : $t):
                                            var pos = e.pos;
                                            var te = switch t {
                                                case TPath({ pack: parts, name: name, params: params, sub: sub}): 
                                                    parts = parts.copy();
                                                    parts.push(name);
                                                    
                                                    if (params != null)
                                                        for (p in params)
                                                        switch p {
                                                            case TPType(macro : Dynamic):
                                                            default: pos.contextError('Can only use `Dynamic` type parameters in type switching');
                                                        }
                                                    if (sub != null)
                                                        parts.push(sub);
                                                        
                                                    (macro $p{parts});
                                                
                                                default: 
                                                    pos.contextError('Invalid type for switching');
                                            }
                                            (macro @:pos(pos) (if (Std.is(_, $te)) [(_ : $t)] else []) => [$pattern]);

                                        default:
                                            e;
                                    }
                                });
                                mutatedValues;
                            }
                            else values;

                        default: 
                            c.values[0].pos.contextError('u failed');
                    }
                e;
                default: e;
            }
            default: e;
        }
    }

    static function def(flag:String, ?value:String, mutuallyExclude:Iterable<String>) {
        Compiler.define(flag, value);
    }

    static function isdef(flag: String):Bool {
        return Context.defined(flag) && Context.definedValue(flag) != "false";
    }

    public static function build():Array<Field> {
        return switch (Context.getLocalType()) {
            case null: null;
            case TInst(_.get() => c, _):
                // skip over modules in the pmdb.utils.macro.* package
                switch (c.pack) {
                    // skip tink stuff
                    case (_[0] => 'tink'):
                        return null;

                    case (_.slice(0, 3) => abc) if (c.pack.length > 3): switch abc {
                        case ['pmdb', 'utils', 'macro']:
                            return null;
                        default: //
                    }

                    default:
                        //
                }

                var builder = new ClassBuilder();
                var changed = false;
                for (plugin in classLevel)
                    changed = plugin(builder) || changed;
                changed = applyMainTransform(builder)||changed;
                if (changed)
                    builder.export(builder.target.meta.has(':explain'));
                else
                    null;
            default: null;
        }
    }

    @:access(pmdb.utils.macro.gen.ClassBuilder)
    static function applyMainTransform(cl: ClassBuilder):Bool {
        if (cl.target.pack.concat([cl.target.name]).join('.') == MAIN) {
            var main = cl.memberByName('main').sure();
            var f = main.getFunction().sure();
            
            if (f.expr == null) {
                f.expr = macro @:pos(main.pos) {};
            }
          
            for (rule in transformMain) {
                f.expr = rule(f.expr);
            }
        
            return true;
        }
        else {
            return false;
        }
    }

    static function makeSyntax(rule: ClassBuilder -> Option<Expr -> Expr>):ClassBuilder -> Bool {
        return function(ctx: ClassBuilder)
            return switch rule(ctx) {
                case Some(rule):
                    function transform(fn: Function)
                        if (fn.expr != null)
                            fn.expr = rule(fn.expr);

                    
                    if (ctx.hasConstructor())
                        ctx.getConstructor().onGenerate( transform );
                    
                    for (m in ctx)
                        switch m.kind {
                            case FFun(f): transform( f );
                            case FProp(_, _, _, e), FVar(_, e):
                                if (e != null)
                                    e.expr = rule(e).expr;
                        }
                        true;
                case None:
                    false;
            }
    }



    
    static var MAIN:Null<String> = null;
    public static var classLevel:Array<ClassBuilder->Bool> = [];
    public static var transformMain:Array<Expr -> Expr> = [];
    public static var exprLevel(default, null) = new ExprLevelSyntax('::exprLevel');
}

class ExprLevelSyntax {
    public var inward(default, null):Array<ExprLevelRule>;
    public var outward(default, null):Array<ExprLevelRule>;
    public var id(default, null): String;

    public function new(id) {
        this.inward = [];
        this.outward = [];
        this.id = id;
    }

    public function appliedTo(c: ClassBuilder):Option<Expr -> Expr> {
        function getRelevant(rules:Array<ExprLevelRule>)
            return [for (p in rules) if (p.appliesTo(c)) p];
        var inward = getRelevant(inward),
            outward = getRelevant(outward);
        if (inward.length + outward.length == 0)
            return None;
        function apply(e: Expr) {
            return
                if (e == null || e.expr == null) e;
                else switch e.expr {
                    case EMeta({name:':diet'}, _): e;
                    default:
                        for (rule in inward)
                            e = rule.apply( e );
                        e = e.map( apply );
                        for (rule in outward)
                            e = rule.apply( e );
                        e;
                }
        }
        return Some(apply);
    }
}

class FunctionalExprLevelSyntax {
    var applies : ClassBuilder -> Bool;
    var _apply : Expr -> Expr;

    public function new(a, b) {
        this.applies = a;
        this._apply = b;
        //super(id);
    }

    public function appliesTo(c: ClassBuilder):Bool {
        return this.applies( c );
    }
    public function apply(e: Expr):Expr {
        return this._apply( e );
    }
}

typedef ExprLevelRule = {
    function appliesTo(c: ClassBuilder):Bool;
    function apply(e: Expr):Expr;
}