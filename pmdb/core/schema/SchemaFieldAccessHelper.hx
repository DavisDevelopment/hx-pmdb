package pmdb.core.schema;

import pmdb.core.schema.Types;

/**
	class which encapsulates and provides convenient methods for accessing fields of stored documents
**/
class SchemaFieldAccessHelper {
	private var field: SchemaField;

	public function new(field) {
		this.field = field;
	}

	public inline function get(doc: Struct):Null<Dynamic> {
		return doc[field.name];
	}

	public inline function set(doc: Struct, value:Dynamic, noCheck = false):Dynamic {
		if (!noCheck)
			assert(field.checkValueType(value), SchemaError.TypeError(value.dataTypeOf(), field.type));
		doc[field.name] = value;
		return value;
	}

	public inline function del(doc: Struct):Bool {
		return doc.remove(field.name);
	}

	public inline function has(doc: Struct):Bool {
		return doc.exists(field.name);
	}

	public function cmp(x:Dynamic, y:Dynamic):Int {
		return field.comparator.compare(x, y);
	}

	public function eq(x:Dynamic, y:Dynamic):Bool {
		return field.equator.equals(x, y);
	}
}