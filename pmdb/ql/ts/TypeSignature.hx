package pmdb.ql.ts;

import tannus.ds.Anon;
import tannus.ds.Dict;
import tannus.ds.Set;
import tannus.ds.Pair;
import tannus.ds.IComparable;

import pmdb.core.Check;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Error;
import pmdb.core.Arch;
import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;

import haxe.ds.Vector;
import haxe.ds.Either;
import haxe.PosInfos;

import Slambda.fn;
import pmdb.ql.ts.TypeChecks.*;
import Type.ValueType as Vt;
import pmdb.ql.ts.DataType as Dt;

using Type.Type;
using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.MapTools;
using tannus.ds.DictTools;
using tannus.FunctionTools;

class TypeSignature implements IComparable<TypeSignature> {
    /* Constructor Function */
    public function new(accepts:Array<TypeDesc>, returns:TypeDesc):Void {
        //initialize variables
        input = accepts.copy();
        output = returns;
    }

/* === Methods === */

    public function accepts(values: Array<Dynamic>):Bool {
        if (values.empty() || values.length != input.length)
            return false;
        for (i in 0...input.length) {
            if (!input[i].test(values[i]))
                return false;
        }
        return true;
    }

    public function toString():String {
        return input.map( Td.print ).join('->').append('->').append(output.print());
    }

    public function compareTo(other: TypeSignature):Int {
        return switch Td.compareList(input, other.input) {
            case 0: output.compare( other.output );
            case x: x;
        }
    }

    public function copy():TypeSignature {
        return new TypeSignature(input, output);
    }

/* === Statics === */

    public static function parseList(ts: Array<TypeDesc>):TypeSignature {
        return new TypeSignature(ts.slice(0, ts.length - 1), switch ts.takeLast(1)[0] {
            case null: TVoid;
            case x: x;
        });
    }

    static var headString = ~/((?:[?!]*)?(?:(?:[_a-zA-Z][_a-zA-Z0-9]*\.?)+)\s*(?:<(?:.+)>))?\s*(.+)$/gm;
    static var parent = ~/^\s*\((.*)\)\s*$/gm;
    static var comma = ~/\s*,\s*/gm;
    public static function parseString(s: String):TypeSignature {
        if (headString.match( s )) {
            switch [headString.matched(1), headString.matched(2)] {
                case [ret, args]:
                    return new TypeSignature(parseInputString(args), TypeDesc.parseString(ret));
            }
        }
        else {
            throw new Error('Invalid string "$s"');
        }
    }

    static inline function parseInputString(s: String):Array<TypeDesc> {
        return splitInputString( s ).map(x -> TypeDesc.parseString(x));
    }

    static function splitInputString(s: String):Array<String> {
        if (parent.match( s )) {
            return splitInputString(parent.matched( 1 ));
        }
        else {
            return comma.split( s );
        }
    }

/* === Variables === */

    public var input(default, null): Array<TypeDesc>;
    public var output(default, null): TypeDesc;
}

enum ETypeDesc {
    TAny;
    TVoid;
    TBool;
    TFloat;
    TInt;
    TString;
    TClass(c:Class<Dynamic>, allow_subs:Bool);
    TEnum(e: Enum<EnumValue>);

    TNull(td: TypeDesc);
    TAnon(struct: Array<FieldDesc>);
    
    TEither(a:TypeDesc, b:TypeDesc);
    TNot(t: TypeDesc);
    
/* === Abstract Types === */

}

