package pmdb.ql.ast.nodes.value;

import tannus.ds.Lazy;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;
import pmdb.ql.ast.Value;

import pmdb.ql.ts.DataType;
import pmdb.core.DotPath;

using pmdb.ql.ts.DataTypes;

/**
  node which represents a field reference on a document
 **/
class ColumnNode extends ValueNode {
    /* Constructor Function */
    public function new(path:Array<DotPathComponent>, type:DataType, ?expr, ?pos) {
        super(expr, pos);

        this.type = type;
        this.path = path;
        this.fieldName = path.join('.');
        this.dotPath = null;

        if (path.length > 1)
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
        var d = this.doc( ctx );
        return dotPath != null ? dotPath.get(cast d, null) : d.get( fieldName );
    }

    override function assign(c:QueryInterp, val:Dynamic) {
        var d = this.doc( c );
        if (dotPath != null) {
            dotPath.set(cast d, val);
        }
        else {
            //TODO "if (typeCheckEnabled && documentIsClassInstance) {...
            #if (row_type_coerce || (python && py_optimizations))
                try {
            #end

            d.set(fieldName, val);

            #if (row_type_coerce || (python && py_optimizations))
                }
                #if python
                catch (err: python.Exceptions.AttributeError) {
                    python.Syntax.arraySet(d.__dict__, fieldName, val);
                }
                #end
                catch (err: Dynamic) {
                    throw err;
                }
            #end
        }
    }

    /**
      ensure that the referenced field is available
     **/
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
        if (dotPath != null) {
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
        else {
            if (doc.get( fieldName ) == null) {
                return doc.set(fieldName, defaultValue);
            }
            else {
                return doc.get( fieldName );
            }
        }
    }

    /**
      build and return a function that will perform the same task as [eval]
     **/
    override function compile() {
        if (dotPath != null) {
            return function(doc:Dynamic, args):Dynamic {
                return dotPath.get( doc );
            }
        }
        else {
            return function(doc:Dynamic, args):Dynamic {
                return Reflect.field(doc, fieldName);
            }
        }
    }

    override function clone():ValueNode {
        return new ColumnNode(path.copy(), type, expr, position);
    }

    override function getExpr():ValueExpr {
        return ValueExpr.make(ECol(fieldName));
    }

/* === Variables === */

    public var path: Array<DotPathComponent>;
    public var fieldName: String;
    public var dotPath: DotPath;
}

typedef DotPathComponent = String;
