package pmdb.core.schema;

import pmdb.core.ds.Incrementer;
import haxe.EnumFlags;

import haxe.Serializer;
import haxe.Unserializer;

import pmdb.core.schema.Types;
import pmdb.core.schema.SchemaFieldAccessHelper;

/**
	class which represents a field of the schema
**/
class SchemaField {
	public function new(name, type, ?flags) {
		this.name = name;
		this.flags = flags == null ? new EnumFlags() : flags;
		this.type = type;

		this.comparator = try this.etype.getTypedComparator() catch (err:Dynamic) Comparator.cany();
		this.equator = try this.etype.getTypedEquator() catch (err:Dynamic) Equator.anyEq();

		this.incrementer = null;
		if (hasFlag(AutoIncrement)) {
			this.incrementer = new Incrementer();
		}

		this.access = new SchemaFieldAccessHelper(this);
	}

	/* === Methods === */
	public function clone():SchemaField {
		return new SchemaField(name, type, flags);
	}

	public function addFlags(flags:Array<FieldFlag>) {
		for (flag in flags)
			inline addFlag(flag);
	}

	public function addFlag(flag:FieldFlag) {
		flags.set(flag);
		calcEType();
	}

	public function removeFlag(flag:FieldFlag) {
		flags.unset(flag);
		calcEType();
	}

	public inline function hasFlag(flag:FieldFlag):Bool {
		return flags.has(flag);
	}

	public inline function is(flag:FieldFlag):Bool {
		return hasFlag(flag);
	}

	public function getComparator():Comparator<Dynamic> {
		return comparator;
	}

	public function getEquator():Equator<Dynamic> {
		return etype.getTypedEquator();
	}

	public inline function isOmittable():Bool {
		return optional || primary || type.match(TNull(_));
	}

	public function checkValueType(value:Dynamic):Bool {
		return etype.checkValue(value);
	}

	public function toString() {
		return 'FieldDefinition("$name", ...)';
	}

	inline function calcEType() {
		etype = type;
		if (isOmittable())
			etype = etype.makeNullable();
	}

	@:keep
	public function hxSerialize(s:Serializer) {
		s.serialize(name);
		s.serialize(etype);
		s.serialize(flags.toInt());
		var extras:Dynamic = {};
		if (incrementer != null && autoIncrement) {
			extras.inc = incrementer.current();
		}
	}

	@:keep
	public function hxUnserialize(u:Unserializer) {
		name = u.unserialize();
		etype = u.unserialize();
		flags = u.unserialize();
		var extras:Dynamic = u.unserialize();
		if (extras == null)
			return;
		if (extras.inc != null) {
			assert((extras.inc is Int), SchemaError.TypeError(extras.inc.dataTypeOf(), TScalar(TInteger)));
			incrementer = new Incrementer(cast(extras.inc, Int));
		}
	}

	public function toJson():JsonSchemaField {
		return {
			name: this.name,
			type: this.type.print(),
			optional: this.optional,
			unique: this.unique,
			primary: this.primary,
			autoIncrement: this.autoIncrement,
			incrementer: {
				if (autoIncrement && incrementer != null)
					{
						state: incrementer.current()
					};
				else
					null;
			}
		};
	}

	public function extract(o:Dynamic):Null<Dynamic> {
		return Reflect.field(o, name);
	}

	public function assign(o:Dynamic, value:Dynamic):Null<Dynamic> {
		Reflect.setField(o, name, value);
		return value;
	}

	public inline function exists(o:Dynamic):Bool {
		return Reflect.hasField(o, name);
	}

	/**
		obtain the next value in the incrementation
	**/
	public function incr():Int {
		assert(autoIncrement, 'Invalid call to incr()');
		if (incrementer == null) {
			incrementer = new Incrementer();
		}
		return incrementer.next();
	}

	/* === Properties === */
	public var optional(get, never):Bool;

	inline function get_optional()
		return hasFlag(Optional);

	public var unique(get, never):Bool;

	inline function get_unique()
		return hasFlag(Unique);

	public var primary(get, never):Bool;

	inline function get_primary():Bool
		return is(Primary);

	public var autoIncrement(get, never):Bool;

	inline function get_autoIncrement():Bool
		return is(AutoIncrement);

	public var type(default, set):DataType;

	inline function set_type(v:DataType) {
		this.type = v;
		calcEType();
		return type;
	}

	/* === Fields === */
	public var name(default, null): String;
	public var flags(default, null): EnumFlags<FieldFlag>;
	public var comparator(default, null): Null<Comparator<Dynamic>>;
	public var equator(default, null): Null<Equator<Dynamic>>;
	public var access(default, null): SchemaFieldAccessHelper;

	public var etype(default, null): DataType;

	private var incrementer(default, null): Null<Incrementer>;
}

