package pmdb.core.schema;

import pm.Ord;
import pmdb.core.DotPath;
import pmdb.core.ValType;
import pmdb.ql.ast.Value;
import haxe.rtti.CType;

@:keep
enum IndexType {
	Simple(path: DotPath);
	// Compound(types:Array<IndexType>);
	Expression(expr: ValueExpr);
}
interface IndexDefObject {
	function toString():String;
	function getIndexType():IndexType;
	function getStructKey(o: Struct):Dynamic;
	function compareKeys(a:Dynamic, b:Dynamic):Int;

	function isUnique():Bool;
	function isSparse():Bool;
	function createNewInstance():Dynamic;
}

class SimpleIndexDef {
	public var path: DotPath;
}

@:keep
enum abstract IndexAlgo(String) from String to String {
	var AVLIndex;
	var MapIndex;//!Stub
}

typedef TypedAttr = {
	var name(default, null):String;
	var type(default, null):DataType;
}

typedef IndexInit = {
	?name:String,
	?type:ValType,
	?kind:IndexType,
	?algorithm:IndexAlgo,
	?config: IndexConfigurationInit
};

typedef IndexConfigurationInit = {
	?unique: Bool,
	?sparse: Bool
};
typedef IndexConfiguration = {
	final unique: Bool;
	final sparse: Bool;
}

typedef StructClassInfo = {
	proto:Class<Dynamic>,
	?info:Null<Classdef>
}

/* === Json-State Typedefs === */
typedef JsonSchemaField = {
	var name:String;
	var type:String;

	var flags: Int;
	var optional:Bool;
	var unique:Bool;
	var primary:Bool;
	var autoIncrement:Bool;
	@:optional
	var incrementer:Null<{
		state:Dynamic
	}>;
};

/**
	[TODO] represent the entire index-spec here
**/
typedef JsonSchemaIndex = String;

typedef JsonSchemaData = {
	?rowClass:String,
	version:Int,
	fields:Array<JsonSchemaField>,
	indexes:Array<JsonSchemaIndex>
}

typedef Struct = pmdb.core.Object.Doc;

enum SchemaError {
	FieldTypeMismatch(field:SchemaField, want:ValType, have:ValType);
	FieldNotProvided(field:SchemaField);
    TypeError(have:ValType, want:ValType);
}