@:forward
@:staticForward
abstract TypeDesc (ETypeDesc) from ETypeDesc to ETypeDesc {
/* === Methods === */

    public inline function test(v: Dynamic):Bool {
        return Td.match(this, v);
    }

    public inline function print(?pretty:Bool):String {
        return Td.print(this);
    }

    public inline function compare(other: TypeDesc):Int {
        return Td.compare(this, other);
    }

    @:op(A | B)
    public inline function or(other: TypeDesc):TypeDesc {
        return either(this, other);
    }

    @:to
    public inline function toString():String {
        return print();
    }

    @:op(A == B)
    public inline function unifyWithDataType(type: DataType):Bool {
        return Td.unifiesWithDataType(this, type);
    }

    @:op(A > B)
    public inline function gt(x: TypeDesc):Bool {
        return compare(x) > 0;
    }

    @:op(A >= B)
    public inline function gte(x: TypeDesc):Bool {
        return compare(x) >= 0;
    }

    @:op(A < B)
    public inline function lt(x: TypeDesc):Bool {
        return compare(x) < 0;
    }

    @:op(A <= B)
    public inline function lte(x: TypeDesc):Bool {
        return compare(x) <= 0;
    }

    @:op(A == B)
    public inline function eq(other: TypeDesc):Bool {
        return this.equals( other );
    }

    @:op(A | B)
    //@:commutative
    public static inline function either(a:TypeDesc, b:TypeDesc):TypeDesc {
        return TEither(a, b);
    }

    @:op(!A)
    public inline function negate():TypeDesc {
        return this;
    }

/* === Factories === */

    @:from
    public static inline function fromClass(c: Class<Dynamic>):TypeDesc {
        return TClass(c, true);
    }

    @:from
    public static inline function fromEnum<T>(e: Enum<T>):TypeDesc {
        return TEnum(cast e);
    }

    @:from
    public static inline function parseString(s: String):TypeDesc {
        return Td.parse( s );
    }

    @:from
    public static inline function fromValueType(vt: Type.ValueType):TypeDesc {
        return Td.describeValueType( vt );
    }

    @:from
    public static inline function fromDataType(dt: pmdb.ql.ts.DataType):TypeDesc {
        return Td.describeDataType( dt );
    }

    public static inline function nullType(t: TypeDesc):TypeDesc return TNull(t);

/* === Constants === */

    public static var anyType:TypeDesc = TAny;
    public static var boolType:TypeDesc = TBool;
    public static var floatType:TypeDesc = TFloat;
    public static var intType:TypeDesc = TInt;
    public static var stringType:TypeDesc = TString;
    public static var voidType:TypeDesc = TVoid;
}

class Td {

    //#if macro

    //public static function typeDescForExpr(e: Expr):TypeDesc {
        //return switch e {
            //case macro $i{type_name}:
                //return parse( type_name );

            //case _:
                //throw 'Unsupported $e';
        //}
    //}

    //public static function typeDescForType(type: Type):TypeDesc {
        //var ctype = TypeTools.toComplexType(type);
        //return switch ctype {
            //case (macro : StdTypes.Bool): TBool;
            //case (macro : StdTypes.Float): TFloat;
            //case (macro : StdTypes.Int): TInt;
            //case (macro : String): TString;
            //case (macro : StdTypes.Dynamic): TAny;
            //case (macro : StdTypes.Void): TVoid;
            //case _: TAny;
        //}
    //}

    //#end

    static var typeString = ~/([?!]*)?((?:[_a-zA-Z][_a-zA-Z0-9]*\.?)+)\s*(?:<(.+)>)?$/gm;
    static var listNotation = ~/^\s*\[(.+)\]\s*$/gm;

    public static function parse(s: String):TypeDesc {
        var eitherDivider = ~/\s*\|\s*/gm;

        s = s.trim();
        if (eitherDivider.match( s )) {
            return eitherDivider.split( s ).map( parse ).reduceInit( TypeDesc.either );
        }
        else if (listNotation.match( s )) {
            trace('WARN: Typed Arrays not yet supported');
            return TClass(Array, true);
        }
        else if (typeString.match( s )) {
            var prefix = typeString.matched( 1 ).nullEmpty(),
                name = typeString.matched( 2 ),
                params = typeString.matched( 3 ).nullEmpty();

            var t:TypeDesc = parseTypeName( name );

            if (params != null) {
                //TODO var typeParams = parseList(params);
            }
            
            if (prefix != null) {
                for (i in 0...prefix.length) {
                    switch prefix.charCodeAt(i) {
                        case '?'.code:
                            t = TNull( t );

                        case '!'.code:
                            t = t.negate();

                        case _:
                            throw new Error();
                    }
                }
            }

            return t;
        }
        else {
            throw new Error('Invalid TypeDesc syntax');
        }
    }

    public static function parseTypeName(n: String):TypeDesc {
        return switch n.toLowerCase() {
            case 'void': TVoid;
            case 'any'|'dynamic': TAny;
            case 'bool'|'boolean': TBool;
            case 'number'|'float'|'double': TFloat;
            case 'int'|'integer': TInt;
            case 'string': TString;
            case 'ereg'|'regexp': TClass(EReg, true);
            case 'bytes': TClass(haxe.io.Bytes, true);
            case 'date': TClass(Date, true);
            case _:
                switch Type.resolveClass( n ) {
                    case null: switch Type.resolveEnum( n ) {
                        case null: throw new Error('"$n" is not a TypeDesc');
                        case e: TEnum(cast e);
                    }
                    case c: TClass(c, true);
                }
        }
    }

