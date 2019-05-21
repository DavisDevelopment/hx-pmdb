package pmdb.utils.macro.gen;

import pm.*;
import pm.Outcome;
import haxe.ds.Option;

using pm.Arrays;
using pm.Strings;
using pm.Functions;
using pm.Options;
using pmdb.utils.macro.Exprs;

@:diet 
class ClassBuilder {
	public var target(default, null):ClassType;
	var initializeFrom:Array<Field>;
	var constructor:Null<Constructor>;
    var memberList: Array<Member>;
    var macros: Map<String, Field>;
    var superFields: Map<String, Bool>;

    public function new(?target, ?fields) {
        if (target == null)
            target = Context.getLocalClass().get();
        if (fields == null)
            fields = Context.getBuildFields();
        this.initializeFrom = fields;
        this.target = target;
    }

    public function init() {
        if (this.initializeFrom == null) return ;
        var fields = initializeFrom;
        initializeFrom = null;
        this.macros = new Map();
        this.memberList = new Array();
        for (field in fields) {
            if (field.access.has(AMacro)) {
                macros.set(field.name, field);
            }
            else if (field.name == 'new') {
                var m:Member = field;
                //TODO this.constructor = ...
                this.constructor = new Constructor(this, m.getFunction().sure(), m.isPublic, m.pos, field.meta);
            }
            else {
                doAddMember(field);
            }
        }
    }

    public function hasConstructor():Bool {
        init();
        return this.constructor != null;
    }

    public function getConstructor(?fallback: Function) {
        init();
        if (constructor == null) {
            if (fallback != null)
                constructor = new Constructor(this, fallback);
            else {
                var sup = target.superClass;
                while (sup != null) {
                    var cl = sup.t.get();
                    if (cl.constructor != null) {
                        try {
                            var ctor = cl.constructor.get();
                            var ctorExpr = ctor.expr();
                            if (ctorExpr == null) throw 'Super constructor has no expression';
                            var func = Context.getTypedExpr(ctorExpr).getFunction().sure();
                            for (arg in func.args)
                                arg.type = null;
                            func.expr = ECall("super".resolve(), func.getArgIdents()).at();
                            constructor = new Constructor(this, func);
                            if (ctor.isPublic)
                                constructor;//.publish();
                        }
                        catch(e : Dynamic) {
                            if (e == 'assert')
                                throw e;
                            constructor = new Constructor(this, null);
                        }
                        break;
                    }
                    else sup = cl.superClass;
                }
                if (constructor == null) {
                    constructor = new Constructor(this, null);
                }
            }
        }
        return constructor;
    }

    function doAddMember(m:Member, ?front:Bool = false):Member {
        init();

        if (m.name == 'new')
            throw 'Constructor must not be registered as ordinary member';

        if ( front )
            memberList.unshift(m);
        else
            memberList.push(m);

        return m;
    }

    public function addMember(m:Member, ?front:Bool = false):Member {
        doAddMember(m, front);

        if (!m.isStatic && hasSuperField(m.name))
            m.overrides = true;

        return m;
    }

    static public function run(plugins:Array<ClassBuilder->Void>, ?verbose) {
        var builder = new ClassBuilder();
        for (p in plugins)
            p( builder );
        return builder.export(verbose);
    }
    
    public function export(?verbose):Array<Field> {
        if (initializeFrom != null) return null;
        var ret = (constructor == null || target.isInterface) ? [] : [constructor.toHaxe()];
        for (member in memberList) {
            if (member.isBound)
                switch (member.kind) {//TODO: this seems like an awful place for a cleanup. If all else fails, this should go into a separate plugin (?)
                    case FVar(_, _): 
                        if (!member.isStatic)
                            member.isBound = null;
                    case FProp(_, _, _, _):
                        member.isBound = null;
                    default:
                }
            ret.push(member);
        }
        for (m in macros)
            ret.push(m);

        if (verbose)
            for (field in ret)
                Context.warning(new haxe.macro.Printer().printField(field), field.pos);

        return ret;
    }

    public function iterator():Iterator<Member> {
        init();
        return this.memberList.copy().iterator();
    }

    public function hasOwnMember(name:String):Bool {
        init();
        return macros.exists(name) || memberByName(name).isSuccess();
    }
    public function memberByName(name:String, ?pos:Position) {
        init();
        for (m in memberList)
            if (m.name == name)
                return Success( m );
        return pos.makeFailure('unknown member $name');
    }
    public function removeMember(m: Member) {
        init();
        return memberList.remove( m );
    }
    public function hasMember(n: String) {
        return hasOwnMember(n)||hasSuperField(n);
    }

    public function hasSuperField(name: String):Bool {
        if (superFields == null) {
            superFields = new Map();
            var cl = target.superClass;
            while (cl != null) {
                var c = cl.t.get();
                for (f in c.fields.get())
                    superFields.set(f.name, true);
                cl = c.superClass;
            }
        }

        return superFields.get(name);
    }
}

enum FieldInit {
    Value(expr: Expr);
    Arg(?type:ComplexType, ?noPublish:Bool);
    OptArg(?expr:Expr, ?type:ComplexType, ?noPublish:Bool);
}

