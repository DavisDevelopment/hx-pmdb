package pmdb.storage;

import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.*;

@:forward
abstract Format<A, B> (IFormat<A, B>) from IFormat<A, B> to IFormat<A, B> {
    public static inline function json():Format<Dynamic, String> return JsonFormat.make();
    public static inline function hx():Format<Dynamic, String> return HaxeSerializationFormat.make(); 
}

class JsonFormat implements IFormat<Dynamic, String> {
    function new() {}
    public static function make() return new JsonFormat();
    public function encode(data: Dynamic):String return Json.stringify( data );
    public function decode(data: String):Dynamic return Json.parse( data );
}

class HaxeSerializationFormat implements IFormat<Dynamic, String> {
    function new() {}
    public static function make() return new HaxeSerializationFormat();
    public function encode(data: Dynamic):String return Serializer.run( data );
    public function decode(data: String):Dynamic return Unserializer.run( data );
}