    public static function print(t: TypeDesc):String {
        return switch t {
            case TAny: 'Any';
            case TBool: 'Bool';
            case TFloat: 'Float';
            case TInt: 'Int';
            case TString: 'String';
            case TVoid: 'Void';
            case TClass(c, _): c.getClassName();
            case TEnum(e): e.getEnumName();
            case TNull(t): '?' + print(t);
            case TNot(t): '!' + print(t);
            case TEither(x, y): 
                inline function sub(a: TypeDesc):String {
                    return
                    if ((a : ETypeDesc).match(TEither(_, _))) '(${print(a)})'
                    else print(a);
                }
                sub(x).append('|').append(sub(y));

            case TAnon(fields): printStruct(fields);
        }
    }

    public static function printStruct(fields:Array<FieldDesc>, pretty:Bool=false):String {
        var out = new StringBuf();
        inline function w<T>(x: T) out.add( x );

        w('{');
        for (i in 0...fields.length) {
            w( fields[i].name );
            w(':');
            w(print(switch fields[i].type {
                case null: TAny;
                case t: t;
            }));
            if (i < fields.length - 1)
                w(',');
        }
        w('}');
        return out.toString();
    }

    public static inline function match(desc:TypeDesc, value:Dynamic):Bool {
        return switch desc {
            case TAny: is_any( value );
            case TBool: is_boolean( value );
            case TFloat: is_double( value );
            case TInt: is_integer( value );
            case TString: is_string( value );
            case TClass(c, true): is_instance(value, c);
            case TClass(c, false): is_direct_instance(value, c);
            case TEnum(e): is_enumvalue(value, e);
            case TNull(type): is_null(value) || match(type, value);
            case TNot(type): !match(type, value);
            case TEither(a, b): match(a, value) || match(b, value);
            case TAnon([]): is_anon( value );
            case TAnon(fields): matchStruct(value, fields);
            case TVoid: throw new Error('Cannot test against TVoid');
        }
    }

    public static function matchStruct(value:Dynamic, fields:Array<FieldDesc>):Bool {
        if (!is_anon( value ))
            return false;
        for (field in fields) {
            if (!matchField(value, field)) {
                return false;
            }
        }
        return true;
    }

    #if !no_inline_typechecks inline #end
    public static function matchField(field:FieldDesc, o:Dynamic):Bool {
        return switch field {
            case {name:name, type:null}: Reflect.hasField(o, name);
            case {name:name, type:type}: Reflect.hasField(o, name) && match(type, Reflect.field(o, name));
        }
    }

    public static function unifiesWithDataType(left:TypeDesc, right:DataType):Bool {
        inline function uni(l:TypeDesc, r:DataType) return unifiesWithDataType(l, r);

        return switch [left, right] {
            case [TAny, _]: true;
            case [_, TAny]: true;
            case [TBool, TScalar(TBoolean)]: true;
            case [TFloat, TScalar(TDouble|TInteger)]: true;
            case [TInt, TScalar(TInteger)]: true;
            case [TString, TScalar(TString)]: true;
            case [TClass(haxe.io.Bytes, _), TScalar(ScalarDataType.TBytes)]: true;
            case [TClass(Date, _), TScalar(TDate)]: true;
            case [TClass(Array, _), TArray(_)]: true;
            case [TNull(left), TNull(right)]: unifiesWithDataType(left, right);
            case [TEither(_, _), TUnion(ra, rb)]: uni(left, ra)||uni(right, rb);
            case [TEither(a, b), type]: uni(a, type)||uni(b, type);
            case [_, TUnion(a, b)]: uni(left, a)||uni(left, b);
            case [TNot(left), _]: !uni(left, right);
            case [TClass(cl, _), DataType.TClass(cr)]: unifyClasses(cl, cr);
            case [TEnum(e), _]: false;
            case _: false;
        }
    }

    public static function unifyClasses(left:Class<Dynamic>, right:Class<Dynamic>):Bool {
        if (left == right)
            return true;
        while (right != null) {
            if (left == right)
                return true;
            right = right.getSuperClass();
        }
        return false;
    }

