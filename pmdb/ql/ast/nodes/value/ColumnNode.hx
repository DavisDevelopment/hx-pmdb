package pmdb.ql.ast.nodes.value;

import tannus.ds.Lazy;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;
import pmdb.ql.ast.Value;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.core.DotPath;

using pmdb.ql.ts.DataTypes;

class ColumnNode extends ValueNode {
    /* Constructor Function */
    public function new(path:Array<DotPathComponent>, type:DataType, ?expr, ?pos) {
        super(expr, pos);

        this.type = type;
        this.path = path;
        this.fieldName = path.join('.');
        this.dotPath = new DotPath(path, fieldName);

        addLabel('column');
    }

/* === Methods === */

    override function attachInterp(c: QueryInterp) {
        super.attachInterp( c );
    }

    override function computeTypeInfo() {
        super.computeTypeInfo();

        switch (interp) {
            case {store: null}:
                type = DataType.TAny;

            case {store: _.index(fieldName) => null}:
                type = DataType.TAny;

            case {store: _.index(fieldName) => idx={fieldType: ftype}}:
                addLabel('index', idx);
                type = ftype;

            case null:
                //
        }
    }

    /**
      pull the field-value from [ctx.document]
     **/
    override function eval(ctx: QueryInterp):Dynamic {
        //return ctx.document.dotGet( fieldName );
        return dotPath.get(cast ctx.document, null);
    }

    public function ensure(doc:Object<Dynamic>, ?defaultValue:Dynamic):Dynamic {
        if (defaultValue == null) {
            if (type != null) {
                switch type {
                    case TArray(_):
                        defaultValue = [];

                    case TAnon(null):
                        defaultValue = {};

                    case _:
                        //
                }
            }
        }

        //trace('has(${dotPath.pathName}): ${dotPath.has(cast doc)}');
        if (!dotPath.has(cast doc)) {
            return dotPath.set(cast doc, defaultValue, function(p: Array<String>) {
                if (p.join('.') == fieldName) {
                    return defaultValue;
                }
                else return null;
            });
        }
        else {
            return dotPath.get(cast doc);
        }
    }

    /**
      build and return a function that will perform the same task as [eval]
     **/
    override function compile():QueryInterp->Dynamic {
        return (function(path:DotPath) {
            return (c: QueryInterp) -> path.get( c.document );
        })( path );
    }

    override function clone():ValueNode {
        return new ColumnNode(path.copy(), type, expr, position);
    }

    override function getExpr():ValueExpr {
        return ValueExpr.ECol(fieldName);
    }

/* === Variables === */

    public var path: Array<DotPathComponent>;
    public var fieldName: String;
    public var dotPath: DotPath;
}

typedef DotPathComponent = String;
