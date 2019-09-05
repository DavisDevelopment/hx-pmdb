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
    public function encodeException(e: Dynamic):String {
        throw e;
    }
    public function decode(data: String):Dynamic return Json.parse( data );
}

class HaxeSerializationFormat implements IFormat<Dynamic, String> {
    public function new() {
        //
    }

    static final _instance:HaxeSerializationFormat = new HaxeSerializationFormat();
    public static inline function make() return _instance;

    public function encode(data: Dynamic):String {
        var s = new Serializer();
        s.useCache = true;
        s.serialize(data);
        return s.toString();
    }

    public function encodeException(error: Dynamic):String {
        var s = new Serializer();
        s.useCache = true;
        s.serializeException(error);
        return s.toString();
    }

    public inline function decode(data: String):Dynamic {
        return Unserializer.run( data );
    }
}