    public static function describeValueType(t: Vt):TypeDesc {
        return switch t {
            case Vt.TNull: TNull(TAny);
            case Vt.TBool: TBool;
            case Vt.TFloat: TFloat;
            case Vt.TInt: TInt;
            case Vt.TObject: TAnon(new Array());
            case Vt.TUnknown: TAny;
            case Vt.TClass(c): TClass(c, true);
            case Vt.TEnum(e): TEnum(cast e);
            case Vt.TFunction: throw new Error('No TypeDesc equivalent for TFunction');
        }
    }

    public static function describeDataType(t:Dt, strict:Bool=false):TypeDesc {
        return switch t {
            case Dt.TAny: TAny;
            case Dt.TClass(c): TClass(c, true);
            case Dt.TAnon(null): TAnon(new Array());
            case Dt.TAnon(anon): 
                TAnon(anon.fields
                .map(p -> {
                    name: p.name,
                    type: (x -> p.opt ? TNull(x) : x)(describeDataType( p.type ))//.with(p.opt ? TNull(_) : _)
                }));
            case Dt.TUnion(a, b): TEither(describeDataType(a), describeDataType(b));
            case Dt.TStruct(schema): throw new Error('pigeon chins');
                //TAnon(schema.properties
                //.map(p -> {
                    //name: p.name,
                    //type: (x -> p.opt ? TNull(x) : x)(describeDataType( p.type ))//.with(p.opt ? TNull(_) : _)
                //}));
            case Dt.TNull(t): TNull(describeDataType(t));
            case Dt.TScalar(s): switch s {
                case ScalarDataType.TBoolean: TBool;
                case ScalarDataType.TDouble: TFloat;
                case ScalarDataType.TInteger: TInt;
                case ScalarDataType.TString: TString;
                case ScalarDataType.TBytes: TClass(haxe.io.Bytes, true);
                case ScalarDataType.TDate: TClass(Date, true);
            }
            case Dt.TTuple(_): TClass(Array, true);
            case Dt.TArray(_): TClass(Array, true);

            default: throw 'Cannot describe';
        }
    }

    public static function compareList(a:Array<TypeDesc>, b:Array<TypeDesc>):Int {
        return switch [a, b] {
            case [null, null]: 0;
            case [null, _]: -1;
            case [_, null]: 1;
            case [a, b]:
                if (a.length == b.length) {
                    a.sort( compare );
                    b.sort( compare );
                    var comp:Int = 0;
                    for (i in 0...a.length) {
                        if ((comp = compare(a[i], b[i])) != 0)
                            break;
                    }
                    comp;
                }
                else Reflect.compare(a.length, b.length);
        }
    }

    public static function compare(a:TypeDesc, b:TypeDesc):Int {
        return switch [a, b] {
            case [null, null]: 0;
            case [null, _]: -1;
            case [_, null]: 1;
            case [TClass(a, ab), TClass(b, bb)]:
                switch Reflect.compare(a.getClassName(), b.getClassName()) {
                    case 0:
                        switch [ab, bb] {
                            case [false, false]|[true, true]: 0;
                            case [false, true]: -1;
                            case [true, false]: 1;
                        }

                    case x: x;
                }

            case [TEnum(a), TEnum(b)]:
                if (a == b) 0;
                else Reflect.compare(a.getName(), b.getName());
            case [TNull(a), TNull(b)]: compare(a, b);
            case [TEither(aa, ab), TEither(ba, bb)]:
                switch compare(aa, ba) {
                    case 0: compare(ab, bb);
                    case x: x;
                }

            case [a, b]: Reflect.compare(a.enumIndex(), b.enumIndex());
        }
    }

    public static function compareAnon(a:Array<FieldDesc>, b:Array<FieldDesc>):Int {
        return switch [a, b] {
            case [null, null]: 0;
            case [null, _]: -1;
            case [_, null]: 1;
            case [a, b]:
                if (a.length == b.length) {
                    var comp: Int = 0;
                    for (i in 0...a.length) {
                        if ((comp = compareFieldDesc(a[i], b[i])) != 0)
                            break;
                    }
                    comp;
                }
                else Reflect.compare(a.length, b.length);
        }
    }

    public static inline function compareFieldDesc(a:FieldDesc, b:FieldDesc):Int {
        return switch Reflect.compare(a.name, b.name) {
            case 0: compare(a.type, b.type);
            case x: x;
        }
    }
}

typedef FieldDesc = {
    name: String,
    ?type: TypeDesc
}
