package pmdb.ql.ts;

import tannus.ds.Set;

import pmdb.core.Error;
import pmdb.ql.ts.DataType;
import pmdb.ql.types.DotPath;

//import hscript.Expr;

using StringTools;
using tannus.ds.StringUtils;

class DocumentSchema {
    /* Constructor Function */
    public function new(?className, ?properties) {
        if (className == null) 
            className = 'Document';

        this.className = className;
        this.properties = [];
        if (properties != null) {
            this.properties = properties;
            pack();
        }

        _make = null;
    }

/* === Instance Methods === */

    public function pack() {
        normalize();
    }

    public function make(args: Array<Dynamic>):Dynamic {
        if (_make != null) {
            return Reflect.callMethod(null, _make, args);
        }
        else {
            throw new NotImplementedError();
        }
    }

    public function normalize() {
        if (properties.length == 0)
            throw new Error();

        primary = -1;
        var prop;
        for (i in 0...properties.length) {
            prop = properties[i];
            if (prop.opt && prop.unique)
                throw new Error('Property cannot be sparse AND unique. It makes no sense');

            for (note in prop.annotations) {
                switch note {
                    case APrimary:
                        if (primary != -1)
                            throw new Error('multiple properties cannot be primary');
                        primary = i;

                    case AAutoIncrement:
                        continue;

                    case ARelation(_, _):
                        continue;

                    case ANoIndex:
                        continue;
                }
            }
        }

        if (primary == -1) {
            properties.unshift(new DocumentProperty('_id', TScalar(TString), [APrimary], false, true));
            primary = 0;
        }

        _props = new Map();
        for (prop in properties) {
            _props[prop.name] = prop;
        }
    }

    public function get(name: String):Null<DocumentProperty> {
        return _props[name];
    }

    public function setClass(cl: hscript.Expr.ClassDecl) {
        this.hsClassDecl = cl;
    }

    public function prepare(pmql: String) {
        return pmdb.ql.hsn.QlParser.run( pmql );
    }
/* === Factory Methods === */

    public static function parseString(code: String):DocumentSchema {
        return pmdb.ql.hsn.ModuleParser.run( code );
    }

/* === Computed Fields === */

    public var id(get, never): Property;
    inline function get_id():Property return properties[primary];

/* === Instance Fields === */

    public var className(default, null): String;
    public var properties(default, null): Array<DocumentProperty>;

    public var primary(default, null): Int;

    private var hsClassDecl(default, null): Null<hscript.Expr.ClassDecl> = null;
    private var _make: Null<Dynamic>;
    private var _props: Map<String, DocumentProperty>;
}

class DocumentProperty extends Property {
    /* Constructor Function */
    public function new(name, type, ?annotations:Array<PropertyAnnotation>, sparse=false, unique=false) {
        super(name, type, sparse);

        this.annotations = new Set();
        this.unique = unique;
        if (annotations != null)
            this.annotations.pushMany( annotations );
    }

    public function setName(nname: String) {
        this.name = nname;
    }

    public function setType(ntype: DataType) {
        this.type = ntype;
    }

    public function setSparse(nv: Bool) {
        this.opt = nv;
    }

    public function setUnique(nv: Bool) {
        this.unique = nv;
    }

    public var unique(default, null): Bool;
    public var annotations(default, null): Set<PropertyAnnotation>;
}

enum PropertyAnnotation {
    APrimary;
    AAutoIncrement;
    ANoIndex;
    ARelation(store:String, path:DotPath);
}
