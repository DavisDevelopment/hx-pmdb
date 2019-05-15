package pmdb.utils.macro;

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

        /*
        var subs = [
            'pmdb.core',
            'pmdb.ql'
        ];
        for (pack in subs)
            Compiler.addGlobalMetadata(pack, '@:build(pmdb.utils.macro.PmDbMacros.build())', true, true, false);
        */
        Compiler.addGlobalMetadata('', '@:build(pmdb.utils.macro.PmDbMacros.build())', true, true, false);
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

                    /*TODO
                    if (ctx.hasConstructor())
                        ctx.getConstructor().onGenerate( transform );
                    */
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

typedef ExprLevelRule = {
    function appliesTo(c: ClassBuilder):Bool;
    function apply(e: Expr):Expr;
}