class Constructor {
	public function new(c, f:Function, ?isPublic:Null<Bool> = null, ?pos:Position, ?meta:Metadata) {
		this.nuStatements = [];
		this.owner = c;
		this.isPublic = isPublic;
		this.pos = pos.sanitize();
		this.onGenerateHooks = [];
		this.args = [];
		this.beforeArgs = [];
		this.afterArgs = [];
		this.meta = meta;

		this.oldStatements = f == null ? [] : {
			for (i in 0...f.args.length) {
				var a = f.args[i];
				if (a.name == '_') {
					afterArgs = f.args.slice(i + 1);
					break;
				}
				beforeArgs.push(a);
			}

			if (f.expr == null)
				[];
			else
				switch (f.expr.expr) {
					case EBlock(exprs): exprs;
					default: oldStatements = [f.expr];
				}
		}
        this.superCall = 
            if (this.oldStatements.length == 0) [].toBlock();
            else switch oldStatements[0] {
                case macro super($a{_}): oldStatements.shift();
                default: [].toBlock();
            }
	}

    private function tempName():String {
        return 'tmp' + HashKey.next();
    }

    public function init(name:String, pos:Position, with:FieldInit, ?options:{ ?prepend:Bool, ?bypass:Bool }) {
        if (options == null) 
            options = {};
        var e = switch with {
            case Arg(t, noPublish):
                if (noPublish != true) 
                    publish();
                args.push({ 
                    name : name, 
                    opt : false,
                    type : t 
                });
                name.resolve(pos);

            case OptArg(e, t, noPublish):
                if (noPublish != true) 
                    publish();
                args.push({ 
                    name : name, 
                    opt : true, 
                    type : t, 
                    value: e 
                });
                name.resolve(pos);
            case Value(e):
                e;
        }
        
        var tmp = tempName();
        var member = owner.memberByName(name).sure();
        
        if (options.bypass && member.kind.match(FProp(_, 'never' | 'set', _, _))) {
            member.addMeta(':isVar');

            addStatement(
                (function () {
                    var fields = [
                        for (f in  (macro this).typeof().sure().getClass().fields.get())
                            f.name => f 
                    ];
                    
                    function setDirectly(t:TypedExpr) {
                        var direct = null;
                        function seek(t: TypedExpr) {
                            switch t.expr {
                                case TField({expr:TConst(TThis)}, FInstance(_, _, f)) if (f.get().name == name):
                                    direct = t;
                                default:
                                    t.iter(seek);
                            }
                        }			
                        seek(t);
                        if (direct == null)
                            pos.contextError('nope');
                        var direct = Context.storeTypedExpr(direct);
                        return macro @:pos(pos) $direct = $e;
                    }
                    
                    return switch fields[name] {
                        case null: 
                            pos.contextError('this direct initialization causes the compiler to do really weird things');
                        case f:
                            switch f.kind {
                                case FVar(_, AccNormal | AccNo):
                                    macro @:pos(pos) this.$name = $e;
                                case FVar(AccNever, AccNever):
                                    macro @:pos(pos) this.$name = $e;
                                case FVar(AccNo | AccNormal, AccNever):
                                    setDirectly(Context.typeExpr(macro @:pos(pos) this.$name));
                                case FVar(AccCall, AccNever):
                                    setDirectly(fields['get_$name'].expr());
                                case FVar(_, AccCall):
                                    setDirectly(fields['set_$name'].expr());
                                default:
                                    pos.contextError('not implemented');
                            }
                    }
                }).bounce(),
                options.prepend
            );
        }
        else {
            addStatement(macro @:pos(pos) this.$name = $e, options.prepend);
        }
    }

    public function publish() {
        if (isPublic == null)
            isPublic = true;
    }

    public function addMeta(n:String, ?params:Array<Expr>, ?pos:Position):Constructor {
        meta.push({
            name: n,
            params: params,
            pos: pos.sanitize()
        });
        return this;
    }

    public function metaSearch(n: String):Array<MetadataEntry> {
        return this.meta.filter(e -> (e.name == n));
    }

    public function getMeta(n: String):Array<Array<Expr>> {
        return metaSearch( n ).map(function(e: MetadataEntry) {
            return
                if (e.params == null) [];
                else e.params;
        });
    }

    public function getArgList():Array<FunctionArg> {
        return beforeArgs.concat(args).concat(afterArgs);
    }

    public function addStatement(e:Expr, ?prepend) {
        if (prepend)
            this.nuStatements.unshift(e)
        else
            this.nuStatements.push(e);
        return this;
    }

    public function addArg(name:String, ?t:ComplexType, ?e:Expr, ?opt = false):Constructor {
        args.push({
            name : name,
            opt : opt || e != null, 
            type : t, 
            value: e 
        });
        return this;
    }
  

    public function toBlock():Expr {
        return [superCall]
            .concat(nuStatements)
            .concat(oldStatements)
            .toBlock(pos);
    }

    public function onGenerate(hook: Function -> Void, prepend=false):Constructor {
        if (prepend)
            onGenerateHooks.unshift(hook);
        else
            onGenerateHooks.push(hook);
        return this;
    }

    public function toHaxe():Field {
        var f:Function = {
            args: beforeArgs.concat(args).concat(afterArgs),
            ret: (macro : Void),
            expr: toBlock(),
            params: []
        };
        for (hook in this.onGenerateHooks)
            hook(f);
        onGenerateHooks = new Array();
        return {
            name: 'new',
            doc : null,
            access : this.isPublic ? [APublic] : [],
            kind :  FFun(f),
            pos : this.pos,
            meta : this.meta,
        };
    }

	public var isPublic(default, null):Null<Bool>;

	var owner:ClassBuilder;
    var pos: Position;
    var meta: Metadata;
	var oldStatements:Array<Expr>;
	var nuStatements:Array<Expr>;
	var onGenerateHooks:Array<Function->Void>;
	var superCall:Expr;
	var beforeArgs:Array<FunctionArg>;
	var args:Array<FunctionArg>;
	var afterArgs:Array<FunctionArg>;
}
