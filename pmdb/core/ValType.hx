package pmdb.core;

import Type.ValueType as TVType;

import pmdb.ql.ts.DataType;
import pmdb.core.Object;

import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.macro.Expr.ComplexType;

using pmdb.ql.ts.DataTypes;
using tannus.async.OptionTools;

@:forward
abstract ValType (DataType) from DataType  to DataType {
    @:from
    static inline function of(t: DataType):ValType {
        return cast t;
    }

    @:from public static inline function ofClassUnsafe(classType: Class<Dynamic>):ValType return ofClass(classType);

    @:from public static function ofClass<T>(classType: Class<T>):ValType {
        var type = specialClassType( classType );
        if (type == null)
            type = of(TClass( classType ));
        return type;
    }

    @:from public static inline function ofScalar(t: ScalarDataType):ValType {
        return of(TScalar(t));
    }
    static inline function scalar(t: ScalarDataType):ValType return ofScalar( t );

    @:from public static inline function ofArray<T:ValType>(a: Array<T>):ValType {
        return switch ( a.length ) {
            case 0: of(TArray(TAny));
            case 1: of(TArray(cast a[0]));
            default: of(TTuple(cast a));
        }
    }

    @:from public static function ofString(s: String):ValType {
        try {
            return try ofTypeName( s ) catch (e: Dynamic) ofTypeExprString( s );
        }
        catch (e: Dynamic) {
            throw new Error('"$s" does not describe a type');
        }
    }

    public static function ofTypeName(ident: String):ValType {
        return switch (ident.toLowerCase()) {
            case 'int': scalar(TInteger);
            case 'float', 'double': scalar(TDouble);
            case 'bool', 'boolean': scalar(TBoolean);
            case 'str', 'string': scalar(TString);
            case 'bytes', 'binary': scalar(TBytes);
            case 'date', 'datetime', 'timestamp': scalar(TDate);
            case other: throw new Error('"$other" is not a valid type-name');
        }
    }

    @:from
    public static function ofComplexType(ctype: haxe.macro.ComplexType):ValType {
        return switch ctype {
            case ComplexType.TAnonymous(fields): DataType.TAnon(new CObjectType(fields.map(f -> new Property(f.name, switch f.kind {
                //case FVar(null, _): DataType.TUnknown;
                case FVar(ctype, _) if (ctype != null): ofComplexType( ctype );
                case _: DataType.TUnknown;
            }))));
            case ComplexType.TNamed(_, ctype): ofComplexType(ctype);
            case ComplexType.TParent(ctype): ofComplexType(ctype);
            case ComplexType.TOptional(ctype): DataType.TNull(ofComplexType(ctype));
            case ComplexType.TPath(path): ofTypePath( path );

            default: throw 'Unsupported';
        }
    }

    public static function ofTypePath(path: haxe.macro.Expr.TypePath):ValType {
        return switch ( path ) {
            case {name: 'Bool' }|{name: 'StdTypes', sub:'Bool' }: DataType.TScalar( TBoolean );
            case {name: 'Float'}|{name: 'StdTypes', sub:'Float'}: DataType.TScalar( TDouble  );
            case {name: 'Int'  }|{name: 'StdTypes', sub:'Int'  }: DataType.TScalar( TInteger );
            case {name: 'Date' }|{name: 'StdTypes', sub:'Date' }: DataType.TScalar( TDate    );
            case {name: 'String' }|{name: 'StdTypes', sub:'String' }: DataType.TScalar( TString    );
            case {name: 'Bytes' }: DataType.TScalar( TBytes    );

            default: throw '[TODO]';
        }
    }

    public static function ofTypeExprString(s: String):ValType {
        try {
            return of(pmdb.core.query.StoreQueryInterface.globalParser.parseDataType( s ));
        }
        catch (e: Dynamic) {
            throw new Error('"$s" is not a valid type-expression');
        }
    }

    @:from public static inline function ofValueType(t: TVType):ValType {
        return of(t.toDataType());
    }

    @:from public static inline function ofHsExpr(e: hscript.Expr):ValType {
        return of(pmdb.core.query.StoreQueryInterface.globalParser.readDataType( e ));
    }

    private static function specialClassType(cl: Class<Dynamic>):Null<ValType> {
        if (cl == String) {
            return ofScalar(TString);
        }
        else if (cl == haxe.io.Bytes) {
            return ofScalar(TBytes);
        }
        else if (cl == Date) {
            return ofScalar(TDate);
        }
        else if (cl == Array) {
            return of(TArray(TAny));
        }
        else {
            return null;
        }
    }
}
