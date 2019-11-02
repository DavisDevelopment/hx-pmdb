
import haxe.rtti.CType;
import haxe.xml.Fast;
import haxe.ds.StringMap;

using StringTools;

typedef DeflaterOptions = {
  ?purpose : String,
  ?typeDeflater : Deflater,
  ?stats : haxe.ds.StringMap<Int>,
  ?useEnumIndex : Bool,
  ?useEnumVersioning : Bool,
  ?useCache : Bool,
  ?skipHeader : Bool,
  ?compressStrings : Bool,
};


class DeflatedType {
  public var index : Int;
  public function new() {
    this.index = -1;
  }
}

class DeflatedClass extends DeflatedType {
  public var name : String;
  public var baseClassIndex : Int;
  public var custom : Bool;
  public var version : Int;
  public var startField : Int;
  public var numFields : Int;
  public var potentiallyStale : Bool;

  public function new() {
    super();
    this.name = null;
    this.baseClassIndex = -1;
    this.custom = false;
    this.version = -1;
    this.startField = 0;
    this.numFields = 0;
    this.potentiallyStale = false;
  }
}

class DeflatedEnumValue extends DeflatedType {
  public var construct : String;
  public var enumIndex : Int;
  public var typeIndex : Int;
  public var numParams : Int;

  public function new() {
    super();
    this.construct = null;
    this.enumIndex = -1;
    this.typeIndex = -1;
    this.numParams = 0;
  }
}

class DeflatedEnum extends DeflatedType {
  public var name : String;
  public var version : Int;
  public var useIndex : Bool;

  public function new() {
    super();
    this.name = null;
    this.version = -1;
    this.useIndex = false;
  }
}

/* Our Character codes
  "Z" - Deflater Version (first character)
  "V" - Final Type Info
  "W" - Base Type Info
  "T" - Index to Type Info in the cache
  "|" - Enum Type Info
  "=" - Enum Value Type Info
  "_" - Index to Enum Value Type Info in the cache
  "Y" - Raw String
  "R" - Our Raw String ref
  "S" - no field serialized (Skip)
  "N" - EnumValueMap
*/

  /* prefixes :
    a : array
    b : hash
    c : class
    C : custom
    d : Float
    e : reserved (float exp js)
    E : reserved (float exp cs)
    f : false
    g : object end
    h : array/list/hash end
    i : Int
    j : enum (by index)
    k : NaN
    l : list
    m : -Inf
    M : haxe.ds.ObjectMap
    n : null
    o : object
    p : +Inf
    q : haxe.ds.IntMap
    r : reference
    s : bytes (base64)
    t : true
    u : array nulls
    v : date
    w : enum
    x : exception
    y : urlencoded string
    z : zero
  */

// FIXME - need automagic Entity & Component serialization

class Deflater {

  /* Deflater Version history
  0 - Initial
  1 - Added serialized VERSION with "ZVER" character code,
      Serialize each class instance's full type and version hierarchy
  2 - Add deflater "purpose" string to the stream header
  3 - Change Skip code from E to S (fixes overload with float exp)
  */
  public static inline var VERSION_CODE = "ZVER";
  public static inline var VERSION : Int = 3;

  var buf : StringBuf;
  var cache : Array<Dynamic>;
  var shash : StringMap<Int>;
  var scount : Int;
  var rtree : RadixTree;

  static var BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
  #if neko
  static var base_encode = neko.Lib.load("std","base_encode",2);
  #end

  public var options : DeflaterOptions;

  /**
    The individual cache setting for [this] Deflater instance.
    See USE_CACHE for a complete description.
  **/
  public var useCache(default, null) : Bool;

  /**
    The individual enum index setting for [this] Deflater instance.
  **/
  public var useEnumIndex(default, null) : Bool;

  var thash : StringMap<Array<DeflatedType>>;
  var tcount : Int;
  var farray : Array<String>;

  /**
    Creates a new Deflater instance.
    Subsequent calls to [this].serialize() will append values to the
    internal buffer of this String. Once complete, the contents can be
    retrieved through a call to [this].toString() .
    Each Deflater instance maintains its own cache if [this].useCache is
    true.
  **/
  public function new(?opt:DeflaterOptions) {
    buf = new StringBuf();
    cache = new Array();
    useCache = opt != null ? opt.useCache : false;
    useEnumIndex = opt != null ? opt.useEnumIndex : false;
    shash = new StringMap();
    scount = 0;
    rtree = new RadixTree();

    thash = new StringMap();
    tcount = 0;
    farray = [];

    options = opt != null ? opt : { purpose:null, typeDeflater:null, stats:null };
    if (options.compressStrings == null) {
      options.compressStrings = false;
    }
    if (options.useEnumVersioning == null) {
      options.useEnumVersioning = true;
    }

    // Write our version at the top of the buffer
    if (opt == null || !opt.skipHeader) {
      buf.add(VERSION_CODE);
      buf.add(VERSION);
    }

    // Write the "purpose" string in our deflater options
    serialize(options.purpose);
  }

  function serializeString( s : String ) {
    // mini optimizations to improve codegen for JS
    inline function addInt(buf:StringBuf, x:Int) {
      #if js
        untyped buf.b += x;
      #else
        buf.add(x);
      #end
    }
    inline function addRawStr(buf:StringBuf, x:String) {
      #if js
        untyped buf.b += x;
      #else
        buf.add(x);
      #end
    }

    var td = options.typeDeflater;
    var buf = this.buf;
    if (td != null && td.options.compressStrings) {
      var id = td.rtree.serialize(s, td.buf, false);
      buf.add("~");
      addInt(buf, id);
    } else if (td == null && options.compressStrings) {
      rtree.serialize(s, buf, true);
    } else if (td != null) {
      var x = td.shash.get(s);
      if( x != null ) {
        buf.add("R");
        addInt(buf, x);
        return;
      }
      td.shash.set(s,td.scount);
      buf.add("R");
      addInt(buf, td.scount);
      td.scount++;

      var encodedString = StringTools.urlEncode(s);
      td.buf.add("y");
      addInt(td.buf, encodedString.length);
      td.buf.add(":");
      addRawStr(td.buf, encodedString);
    } else {
      var x = shash.get(s);
      if ( x != null ) {
        buf.add("R");
        addInt(buf, x);
      } else {
        shash.set(s,scount++);
        buf.add("y"); // TODO: use "Y" for raw (non-encoded) strings when possible
        var encodedString = StringTools.urlEncode(s);
        addInt(buf,encodedString.length);
        buf.add(":");
        addRawStr(buf, encodedString);
      }
    }
  }

  public static function inflateTypeInfo(buf:String) : Deflater {
    if (buf != null) {
      var inflater = Inflater.inflateTypeInfo(new StringInflateStream(buf));
      return getTypeInfoFromInflater(inflater);
    } else {
      return new Deflater();
    }
  }

  public static function getTypeInfoFromInflater(inflater:Inflater) @:privateAccess {
    var deflater = new Deflater();
    var i_scache = inflater.scache;
    for (i in 0...i_scache.length) {
      deflater.serializeString(i_scache[i]);
    }
    if (deflater.scount != i_scache.length) {
      throw 'bad length';
    }
    for (i in 0...inflater.tcache.length) {
      var type = inflater.tcache[i];
      if (Std.is(type, InflatedEnum)) {
        var ctype:InflatedEnum = cast type;
        var info = new DeflatedEnum();
        info.name = ctype.name;
        info.index = deflater.tcount++;
        info.version = ctype.serialized_version;
        info.useIndex = ctype.useIndex;

        var mungedName = mungeClassName(ctype.name, ctype.serialized_version);
        if (!deflater.thash.exists(mungedName)) {
          deflater.thash.set(mungedName, []);
        }
        deflater.thash.get(mungedName).push(info);
        writeEnumInfo(deflater, info);
      }
      else if (Std.is(type, InflatedEnumValue)) {
        var ctype:InflatedEnumValue = cast type;
        var enumType = ctype.enumType;
        var info = new DeflatedEnumValue();
        info.construct = ctype.construct;
        info.index = deflater.tcount++;
        info.numParams = ctype.numParams;
        info.enumIndex = ctype.enumIndex;
        info.typeIndex = enumType.index;

        var mungedName = mungeClassName(enumType.name, enumType.serialized_version) + '::${ctype.construct}';
        if (!deflater.thash.exists(mungedName)) {
          deflater.thash.set(mungedName, []);
        }
        deflater.thash.get(mungedName).push(info);
        writeEnumValueInfo(deflater, info);
      }
      else {
        var ctype:InflatedClass = cast type;
        var info = new DeflatedClass();
        info.name = ctype.name;
        info.index = deflater.tcount++;
        info.baseClassIndex = ctype.baseClassIndex;
        info.custom = ctype.custom;
        info.version = ctype.serialized_version;
        info.startField = deflater.farray.length;
        info.numFields = ctype.numFields;
        info.potentiallyStale = true;

        var mungedName = mungeClassName(ctype.name, ctype.serialized_version);
        if (!deflater.thash.exists(mungedName)) {
          deflater.thash.set(mungedName, []);
        }
        deflater.thash.get(mungedName).push(info);

        deflater.buf.add("V");
        writeClassInfo(deflater, info, inflater.fcache.slice(ctype.startField, ctype.startField+ctype.numFields));
      }
    }
    if (deflater.tcount != inflater.tcache.length) {
      throw 'bad length';
    }

    return deflater;
  }

  /**
    Serializes `v`.
    We have special handling for versioned objects, ModelEntity and ModelComponents
    The values of [this].useCache and [this].useEnumIndex may affect
    serialization output.
  **/
  public function serialize( v : Dynamic ) {
    switch( Type.typeof(v) ) {
    case TClass(c):
      serializeClassInstance(v, c);
    case TNull:
      buf.add("n");
    case TInt:
      serializeInt(v);
    case TFloat:
      serializeFloat(v);
    case TBool:
      serializeBool(v);
    case TObject:
      serializeObject(v);
    case TEnum(e):
      if (options.useEnumVersioning) {
        var valueInfo = deflateEnum(v, e);
        deflateEnumValue(v, valueInfo);
      }
      else {
        serializeEnum(v, e);
      }
    case TFunction:
      throw "Cannot serialize function";
    default:
      #if neko
      if( untyped (__i32__kind != null && __dollar__iskind(v,__i32__kind)) ) {
        buf.add("i");
        buf.add(v);
        return;
      }
      #end
      throw "Cannot serialize "+Std.string(v);
    }
  }

  function serializeFields(v) {
    for( f in Reflect.fields(v) ) {
      serializeString(f);
      serialize(Reflect.field(v,f));
    }
    buf.add("g");
  }

  function serializeClassInstance(v:Dynamic, c:Class<Dynamic>) : Void {
    if( #if neko untyped c.__is_String #else c == String #end ) {
      serializeString(v);
      return;
    }
    if( useCache && serializeRef(v) )
      return;
    cache.pop();
    switch( #if (neko || cs) Type.getClassName(c) #else c #end ) {
    case #if (neko || cs) "Array" #else cast Array #end:
      serializeArray(v);
    case #if (neko || cs) "List" #else cast List #end:
      serializeList(v);
    case #if (neko || cs) "Date" #else cast Date #end:
      serializeDate(v);
    case #if (neko || cs) "haxe.ds.StringMap" #else cast haxe.ds.StringMap #end:
      serializeStringMap(v);
    case #if (neko || cs) "haxe.ds.IntMap" #else cast haxe.ds.IntMap #end:
      serializeIntMap(v);
    case #if (neko || cs) "haxe.ds.ObjectMap" #else cast haxe.ds.ObjectMap #end:
      serializeObjectMap(v);
    case #if (neko || cs) "haxe.io.Bytes" #else cast haxe.io.Bytes #end:
      serializeBytes(v);
    case #if (neko || cs) "haxe.ds.EnumValueMap" #else cast haxe.ds.EnumValueMap #end:
      serializeEnumValueMap(v);
    default:
      // do our versioned serialization
      // first find / create our class info
      var info = deflateClass(v, c);
      deflateInstance(v, info);
    }
  }

  inline function serializeArray(v : Dynamic) : Void {
    var ucount = 0;
    buf.add("a");
    #if flash9
    var v : Array<Dynamic> = v;
    #end
    var l = #if (neko || flash9 || php || cs || java) v.length #elseif cpp v.__length() #else v[untyped "length"] #end;
    for( i in 0...l ) {
      if( v[i] == null )
        ucount++;
      else {
        if( ucount > 0 ) {
          if( ucount == 1 )
            buf.add("n");
          else {
            buf.add("u");
            buf.add(ucount);
          }
          ucount = 0;
        }
        serialize(v[i]);
      }
    }
    if( ucount > 0 ) {
      if( ucount == 1 )
        buf.add("n");
      else {
        buf.add("u");
        buf.add(ucount);
      }
    }
    buf.add("h");
  }

  inline function serializeList(v : Dynamic) : Void {
    buf.add("l");
    var v : List<Dynamic> = v;
    for( i in v )
      serialize(i);
    buf.add("h");
  }

  inline function serializeDate(v : Dynamic) : Void {
    var d : Date = v;
    buf.add("v");
    buf.add(d.toString());
  }

  inline function serializeStringMap(v : Dynamic) : Void {
    buf.add("b");
    var v : haxe.ds.StringMap<Dynamic> = v;
    for( k in v.keys() ) {
      serializeString(k);
      serialize(v.get(k));
    }
    buf.add("h");
  }

  inline function serializeIntMap(v : Dynamic) : Void {
    buf.add("q");
    var v : haxe.ds.IntMap<Dynamic> = v;
    for( k in v.keys() ) {
      buf.add(":");
      buf.add(k);
      serialize(v.get(k));
    }
    buf.add("h");
  }

  inline function serializeObjectMap(v : Dynamic) : Void {
    buf.add("M");
    var v : haxe.ds.ObjectMap<Dynamic,Dynamic> = v;
    for ( k in v.keys() ) {
      #if (js || flash8 || neko)
      var id = Reflect.field(k, "__id__");
      Reflect.deleteField(k, "__id__");
      serialize(k);
      Reflect.setField(k, "__id__", id);
      #else
      serialize(k);
      #end
      serialize(v.get(k));
    }
    buf.add("h");
  }

  inline function serializeBytes(v : Dynamic) : Void {
    var v : haxe.io.Bytes = v;
    #if neko
    var chars = new String(base_encode(v.getData(),untyped BASE64.__s));
    #else
    var i = 0;
    var max = v.length - 2;
    var charsBuf = new StringBuf();
    var b64 = BASE64;
    while( i < max ) {
      var b1 = v.get(i++);
      var b2 = v.get(i++);
      var b3 = v.get(i++);

      charsBuf.add(b64.charAt(b1 >> 2));
      charsBuf.add(b64.charAt(((b1 << 4) | (b2 >> 4)) & 63));
      charsBuf.add(b64.charAt(((b2 << 2) | (b3 >> 6)) & 63));
      charsBuf.add(b64.charAt(b3 & 63));
    }
    if( i == max ) {
      var b1 = v.get(i++);
      var b2 = v.get(i++);
      charsBuf.add(b64.charAt(b1 >> 2));
      charsBuf.add(b64.charAt(((b1 << 4) | (b2 >> 4)) & 63));
      charsBuf.add(b64.charAt((b2 << 2) & 63));
    } else if( i == max + 1 ) {
      var b1 = v.get(i++);
      charsBuf.add(b64.charAt(b1 >> 2));
      charsBuf.add(b64.charAt((b1 << 4) & 63));
    }
    var chars = charsBuf.toString();
    #end
    buf.add("s");
    buf.add(chars.length);
    buf.add(":");
    buf.add(chars);
  }

  inline function serializeEnumValueMap(v : Dynamic) : Void {
    buf.add("N");
    var v : haxe.ds.EnumValueMap<Dynamic,Dynamic> = v;
    for ( k in v.keys() ) {
      serialize(k);
      serialize(v.get(k));
    }
    buf.add("h");
  }

  function serializeRef(v) {
    #if js
    var vt = untyped __js__("typeof")(v);
    #end
    for( i in 0...cache.length ) {
      #if js
      var ci = cache[i];
      if( untyped __js__("typeof")(ci) == vt && ci == v ) {
      #else
      if( cache[i] == v ) {
      #end
        buf.add("r");
        buf.add(i);
        return true;
      }
    }
    cache.push(v);
    return false;
  }

  inline function serializeInt(v : Dynamic) : Void {
    if( v == 0 ) {
      buf.add("z");
    } else {
      buf.add("i");
      buf.add(v);
    }
  }

  inline function serializeFloat(v : Dynamic) : Void {
    if( Math.isNaN(v) )
      buf.add("k");
    else if( !Math.isFinite(v) )
      buf.add(if( v < 0 ) "m" else "p");
    else {
      buf.add("d");
      buf.add(v);
    }
  }

  inline function serializeBool(v : Dynamic) : Void {
    buf.add(if( v ) "t" else "f");
  }

  function serializeObject(v : Dynamic) : Void {
    if( useCache && serializeRef(v) )
      return;
    buf.add("o");
    serializeFields(v);
  }

  inline function serializeEnum(v : Dynamic, e : Enum<Dynamic>) : Void {
    if (!useCache || !serializeRef(v)) {
      cache.pop();
      buf.add(useEnumIndex?"j":"w");
      serializeString(Type.getEnumName(e));
      #if neko
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v.index);
      } else
        serializeString(new String(v.tag));
      buf.add(":");
      if( v.args == null )
        buf.add(0);
      else {
        var l : Int = untyped __dollar__asize(v.args);
        buf.add(l);
        for( i in 0...l )
          serialize(v.args[i]);
      }
      #elseif flash9
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v.index);
      } else
        serializeString(v.tag);
      buf.add(":");
      var pl : Array<Dynamic> = v.params;
      if( pl == null )
        buf.add(0);
      else {
        buf.add(pl.length);
        for( p in pl )
          serialize(p);
      }
      #elseif cpp

      #if (haxe_ver >= 3.3)
      var v:cpp.EnumBase = cast v;
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v._hx_getIndex());
      } else
        serializeString(v._hx_getTag());
      buf.add(":");
      var pl : Array<Dynamic> = v._hx_getParameters();
      if( pl == null )
        buf.add(0);
      else {
        buf.add(pl.length);
        for( p in pl )
          serialize(p);
      }
      #else
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v.__Index());
      } else
        serializeString(v.__Tag());
      buf.add(":");
      var pl : Array<Dynamic> = v.__EnumParams();
      if( pl == null )
        buf.add(0);
      else {
        buf.add(pl.length);
        for( p in pl )
          serialize(p);
      }
      #end

      #elseif php
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v.index);
      } else
        serializeString(v.tag);
      buf.add(":");
      var l : Int = untyped __call__("count", v.params);
      if( l == 0 || v.params == null)
        buf.add(0);
      else {
        buf.add(l);
        for( i in 0...l )
          serialize(untyped __field__(v, __php__("params"), i));
      }
      #elseif (java || cs)
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(Type.enumIndex(v));
      } else
        serializeString(Type.enumConstructor(v));
      buf.add(":");
      var arr:Array<Dynamic> = Type.enumParameters(v);
      if (arr != null)
      {
        buf.add(arr.length);
        for (v in arr)
          serialize(v);
      } else {
        buf.add("0");
      }

      #else
      if( useEnumIndex ) {
        buf.add(":");
        buf.add(v[1]);
      } else
        serializeString(v[0]);
      buf.add(":");
      var l = v[untyped "length"];
      buf.add(l - 2);
      for( i in 2...l )
        serialize(v[i]);
      #end
      cache.push(v);
    }
  }

  /**
    Return the String representation of [this] Deflater.
    The exact format specification can be found here:
    http://haxe.org/manual/serialization/format
  **/
  public function toString() {
    return buf.toString();
  }

  /**
    Serializes `v` and returns the String representation.
    This is a convenience function for creating a new instance of
    Deflater, serialize `v` into it and obtain the result through a call
    to toString().
  **/
  public static function run( v : Dynamic , ?options : DeflaterOptions ) {
    var s = new Deflater(options);
    s.serialize(v);
    return s.toString();
  }

  inline static function hasCustom(cls : Class<Dynamic>) : Bool {
    return Lambda.has(Type.getInstanceFields(cls), "hxSerialize");
  }

  #if !flash9 inline #end static function callPre(value : Dynamic) {
    if( #if flash9 try value.preSerialize != null catch( e : Dynamic ) false #elseif (cs || java) Reflect.hasField(value, "preSerialize") #else value.preSerialize != null #end  ) {
      return true;
    }
    else
      return false;
  }

  #if !flash9 inline #end static function callPost(value : Dynamic) {
    if( #if flash9 try value.postSerialize != null catch( e : Dynamic ) false #elseif (cs || java) Reflect.hasField(value, "postSerialize") #else value.postSerialize != null #end  ) {
      return true;
    }
    else
      return false;
  }

  // Serialize type info for this class (and any base class types that haven't yet been serialized)
  public function deflateClass(value : Dynamic, cls:Class<Dynamic>) : DeflatedClass {
    return deflateClassImpl(value, cls, true);
  }

  inline static function mungeClassName(className:String, version:Int) : String {
    return '$className##$version';
  }

  function typeDiffersFromDeflatedClass(tdeflater:Deflater, cls:Class<Dynamic>, value:Dynamic, classVersion:Int, purpose:String, deflated:DeflatedClass) : Bool {
    // did custom change?
    var freshHasCustom = hasCustom(cls);
    if (deflated.custom != freshHasCustom) {
      throw '${Type.getClassName(cls)} hasCustom changed, but no version bump?!';
    }

    if( !freshHasCustom ) {
      var fields = TypeUtils.getSerializableFields(cls, value, purpose);
      if (fields.length != deflated.numFields) {
        if (fields.length < deflated.numFields) {
          throw ('${Type.getClassName(cls)} has less fields than previously deflated version:\n' +
            'Old version: ${tdeflater.farray.slice(deflated.startField, deflated.startField+deflated.numFields)}\n' +
            'New version: $fields');
        }
        return true;
      }

      var fstart = deflated.startField;
      for (i in 0...fields.length) {
        var fname = tdeflater.farray[fstart+i];
        if (fields[i] != fname) {
          return true;
        }
      }
    }

    var superClass = Type.getSuperClass(cls);
    var freshBaseClassIndex = -1;
    if (superClass != null) {
      var superClassInfo = deflateClassImpl(value, superClass, false);
      freshBaseClassIndex = superClassInfo.index;
    }

    if (deflated.baseClassIndex != freshBaseClassIndex) {
      throw '${Type.getClassName(cls)} changed base class, but no version bump?!';
    }

    return false;
  }

  public function deflateClassImpl(value : Dynamic, cls:Class<Dynamic>, isLastType:Bool) : DeflatedClass {
    var tdeflater;
    if ( options.typeDeflater != null ) {
      // store type info seperately if requested.
      tdeflater = options.typeDeflater;
    } else {
      tdeflater = this;
    }

    var classVersion = 0;
    var di: Dynamic = Reflect.field(cls, "___deflatable_version");
    // If it's not currently a Deflatable, it has version 0
    if (di != null) {
      classVersion = Reflect.callMethod(cls, di, []);
    }

    var name = Type.getClassName(cls);

    var mungedName = mungeClassName(name, classVersion);
    var types = tdeflater.thash.get(mungedName);
    var existingClass:DeflatedClass = null;
    if ( types != null ) {
      // get the most recent typeInfo serialized for this class
      existingClass = cast types[types.length-1];
      // If it was created from a potentially stale type info, check if it is up-to-date
      if (existingClass.potentiallyStale) {
        if (!typeDiffersFromDeflatedClass(tdeflater, cls, value, classVersion, options.purpose, existingClass)) {
          existingClass.potentiallyStale = false;
        } else {
          // Something changed in the type, but the version wasn't bumped.
          // (This is allowed if the type added a field.)
          // This means we need to store a new type information entry.
          existingClass = null;
        }
      }
    }

    if (existingClass != null) {
      // Only write the index if we need it to identify this instance
      if (isLastType) {
        buf.add("T");
        buf.add(existingClass.index);
        buf.add(":");
      }
      return existingClass;
    }

    // Recursively deflate our class hierachy, starting with the base class
    var superClass = Type.getSuperClass(cls);
    var superClassInfo = null;
    if (superClass != null) {
      superClassInfo = deflateClassImpl(value, superClass, false);
    }

    var info = new DeflatedClass();
    info.index = tdeflater.tcount++;
    info.baseClassIndex = superClassInfo != null ? superClassInfo.index : -1;
    info.name = name;
    info.custom = hasCustom(cls);
    info.version = classVersion;
    info.startField = tdeflater.farray.length;
    info.numFields = 0;
    info.potentiallyStale = false;

    if (!(superClassInfo == null || info.custom == superClassInfo.custom)) {
      throw 'Cannot serialize ${info.name}, does not share serialization method with ${superClassInfo.name}';
    }

    var fields : Array<String> = null;
    if( !info.custom ) {
      fields = TypeUtils.getSerializableFields(cls, value, options.purpose);
      info.numFields = fields.length;
    }

    if (!tdeflater.thash.exists(mungedName)) {
      tdeflater.thash.set(mungedName, []);
    }
    tdeflater.thash.get(mungedName).push(info);

    if (isLastType) {
      tdeflater.buf.add("V");
    } else {
      tdeflater.buf.add("W");
    }

    writeClassInfo(tdeflater, info, fields);

    if ( options.typeDeflater != null && isLastType ) {
      buf.add("T");
      buf.add(info.index);
      buf.add(":");
    }

    return info;
  }

  static function writeClassInfo(target:Deflater, info:DeflatedClass, fields:Array<String>) : Void {
    target.serializeString(info.name);
    target.buf.add(":");
    target.serialize(info.baseClassIndex);
    target.buf.add(":");
    target.serialize(info.version);
    target.buf.add(":");
    target.serialize(info.custom);
    target.buf.add(":");
    if (!info.custom) {
      if (fields.length != info.numFields) {
        throw 'bad length';
      }
      target.farray = target.farray.concat(fields);
      target.buf.add(info.numFields);
      target.buf.add(":");
      for (fname in fields)
        target.serializeString(fname);
      target.buf.add(":");
    }
  }

  public function verifyFields(v: Dynamic, info : DeflatedClass) {
    if ( info.custom ) {
      return;
    }

    var farray = ( options.typeDeflater != null ) ? options.typeDeflater.farray : this.farray;
    var cls = Type.getClass(v);

    var fields = TypeUtils.getSerializableFields(cls, v, options.purpose);

    var same = false;
    if (fields.length == info.numFields) {
      same = true;
      for (i in 0...fields.length) {
        if (fields[i] != farray[info.startField+i]) {
          same = false;
        }
      }
    }

    if (!same) {
      trace(info.name);
      trace(fields);
      for (i in 0...info.numFields) {
        trace(farray[info.startField+i]);
      }
    }
  }

  public function deflateInstance(v : Dynamic, info : DeflatedClass) {
    var startPos = 0;
    if ( options.stats != null ) {
      startPos = buf.toString().length;
    }

    cache.push(v);

    if (callPre(v)) {
      v.preSerialize(this);
    }

    if (info.custom) {
      v.hxSerialize(this);
    }
    else {
      var farray = ( options.typeDeflater != null ) ? options.typeDeflater.farray : this.farray;
      var fidx = info.startField;
      for (x in 0...info.numFields) {
        var fname = farray[fidx + x];
        if (#if js Reflect.hasField(v, fname) #else true #end) {
          var fval = #if js untyped v[fname] #else Reflect.field(v,fname) #end;
          serialize(fval);
        } else {
          // No data to serialize for this field
          buf.add("S");
        }
      }
    }

    buf.add("g");

    if (callPost(v)) {
      v.postSerialize();
    }

    if ( options.stats != null ) {
      var endPos = buf.toString().length;
      var name = Type.getClassName(Type.getClass(v));
      if ( !options.stats.exists(name) ) {
        options.stats.set(name, 0);
      }
      options.stats.set(name, options.stats.get(name) + (endPos-startPos));
    }
  }

  function deflateEnum(value : Dynamic, enm:Enum<Dynamic>) : DeflatedEnumValue {
    var tdeflater = options.typeDeflater != null ? options.typeDeflater : this;

    var enumName = Type.getEnumName(enm);
    var enumVersion = 0;

    var upgradeClassName = '${enumName}_deflatable';
    var upgradeClass:Class<Dynamic> = Type.resolveClass(upgradeClassName);
    var di: Dynamic = upgradeClass == null ? null : Reflect.field(upgradeClass, "___deflatable_version");
    // If it's not currently a Deflatable, it has version 0
    if (di != null) {
      enumVersion = Reflect.callMethod(upgradeClass, di, []);
    }

    var constructor = Type.enumConstructor(value);
    var mungedEnumName = mungeClassName(enumName, enumVersion);
    var mungedValueName = '$mungedEnumName::$constructor';
    var types = tdeflater.thash.get(mungedValueName);
    var existingValueInfo:DeflatedEnumValue = types != null ? cast types[types.length-1] : null;
    if (existingValueInfo != null) {
      // Only write the index if we need it to identify this instance
      buf.add("_");
      buf.add(existingValueInfo.index);
      buf.add(":");
      return existingValueInfo;
    }

    // lookup the enum type info
    types = tdeflater.thash.get(mungedEnumName);
    var existingInfo:DeflatedEnum = types != null ? cast types[types.length-1] : null;
    if (existingInfo == null) {
      var info = existingInfo = new DeflatedEnum();
      info.index = tdeflater.tcount++;
      info.name = enumName;
      info.version = enumVersion;
      info.useIndex = this.useEnumIndex;

      if (!tdeflater.thash.exists(mungedEnumName)) {
        tdeflater.thash.set(mungedEnumName, []);
      }
      tdeflater.thash.get(mungedEnumName).push(info);

      writeEnumInfo(tdeflater, info);
    }

    var info = new DeflatedEnumValue();
    info.index = tdeflater.tcount++;
    info.typeIndex = existingInfo.index;
    info.construct = existingInfo.useIndex ? null : constructor;
    info.enumIndex = Type.enumIndex(value);
    info.numParams = TypeUtils.getEnumParameterCount(enm, value);

    if (!tdeflater.thash.exists(mungedValueName)) {
      tdeflater.thash.set(mungedValueName, []);
    }
    tdeflater.thash.get(mungedValueName).push(info);

    writeEnumValueInfo(tdeflater, info);

    if ( options.typeDeflater != null ) {
      buf.add("_");
      buf.add(info.index);
      buf.add(":");
    }
    return info;
  }

  static function writeEnumInfo(target:Deflater, info:DeflatedEnum) : Void {
    target.buf.add("|");
    target.serializeString(info.name);
    target.buf.add(":");
    target.buf.add(info.version);
    target.buf.add(":");
    target.serialize(info.useIndex);
    target.buf.add(":");
  }

  static function writeEnumValueInfo(target:Deflater, info:DeflatedEnumValue) : Void {
    target.buf.add("=");
    target.serialize(info.construct);
    target.buf.add(":");
    target.buf.add(info.typeIndex);
    target.buf.add(":");
    target.buf.add(info.enumIndex);
    target.buf.add(":");
    target.buf.add(info.numParams);
    target.buf.add(":");
  }

  public function deflateEnumValue(v : Dynamic, valueInfo : DeflatedEnumValue) {
    if (!useCache || !serializeRef(v)) {
      cache.pop();

      var params = Type.enumParameters(v);
      var numParams = params == null ? 0 : params.length;
      if (valueInfo == null || valueInfo.numParams != numParams) {
        throw 'bad length';
      }

      for (x in 0...numParams) {
        serialize(params[x]);
      }
      cache.push(v);
    }
  }
}

class RemovedTypes
{
  /** Set of types that have been removed from code, but could appear in old unserialized data.
   *  If these types are encountered, then their contents are skipped and the data is returned as null.
   */
  public static var names:Map<String,Bool> = new Map();

  public static function add(fullPath:String) : Void {
    names[fullPath] = true;
  }
}

/***************************************************************
================================================================
======================= RadixTree module =======================
================================================================
***************************************************************/

// https://en.m.wikipedia.org/wiki/Compact_prefix_tree
class RadixTree {
  public var root(default, null):RadixNode;
  var m_map:Array<RadixNode>;
  var shash:Map<String,Int>;
  var scount:Int;
  var scache:Array<String>;
  var lastOffset:Int = 0;

  public function new() {
    m_map = [];
    shash = new Map();
    scount = 0;
    scache = [];
    this.root = createNode("");
  }

  public function serialize(word:String, buf:StringBuf, includeExisting:Bool) : Int {
    for (child in this.root.children) {
      var id = serialize_(word, 0, child, buf, includeExisting);
      if (id >= 0) {
        return id;
      }
    }

    var newBranch = createNode(word);
    newBranch.parent = this.root;
    this.root.children.push(newBranch);

    buf.add("!");
    addInt(buf, this.root.id-this.lastOffset);
    lastOffset = this.root.id;
    buf.add(":");
    addInt(buf, newBranch.data.length);
    buf.add(":");
    addStr(buf, newBranch.data);

    return newBranch.id;
  }

  function serialize_(word:String, start:Int, cur:RadixNode, buf:StringBuf, includeExisting:Bool) : Int {
    var num = findConsecutiveMatch(word, start, cur.data);
    if (num == 0) {
      return -1;
    }

    if (num < cur.data.length) {
      var old = cur.data;
      // We matched part of the current node, we need to create a split
      var split = createNode(cur.data.substr(0,num));
      var newSuffix = createNode(word.substr(start+num));

      split.children = [cur, newSuffix];
      cur.data = cur.data.substr(num);

      cur.parent.children.remove(cur);
      split.parent = cur.parent;
      split.parent.children.push(split);
      cur.parent = split;
      newSuffix.parent = split;

      buf.add("#");
      addInt(buf, cur.id-this.lastOffset);
      this.lastOffset = cur.id;
      buf.add(":");
      addInt(buf, num);
      buf.add(":");
      addInt(buf, newSuffix.data.length);
      buf.add(":");
      addStr(buf, newSuffix.data);

      return newSuffix.id;
    } else if (start+num != word.length) {
      // Recurse
      for (child in cur.children) {
        var id = serialize_(word, start+num, child, buf, includeExisting);
        if (id >= 0) {
          return id;
        }
      }

      // Insert a new branch
      var newSuffix = createNode(word.substr(start+num));
      newSuffix.parent = cur;
      cur.children.push(newSuffix);
      buf.add("!");
      addInt(buf, cur.id-this.lastOffset);
      this.lastOffset = cur.id;
      buf.add(":");
      addInt(buf, newSuffix.data.length);
      buf.add(":");
      addStr(buf, newSuffix.data);

      return newSuffix.id;
    } else {
      if (includeExisting) {
        buf.add('~');
        addInt(buf, cur.id-this.lastOffset);
        this.lastOffset = cur.id;
      }
      return cur.id;
    }
  }

  public function getID(name:String) : Int {
    var cur = this.root;
    var len = name.length;
    var matched = 0;
    while (cur != null && matched < len) {
      var next = null;
      for (child in cur.children) {
        var n = findConsecutiveMatch(name, matched, child.data);
        if (n != 0 && n == child.data.length) {
          next = child;
          break;
        }
      }

      if (next != null) {
        cur = next;
        matched += next.data.length;
      } else {
        cur = null;
      }
    }

    return cur != null && matched == len ? cur.id : -1;
  }

  // @:access(Macro.Inflater)
  public function unserialize(inflater:Inflater, relative:Bool) : String @:privateAccess {
    if (!relative) {
      this.lastOffset = 0;
    }

    var stm = inflater.stream;
    var code = stm.readByte();
    if (code == '#'.code) {
      // split
      var id = inflater.readDigits()+this.lastOffset;
      this.lastOffset = id;

      var cur = m_map[id];
      if (stm.readByte() != ':'.code) {
        throw 'invalid RadixTree code';
      }

      var num = inflater.readDigits();
      if (stm.readByte() != ':'.code) {
        throw 'invalid RadixTree code';
      }

      var len = inflater.readDigits();
      if (stm.readByte() != ':'.code) {
        throw 'invalid string length';
      }

      var str = stm.readString(len);

      var split = createNode(cur.data.substr(0,num));
      var newSuffix = createNode(str);
      cur.data = cur.data.substr(num);

      split.children = [cur, newSuffix];

      cur.parent.children.remove(cur);
      split.parent = cur.parent;
      split.parent.children.push(split);
      cur.parent = split;
      newSuffix.parent = split;

      return uptree(newSuffix);
    } else if (code == '!'.code) {
      // insert
      var id = inflater.readDigits()+this.lastOffset;
      this.lastOffset = id;
      var cur = m_map[id];
      if (stm.readByte() != ':'.code) {
        throw 'invalid RadixTree code';
      }

      var len = inflater.readDigits();
      if (stm.readByte() != ':'.code) {
        throw 'invalid string length';
      }
      var str = stm.readString(len);

      var newSuffix = createNode(str);
      newSuffix.parent = cur;
      cur.children.push(newSuffix);

      return uptree(newSuffix);
    } else if (code == '~'.code) {
      var id = inflater.readDigits()+this.lastOffset;
      this.lastOffset = id;
      return uptree(m_map[id]);
    } else {
      throw 'unrecognized code $code';
    }
  }

  public inline function lookup(id:Int) : String {
    var node = m_map[id];
    if (node == null) {
      throw 'invalid radix node: $id';
    }
    return uptree(node);
  }

  function uptree(start:RadixNode) : String {
    if (start.cached != null) {
      return start.cached;
    }

    var nodes = [];
    var cur = start;
    var root = this.root;
    while (cur != root) {
      nodes.push(cur);
      cur = cur.parent;
    }
    var i = nodes.length;
    var buf = new StringBuf();
    while (i-- > 0) {
      buf.add(nodes[i].data);
    }

    return start.cached=buf.toString();
  }

  inline function createNode(part:String) : RadixNode {
    var node = new RadixNode(part, m_map.length);
    m_map.push(node);
    return node;
  }

  inline function findConsecutiveMatch(a:String, start:Int, b:String) : Int {
    var minLen = a.length-start;
    if (b.length < minLen) minLen = b.length;

    var matches = 0;
    for (i in 0...minLen) {
      if (a.fastCodeAt(start+i) == b.fastCodeAt(i)) {
        ++matches;
      } else {
        break;
      }
    }
    return matches;
  }

  // mini optimizations to improve codegen for JS
  static inline function addInt(buf:StringBuf, x:Int) {
    #if js
      untyped buf.b += x;
    #else
      buf.add(x);
    #end
  }
  static inline function addStr(buf:StringBuf, x:String) {
    #if js
      untyped buf.b += x;
    #else
      buf.add(x);
    #end
  }
}

private class RadixNode
{
  public var id:Int;
  public var data:String;
  public var cached:String;
  public var parent:RadixNode;
  public var children:Array<RadixNode>;

  public function new(data:String, id:Int) {
    this.cached = null;
    this.id = id;
    this.data = data;
    this.parent = null;
    this.children = [];
  }
}

//use this for macros or other classes
class Macro {

}

/** Stream implementation based on a string input */
class StringInflateStream implements IInflateStream
{
  var buf:String;
  var pos:Int;
  var offset:Int;
  var length:Int;

  public function new(buf:String, offset:Int=0, length:Int=-1) : Void {
    this.buf = buf;
    this.length = length < 0 ? buf.length : length;
    this.offset = offset;
    this.pos = offset;
  }

  public function dispose() this.buf = null;
  public function getPos() return pos-offset;
  public function seekTo(pos:Int) this.pos = pos+offset;
  public function peekByte() return Inflater.fastCodeAt(buf, pos);
  public function readByte() return Inflater.fastCodeAt(buf, pos++);
  public function getLength() return length;
  public function eof() return pos-offset >= length;
  public function toString() return this.buf;

  public function readString(len:Int) : String {
    var s = buf.substr(pos, len);
    pos += len;
    return s;
  }

  public function sub(offset:Int, length:Int) : IInflateStream {
    return new StringInflateStream(this.buf, offset+this.offset, length);
  }
}

interface IInflateStream
{
  function getPos() : Int;
  function seekTo(pos:Int) : Void;
  function peekByte() : Int;
  function readByte() : Int;
  function readString(len:Int) : String;
  function getLength() : Int;
  function eof() : Bool;
  function sub(offset:Int, length:Int) : IInflateStream;
  function dispose() : Void;
}

#if cs
typedef TypeKey = cs.system.Type;
#else
typedef TypeKey = String;
#end

class TypeUtils
{
  @:meta(System.ThreadStatic)
  static var s_cachedRTTI : Map<TypeKey, TypeTree> = null;
  @:meta(System.ThreadStatic)
  static var s_instanceFieldCache : Map<String, Array<String>> = null;
  @:meta(System.ThreadStatic)
  static var s_staticFieldCache : Map<String, Array<String>> = null;

  /** Given an iterator, return an iterable. */
  public static inline function toIterable<T>(iterator:Iterator<T>) : Iterable<T> {
    return { iterator : function() { return iterator; } };
  }

  /** Return a string key for a class, suitable for Map */
  public static inline function keyForClass(cls:Class<Dynamic>) : TypeKey {
    #if cs
    return cs.Lib.toNativeType(cls);
    #else
    return Type.getClassName(cls);
    #end
  }

  /** Return true if the instance field on the specified class has the specified metadata */
  public static function fieldHasMeta(cls:Class<Dynamic>, field:String, attribute:String) : Bool {
    var meta = fieldMeta(cls, field);
    if ( meta != null ) {
      return Reflect.hasField(meta, attribute);
    }
    return false;
  }

  public static function fieldMeta(cls:Class<Dynamic>, field:String) : Dynamic {
    var meta = haxe.rtti.Meta.getFields(cls);
    if ( meta != null ) {
      if ( Reflect.hasField(meta, field) ) {
        return Reflect.field(meta, field);
      } else {
        var superCls = Type.getSuperClass(cls);
        if ( superCls != null ) {
          return fieldMeta(superCls, field);
        }
      }
    }
    return null;
  }

  public static function getSerializableFields(cls:Class<Dynamic>, instance:Dynamic, purpose:String) : Array<String> {
    if (s_instanceFieldCache == null) {
      s_instanceFieldCache = new Map();
    }

    var key = '${Type.getClassName(cls)}###$purpose';
    var result = s_instanceFieldCache[key];
    if (result == null) {
      var classFields = getSerializableFieldsByClass(cls, purpose);
      result = classFields.filter(function (fname) {
        return !Reflect.isFunction(Reflect.field(instance, fname));
      });
      // ensure that fields are always ordered the same
      result.sort(Reflect.compare);

      s_instanceFieldCache[key] = result;
    }
    return result;
  }

  public static function hasSerializableField(instance:Dynamic, field:String, classFields:Array<String>) : Bool {
    for (cachedField in classFields) {
      if (field == cachedField && !Reflect.isFunction(Reflect.field(instance, field))) {
        return true;
      }
    }
    return false;
  }

  // Returns the data we can get about serializable fields from just the type
  public static function getSerializableFieldsByClass(cls:Class<Dynamic>, purpose:String) : Array<String> {
    if (s_staticFieldCache == null) {
      s_staticFieldCache = new Map();
    }

    var key = '${Type.getClassName(cls)}###$purpose';
    var cached = s_staticFieldCache[key];
    if (cached != null) {
      return cached;
    }

    // Look for filters defined on this class and its base classes
    // Uses the pattern _CLASSNAME_shouldSerializeField
    var filters = [];
    var filterClass = cls;
    while (filterClass != null) {
      var fields = Type.getClassFields(filterClass);
      var className = Type.getClassName(filterClass).split(".").pop();
      var filterName = '_${className}_shouldSerializeField';
      if (Lambda.has(fields, filterName)) {
        filters.push({field:Reflect.field(filterClass, filterName), cls:filterClass});
      }
      filterClass = Type.getSuperClass(filterClass);
    }

    // Get the instance fields and filter out the stuff we don't serialize
    var rawFields = Type.getInstanceFields(cls);
    var filteredFields = [];
    for (fname in rawFields) {
      // Don't serialize any field that has a getter
      if (Lambda.has(rawFields, 'get_$fname')) {
        continue;
      }

      // filter by purpose
      // | purpose | @nostore(X) | serialized? |
      // ---------------------------------------
      // |  null   |  null       |     no      |
      // |  null   |  client     |     no      |
      // |  client |  null       |     no      |
      // |  client |  client     |    yes      |
      // |  client |  datastore  |     no      |
      //
      var meta = TypeUtils.fieldMeta(cls, fname);
      if (meta != null && Reflect.hasField(meta, "nostore")) {
        var nostore : Array<String> = meta.nostore;
        if (nostore == null || purpose == null) {
          continue;
        }

        if (purpose != null && !Lambda.has(nostore, purpose)) {
          continue;
        }
      }

      if (Lambda.exists(filters, function(filter) return !Reflect.callMethod(filter.cls, filter.field, [cls, fname]))) {
        continue;
      }

      filteredFields.push(fname);
    }

    s_staticFieldCache[key] = filteredFields;
    return filteredFields;
  }

  public static function getFieldTypeInfo(cls:Class<Dynamic>, fieldName:String) : haxe.rtti.CType {
    var classKey = keyForClass(cls);
    if ( s_cachedRTTI == null ) {
      s_cachedRTTI = new Map();
    }
    var infos = s_cachedRTTI[classKey];
    if ( infos == null ) {
      var rtti = Reflect.field(cls, "__rtti");
      if (rtti == null) throw 'Class ${Type.getClassName(cls)} does not have RTTI info';
      var x = Xml.parse(rtti).firstElement();
      if (x == null) throw 'Class ${Type.getClassName(cls)} does not have RTTI info';
      s_cachedRTTI[classKey] = infos = new haxe.rtti.XmlParser().processElement(x);
    }
    switch ( infos ) {
      case TClassdecl(classDef):
        for ( f in classDef.fields ) {
          if ( f.name == fieldName ) {
            return f.type;
          }
        }

        if ( classDef.superClass != null ) {
          var superClass = Type.resolveClass(classDef.superClass.path);
          if (superClass == null) {
            throw 'expected super class';
          }
          return getFieldTypeInfo(superClass, fieldName);
        } else {
          return null;
        }

    default:
      throw "Unexpected: " + infos;
    }

    return null;
  }

  public static function getEnumParameterCount(e:Enum<Dynamic>, v : Dynamic) : Int {
    #if neko
      return v.args == null ? 0 : untyped __dollar__asize(v.args);
    #elseif flash9
      var pl : Array<Dynamic> = v.params;
      return pl == null ? 0 : pl.length;
    #elseif cpp

    #if (haxe_ver >= 3.3)
      var v:cpp.EnumBase = cast v;
      var pl : Array<Dynamic> = v._hx_getParameters();
      return pl == null ? 0 : pl.length;
    #else
      var pl : Array<Dynamic> = v.__EnumParams();
      return pl == null ? 0 : pl.length;
    #end

    #elseif php
      var l : Int = untyped __call__("count", v.params);
      return l == 0 || v.params == null ? 0 : l;
    #elseif (java || cs)
      var arr:Array<Dynamic> = Type.enumParameters(v);
      return arr == null ? 0 : arr.length;
    #else
      var l = v[untyped "length"];
      return l - 2;
    #end
  }
}

/***************************************************************
================================================================
======================== FastReflect module =======================
================================================================
***************************************************************/

/**
 *  Faster setProperty API using for precached field name hashes (in C#)
 *  Usage: call/store hash() for property name
 *  Call setProperty using both the field name and field hash.
 */
class FastReflect
{
  static var fieldIds:Array<Int> = [];
  static var fields:Array<String> = [];

  /** Copied from Haxe std/cs/internal/FieldLookup.hx */
  private static inline function doHash(s:String):Int {
    var acc = 0; //alloc_int
    for (i in 0...s.length)
    {
      var tmp:Int = 223 * (acc >> 1) + s.charCodeAt(i);
      acc = ((tmp) << 1);
    }

    return acc >>> 1; //always positive
  }

  /** Copied from Haxe std/cs/internal/FieldLookup.hx */
  public static function hash(s:String):Int {
    if (s == null) return 0;

    var key = doHash(s);

    //start of binary search algorithm
    var ids = fieldIds;
    var min = 0;
    var max = ids.length;

    while (min < max)
    {
      var mid = Std.int(min + (max - min) / 2); //overflow safe
      var imid = ids[mid];
      if (key < imid)
      {
        max = mid;
      } else if (key > imid) {
        min = mid + 1;
      } else {
        var field = fields[mid];
        if (field != s)
          return ~key; //special case
        return key;
      }
    }
    //if not found, min holds the value where we should insert the key
    ids.insert(min, key);
    fields.insert(min, s);
    return key;
  }

  #if cs
    #if debug
    @:functionCode('
      try {
        if (o is haxe.lang.IHxObject)
          ((haxe.lang.IHxObject) o).__hx_setField(field, hash, value, true);
        else if (haxe.lang.Runtime.slowHasField(o, "set_" + field))
          haxe.lang.Runtime.slowCallField(o, "set_" + field, new Array<object>(new object[]{value}));
        else
          haxe.lang.Runtime.slowSetField(o, field, value);
      } catch ( System.Exception e ) {
        UnityEngine.Debug.LogError("Failed to set property " + field + " on " + o.ToString() + " to value " + value.ToString() + ": " + e.ToString());
        throw e;
      }
    ')
    #else
    @:functionCode('
      if (o is haxe.lang.IHxObject)
        ((haxe.lang.IHxObject) o).__hx_setField(field, hash, value, true);
      else if (haxe.lang.Runtime.slowHasField(o, "set_" + field))
        haxe.lang.Runtime.slowCallField(o, "set_" + field, new Array<object>(new object[]{value}));
      else
        haxe.lang.Runtime.slowSetField(o, field, value);
    ')
    #end
  #end
  public #if (!cs) inline #end static function setProperty(o:Dynamic, field:String, hash:Int, value:Dynamic) : Void {
    #if debug
    try {
    #end
      Reflect.setProperty(o, field, value);
    #if debug
    } catch (e:Dynamic) {
      throw 'Failed to set property $field on $o to $value: $e';
    }
    #end
  }

  #if cs
  static var s_registeredClasses = new Map<TypeKey, Bool>();
  #end

  /** Faster version of Type.createEmptyInstance that caches whether class is a Haxe-generated class. */
  public inline static function createEmptyInstance( cl : Class<Dynamic> ) : Dynamic {
    #if cs
      var classKey = TypeUtils.keyForClass(cl);
      var isHX = s_registeredClasses.exists(classKey);
      if ( !isHX && untyped __cs__("cl.GetInterface(\"IHxObject\") != null") ) {
        s_registeredClasses.set(classKey, true);
        isHX = true;
      }

      return isHX ?
        untyped __cs__("
          cl.InvokeMember(\"__hx_createEmpty\",
            System.Reflection.BindingFlags.Static|
            System.Reflection.BindingFlags.Public|
            System.Reflection.BindingFlags.InvokeMethod|
            System.Reflection.BindingFlags.DeclaredOnly,
            null,
            null,
            new object[]{}
          )"
        ) : Type.createInstance(cl, []);
    #else
      return Type.createEmptyInstance(cl);
    #end
  }
}

/***************************************************************
================================================================
======================== Inflater module =======================
================================================================
***************************************************************/

typedef InflaterOptions = {
  ?typeInflater : Inflater,
  ?skipHeader : Bool,
};

class InflatedType {
  public var index : Int;
  public function new() {
    this.index = -1;
  }
}

class InflatedClass extends InflatedType {
  public var name : String;
  public var type : Class<Dynamic>;
  public var baseClassIndex : Int;
  public var custom : Bool;
  public var serialized_version : Int;
  public var startField : Int;
  public var numFields : Int;
  public var classUpgrade : Dynamic;
  public var requiresUpgrade : Bool;
  public var hasPostUnserialize : Int; // -1 if not yet determined
  #if debug
  public var currentFields : Array<String>;
  #end

  public function new() {
    super();
    this.name = null;
    this.type = null;
    this.baseClassIndex = -1;
    this.custom = false;
    this.serialized_version = -1;
    this.startField = 0;
    this.numFields = 0;
    this.classUpgrade = null;
    this.requiresUpgrade = false;
    this.hasPostUnserialize = -1;
  }
}

class InflatedEnumValue extends InflatedType {
  public var construct : String;
  public var enumIndex : Int;
  public var enumType : InflatedEnum;
  public var numParams : Int;

  public function new() {
    super();
    this.construct = null;
    this.enumIndex = -1;
    this.enumType = null;
    this.numParams = 0;
  }
}

class InflatedEnum extends InflatedType {
  public var name : String;
  public var type : Enum<Dynamic>;
  public var serialized_version : Int;
  public var upgradeFunc : Dynamic;
  public var upgradeClass : Class<Dynamic>;
  public var requiresUpgrade : Bool;
  public var useIndex : Bool;

  public function new() {
    super();
    this.name = null;
    this.type = null;
    this.serialized_version = -1;
    this.upgradeFunc = null;
    this.upgradeClass = null;
    this.requiresUpgrade = false;
    this.useIndex = false;
  }
}

@:allow(serialization.Deflater)
class Inflater {
  var deflaterVersion : Int;

  static var BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
  #if neko
  static var base_decode = neko.Lib.load("std","base_decode",2);
  #end

  static var CODES = null;

  static function initCodes() {
    var codes =
      #if flash9
        new flash.utils.ByteArray();
      #else
        new Array();
      #end
    for( i in 0...BASE64.length )
      codes[fastCodeAt(BASE64,i)] = i;
    return codes;
  }

  public var options(default, null) : InflaterOptions;
  var stream : IInflateStream;
  var length : Int;
  var cache : Array<Dynamic>;
  var scache : Array<String>;
  var rtree : RadixTree;
  #if neko
  var upos : Int;
  #end

  var typeInflater : Inflater;
  var tcache : Array<InflatedType>;
  var fcache : Array<String>;
  var hcache : Array<Int>;
  var ecache : Map<String, {info:InflatedEnum, values:Array<InflatedEnumValue>}>;
  var skipCounter : Int;

  public var purpose(default, null) : String;
  public var entities : Array<Dynamic>;

  // The code for skipping would conflict with floats ("E").
  // If infalating version <= 2, then skipCode should be set back to "E".
  var skipCode : Int = "S".code;

  /**
    Creates a new Inflater instance with the specified input stream.

    This does not parse all of this stream immediately, but it reads in the stream's version.  The rest iss parsed
    only when calls to [this].unserialize are made.

    Each Inflater instance maintains its own cache.
    We have special handling for versioned objects
  **/
  public function new(stream:IInflateStream, ?opt:InflaterOptions) {
    this.options = opt;
    this.stream = stream;
    length = stream.getLength();
    #if neko
    upos = 0;
    #end
    cache = new Array();
    ecache = new Map();

    if ( opt != null && opt.typeInflater != null ) {
      typeInflater = opt.typeInflater;
      tcache = typeInflater.tcache;
      fcache = typeInflater.fcache;
      hcache = typeInflater.hcache;
      scache = typeInflater.scache;
      rtree = typeInflater.rtree;
    } else {
      tcache = [];
      fcache = [];
      hcache = [];
      scache = [];
      rtree = new RadixTree();
    }
    entities = [];

    if (opt != null && opt.skipHeader) {
      this.deflaterVersion = Deflater.VERSION;
    } else {
      // Look up our version at the top of the buffer
      var prevPos = stream.getPos();
      var code = stream.readString(Deflater.VERSION_CODE.length);
      if (code == Deflater.VERSION_CODE) {
        this.deflaterVersion = readDigits();
      } else {
        this.stream.seekTo(prevPos);
        // Version 0 is from before we serialized our version
        this.deflaterVersion = 0;
      }
    }

    if (opt != null && opt.typeInflater != null && opt.typeInflater.deflaterVersion != this.deflaterVersion) {
      if (!((opt.typeInflater.deflaterVersion == 2 && this.deflaterVersion == 1) ||
            (opt.typeInflater.deflaterVersion == 3 && this.deflaterVersion == 1) ||
            (opt.typeInflater.deflaterVersion == 3 && this.deflaterVersion == 2))) {
        throw 'Type inflater version was ${opt.typeInflater.deflaterVersion}, but ours is $deflaterVersion';
      }
    }

    // Get our purpose string
    if (this.deflaterVersion >= 2) {
      this.purpose = unserialize();
    }

    // old streams used a different skip code
    if (this.deflaterVersion < 3) {
      this.skipCode = "E".code;
    }
  }

  public static inline function fastCodeAt(s:String, i:Int) : Int {
    #if cs
      return untyped s[i];
    #else
      return StringTools.fastCodeAt(s, i);
    #end
  }

  // Used by custom serialization to get the version of the class that's being inflated
  public function getClassVersion(cls:Class<Dynamic>, instanceClassIndex:Int) : Int {
    var classIndex = instanceClassIndex;
    while (true) {
      if (classIndex == -1) {
        break;
      }
      var inflatedClass:InflatedClass = cast tcache[classIndex];
      if (inflatedClass.type == cls) {
        return inflatedClass.serialized_version;
      }
      classIndex = inflatedClass.baseClassIndex;
    }
    throw 'Cannot find class version for $cls in given index';
    return -1;
  }

  public static function inflateTypeInfo(stream:IInflateStream) : Inflater {
    var inflater = new Inflater(stream);
    var result = [];
    var len = stream.getLength();
    while ( inflater.stream.getPos() != len ) {
      switch (inflater.stream.readByte()) {
      case "V".code:
        inflater.inflateClassInfo(true);
      case "W".code:
        inflater.inflateClassInfo(false);
      // string cache
      case "Y".code:
        inflater.unserializeRawString();
      case "y".code:
        inflater.unserializeURLEncodedString();
      case '!'.code, '#'.code, '~'.code:
        stream.seekTo(stream.getPos()-1);
        inflater.rtree.unserialize(inflater, true);
      case "|".code:
        inflater.inflateEnumInfo();
      case "=".code:
        inflater.inflateEnumValueInfo();
      default:
        throw 'unexpected code in typeinfo';
      }
    }
    return inflater;
  }

  function inflateClassInfo(lastClassType:Bool) : InflatedClass {
    var info : InflatedClass = new InflatedClass();
    info.startField = fcache.length;
    info.name = unserialize();
    if( stream.readByte() != ":".code ) {
      throw "Invalid type format (cls)";
    }
    info.type = Type.resolveClass(info.name);
    if( info.type == null ) {
      // Handle private becoming public
      // (Haxe inserts a "_" in private classes)
      var parts = info.name.split(".");
      if (parts.length > 1) {
        var pi = parts.length-2;
        var pack = parts[pi];
        if (pack.startsWith("_")) {
          parts.splice(pi, 1);
          var newName = parts.join('.');
          info.type = Type.resolveClass(newName);
          if (info.type != null) {
            info.name = newName;
          }
        }
      }
    }

    // Base Class Index
    if (this.deflaterVersion >= 1) {
      info.baseClassIndex = unserialize();
      if ( stream.readByte() != ":".code ) {
        throw "Invalid type format (baseClassIndex)";
      }
    } else {
      // No baseClassIndex before v1
      info.baseClassIndex = -1;
    }

    // Version
    if (this.deflaterVersion >= 1) {
      info.serialized_version = unserialize();
    } else {
      // We used to serialize strings for versions, but we hadn't started using the version tag so it should be null
      var oldVersion:String = unserialize();
      if (oldVersion != null) {
        throw 'oldVersion != null';
      }
      info.serialized_version = 0;
    }
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (version)";
    }


    info.custom = unserialize();
    if( stream.readByte() != ":".code ) {
      throw "Invalid type format (custom)";
    }

    if (!info.custom) {
      info.numFields = readDigits();
      if( stream.readByte() != ":".code ) {
        throw "Invalid type format (fields)";
      }
      for (f in 0...info.numFields) {
        var fieldName:String = unserialize();
        fcache.push(fieldName);
        hcache.push(FastReflect.hash(fieldName));
      }
      if( stream.readByte() != ":".code ) {
        throw "Invalid type format (fields end)";
      }
    }

    info.index = tcache.length;
    tcache.push(info);

    if (info.type != null) {
      // See if we need to upgrade this class
      var currentVersion = 0;
      var di: Dynamic = Reflect.field(info.type, "___deflatable_version");
      if (di != null) {
        currentVersion = Reflect.callMethod(info.type, di, []);
      }

      if (info.serialized_version != currentVersion) {
        // Find the upgrade function we need to call for this class
        var fnName = '_upgrade_version';
        info.classUpgrade = Reflect.field(info.type, fnName);
        if (info.classUpgrade == null && !info.custom) {
          throw 'Please implement ${fnName} for class ${info.name}, need to upgrade from version ${info.serialized_version}';
        }
      }

      // An instance needs an upgrade if this or any base class needs a class upgrade
      var hierarchyInfo = info;
      while (true) {
        if (hierarchyInfo.classUpgrade != null || hierarchyInfo.requiresUpgrade) {
          info.requiresUpgrade = true;
          break;
        }
        if (hierarchyInfo.baseClassIndex == -1) {
          break;
        }
        hierarchyInfo = cast tcache[hierarchyInfo.baseClassIndex];
      }

      // Populate the info with a cache of fields that belong to the current version of this class
      #if debug
      info.currentFields = TypeUtils.getSerializableFieldsByClass(info.type, purpose);
      #end
    } else {
      if (this.skipCounter == 0 && !RemovedTypes.names.exists(info.name)) {
        throw 'Class not found ${info.name}';
      }
    }

    if (lastClassType) {
      return info;
    } else {
      // There's another class type ahead of us that we need to inflate
      switch (stream.readByte()) {
      case "V".code:
        return inflateClassInfo(true);
      case "W".code:
        return inflateClassInfo(false);
      default:
        throw 'Invalid type format - missing version info for lastClassType';
        return null;
      }
    }
  }

  public function inflateClass() : InflatedClass {
    switch( stream.readByte() ) {
    default:
      throw "Invalid instance type";
      return null;
    case "T".code:
      var t = readDigits();
      if( t < 0 || t >= tcache.length )
        throw "Invalid type reference";
      if( stream.readByte() != ":".code )
        throw "Invalid type reference format";
      return cast tcache[t];
    case "V".code:
      return inflateClassInfo(true);
    case "W".code:
      return inflateClassInfo(false);
    }
  }

  public function skipInstanceOf(type:InflatedClass) : Void {
    if (type.custom) {
      if (type.type == null) {
        throw 'Cannot skip an instance of a type that no longer exists and had custom serialization: ${type.name}';
      }
      var o = Type.createEmptyInstance(type.type);
      o.hxUnserialize(this, type.index);
    } else {
      // unserialize each field and throw it away.
      this.skipCounter++;
      for (x in 0...type.numFields) {
        if (stream.peekByte() != this.skipCode) {
          unserialize();
        } else {
          // Just skip the S and move on
          stream.readByte();
        }
      }
      if( stream.readByte() != "g".code ) {
        throw 'Invalid class data for instance of ${type.name} at pos ${stream.getPos()-1} in buf $stream';
      }

      this.skipCounter--;
    }
  }

  static function callPost(value : Dynamic) {
    if( #if flash9 try value.postUnserialize != null catch( e : Dynamic ) false #elseif (cs || java) Reflect.hasField(value, "postUnserialize") #else value.postUnserialize != null #end  ) {
      return true;
    }
    else
      return false;
  }

  @:keep public inline function inflateInstance(o:Dynamic, info : InflatedClass) : Dynamic {
    cache.push(o);
    if (info.custom) {
      o.hxUnserialize(this, info.index);
    } else {
      // Only allocate a field map if we have to upgrade this instance
      var fieldMap = (info.requiresUpgrade ? new Map<String, Dynamic>() : null);

      for (x in 0...info.numFields) {
        var fname = fcache[info.startField + x];
        var fhash = hcache[info.startField + x];
        if (stream.peekByte() != this.skipCode) {
          var val = unserialize();

          if (info.requiresUpgrade) {
            if (fieldMap == null) {
              throw 'fieldMap == null';
            }
            // Set up our field map if we need to upgrade
            fieldMap.set(fname, val);
          } else {
            // No upgrade, just set the field directly
            #if debug
              if (!TypeUtils.hasSerializableField(o, fname, info.currentFields)) {
                throw "Cannot set unserialized field: " + fname + " for type: " + info.name;
              }
            #end
            FastReflect.setProperty(o, fname, fhash, val);
          }
        } else {
          // Just skip the S and move on
          stream.readByte();
        }
      }

      // Upgrade our field map and then set values on the instance
      if (info.requiresUpgrade) {
        if (fieldMap == null) {
          throw 'fieldMap == null';
        }
        // Call update on each class in the hierarchy
        upgradeFieldMap(o, fieldMap, info);

        for (fname in fieldMap.keys()) {
          #if debug
            if (!TypeUtils.hasSerializableField(o, fname, info.currentFields)) {
              throw "Cannot set upgraded field: " + fname + " for type: " + info.name;
            }
          #end
          Reflect.setProperty(o, fname, fieldMap[fname]);
        }
      }

    }

    if( stream.readByte() != "g".code ) {
      throw 'Invalid class data for instance of ${info.name} at pos ${stream.getPos()-1} in buf $stream';
    }

    if (info.hasPostUnserialize == -1) {
      info.hasPostUnserialize = callPost(o) ? 1 : 0;
    }
    if (info.hasPostUnserialize == 1) {
      o.postUnserialize();
    }

    return o;
  }

  function upgradeFieldMap(o:Dynamic, fieldMap:Map<String, Dynamic>, info:InflatedClass) : Void {
    // First upgrade the fields on any base classes
    if (info.baseClassIndex != -1) {
      upgradeFieldMap(o, fieldMap, cast tcache[info.baseClassIndex]);
    }
    if (info.classUpgrade != null) {
      Reflect.callMethod(info.type, info.classUpgrade, [o, info.serialized_version, fieldMap]);
    }
  }

  inline function unserializeInstance() : Dynamic {
    var info = inflateClass();
    if (info.type != null) {
      var o = FastReflect.createEmptyInstance(info.type);
      return inflateInstance(o, info);
    } else if (this.skipCounter > 0 || RemovedTypes.names.exists(info.name)) {
      skipInstanceOf(info);
      return null;
    } else {
      throw 'Missing required code for ${info.name}';
      return null;
    }
  }

  public function inflateEnum() : InflatedEnumValue {
    var b = stream.readByte();
    switch( b ) {
    default:
      throw 'Invalid enum type: $b';
      return null;
    case "_".code:
      var t = readDigits();
      if( t < 0 || t >= tcache.length )
        throw "Invalid enum type reference";
      if( stream.readByte() != ":".code )
        throw "Invalid enum type reference format";
      return cast tcache[t];
    case "=".code:
      return inflateEnumValueInfo();
    case "|".code:
      inflateEnumInfo();
      return inflateEnum();
    }
  }

  function setupInflatedEnum(name:String, serialized_version:Int) : InflatedEnum {
    var info = new InflatedEnum();
    info.name = name;
    info.serialized_version = serialized_version;
    info.type = Type.resolveEnum(name);

    if (info.type != null) {
      // See if we need to upgrade this class
      var currentVersion = 0;
      var upgradeClassName = '${info.name}_deflatable';
      var upgradeClass:Class<Dynamic> = Type.resolveClass(upgradeClassName);
      var di: Dynamic = upgradeClass == null ? null : Reflect.field(upgradeClass, "___deflatable_version");
      // If it's not currently a Deflatable, it has version 0
      if (di != null) {
        currentVersion = Reflect.callMethod(upgradeClass, di, []);
      }

      if (info.serialized_version != currentVersion) {
        // Find the upgrade function we need to call for this class
        var fnName = '_upgrade_enum';
        info.requiresUpgrade = true;
        info.upgradeClass = upgradeClass;
        info.upgradeFunc = upgradeClass == null ? null : Reflect.field(upgradeClass, fnName);
        if (info.upgradeFunc == null) {
          throw 'Please implement ${fnName} for class ${upgradeClassName}, need to upgrade from version ${info.serialized_version}';
        }
      }
    } else {
      if (this.skipCounter == 0 && !RemovedTypes.names.exists(info.name)) {
        throw 'Enum not found ${info.name}';
      }
    }

    return info;
  }

  function inflateEnumInfo() : InflatedEnum {
    var name = unserialize();
    if( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum name)";
    }
    var serialized_version = readDigits();
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum version)";
    }
    var use_index = unserialize();
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum use index)";
    }

    var info = setupInflatedEnum(name, serialized_version);
    info.useIndex = use_index;
    info.index = tcache.length;
    tcache.push(info);
    return info;
  }

  function inflateEnumValueInfo() : InflatedEnumValue {
    var constructor = unserialize();
    if( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum constructor)";
    }
    var type_index = readDigits();
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum type index)";
    }
    var enum_index = readDigits();
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum index)";
    }
    var num_params = readDigits();
    if ( stream.readByte() != ":".code ) {
      throw "Invalid type format (enum num params)";
    }

    var valueInfo : InflatedEnumValue = new InflatedEnumValue();
    valueInfo.construct = constructor;
    valueInfo.enumIndex = enum_index;
    valueInfo.enumType = cast tcache[type_index];
    valueInfo.numParams = num_params;
    valueInfo.index = tcache.length;
    tcache.push(valueInfo);
    return valueInfo;
  }

  @:keep function inflateEnumValue(valueInfo : InflatedEnumValue) : Dynamic {

    var info = valueInfo.enumType;
    var skip = false;
    if (info.type != null) {
      skip = false;
    } else if (this.skipCounter > 0 || RemovedTypes.names.exists(info.name)) {
      skip = true;
    } else {
      throw 'Missing required code for ${info.name}';
    }

    var e = null;
    if (skip) this.skipCounter++;

    var params = valueInfo.numParams == 0 ? null : [for (i in 0...valueInfo.numParams) unserialize()];

    if (skip) { this.skipCounter--; }
    else if (info.useIndex) {
      if (info.requiresUpgrade) {
        throw 'Cannot currently upgrade a useEnumIndex enum ${info.name}';
      }
      try {
        e = Type.createEnumIndex(info.type, valueInfo.enumIndex, params);
      }
      catch (e:Dynamic){
        throw 'Failed to create enum ${info.name}@${valueInfo.enumIndex}(${params}) : $e';
      }
    }
    else {
      // Upgrade our param array before we construct the enum
      var data = {constructor: valueInfo.construct, params: params};
      if (info.requiresUpgrade) {
        Reflect.callMethod(info.upgradeClass, info.upgradeFunc, [info.serialized_version, data]);
      }

      try {
        e = data.constructor == null ? null : Type.createEnum(info.type, data.constructor, data.params);
      }
      catch (e:Dynamic){
        throw 'Failed to create enum ${info.name}.${data.constructor}(${data.params}) : $e';
      }
    }
    cache.push(e);
    return e;
  }

  inline function unserializeEnumValue() : Dynamic {
    var valueInfo = inflateEnum();
    return inflateEnumValue(valueInfo);
  }

  function unserializeOldEnumValue(useIndex:Bool) : Dynamic {
    var name = unserialize();
    var cached : {info:InflatedEnum, values:Array<InflatedEnumValue>} = ecache[name];
    if (cached == null) {
      var info = setupInflatedEnum(name, 0);
      var values = [];
      var constructs = info.type == null ? [] : Type.getEnumConstructs(info.type);
      for (i in 0...constructs.length) {
        var valueInfo = new InflatedEnumValue();
        valueInfo.construct = constructs[i];
        valueInfo.enumIndex = i;
        valueInfo.enumType = info;
        valueInfo.numParams = 0;
        values.push(valueInfo);
      }
      ecache[name] = cached = {info: info, values: values};
    }

    var valueInfo = null;
    if (useIndex) {
      if( stream.readByte() != ":".code ) {
        throw "Invalid type format (old enum index)";
      }
      var index = readDigits();
      valueInfo = cached.values[index];
      if (valueInfo == null && cached.info.type != null) {
        throw 'Unknown enum constructor $name@$index';
      }
    }
    else {
      var constructor = unserialize();
      for (entry in cached.values) {
        if(entry.construct == constructor) {
          valueInfo = entry;
          break;
        }
      }
      if (valueInfo == null) {
        valueInfo = new InflatedEnumValue();
        valueInfo.construct = constructor;
        valueInfo.enumType = cached.info;
      }
    }

    if( stream.readByte() != ":".code )
      throw "Invalid enum format";

    valueInfo.numParams = readDigits();
    return inflateEnumValue(valueInfo);
  }

  inline function unserializeEnumValueMap() : Dynamic {
    var h = new haxe.ds.EnumValueMap();
    cache.push(h);
    while( stream.peekByte() != "h".code ) {
      var s:Dynamic = unserialize();
      h.set(s,unserialize());
    }
    stream.readByte();
    return h;
  }

  inline function unserializeRawString() : Dynamic {
    var len = readDigits();
    if( stream.readByte() != ":".code || length - stream.getPos() < len )
      throw "Invalid string length";
    var s = stream.readString(len);
    scache.push(s);
    return s;
  }

  inline function unserializeURLEncodedString() : Dynamic {
    var len = readDigits();
    if( stream.readByte() != ":".code || length - stream.getPos() < len )
      throw "Invalid string length";
    var s = stream.readString(len);
    s = StringTools.urlDecode(s);
    scache.push(s);
    return s;
  }

  inline function unserializeRawStringReference() : Dynamic {
    var n = readDigits();
    if( n < 0 || n >= scache.length )
      throw "Invalid string reference";
    return scache[n];
  }

  inline function unserializeObject() : Dynamic {
    var o = {};
    cache.push(o);
    while( true ) {
      if( stream.eof() )
        throw "Invalid object";
      if( stream.peekByte() == "g".code )
        break;
      var k = unserialize();
      if( !Std.is(k,String) )
        throw "Invalid object key";
      var v = unserialize();
      Reflect.setField(o,k,v);
    }
    stream.readByte();
    return o;
  }

  inline function unserializeReference() : Dynamic {
    var n = readDigits();
    if( n < 0 || n >= cache.length )
      throw "Invalid reference";
    return cache[n];
  }

  inline function readDigits() {
    var k = 0;
    var s = false;
    var fpos = stream.getPos();
    while( !stream.eof() ) {
      var c = stream.peekByte();
      if( c == "-".code ) {
        if( stream.getPos() != fpos ) {
          break;
        }
        s = true;
        stream.readByte();
        continue;
      }
      if( c < "0".code || c > "9".code ) {
        break;
      }
      k = k * 10 + (c - "0".code);
      stream.readByte();
    }
    if( s )
      k *= -1;
    return k;
  }

  inline function unserializeFloat() : Dynamic {
    var p1 = stream.getPos();
    while( !stream.eof() ) {
      var c = stream.peekByte();
      // + - . , 0-9
      if( (c >= 43 && c < 58) || c == "e".code || c == "E".code ) {
        stream.readByte();
      } else {
        break;
      }
    }
    var pos = stream.getPos();
    stream.seekTo(p1);
    return Std.parseFloat(stream.readString(pos-p1));
  }

  inline function unserializeArray() : Dynamic {
    var a = new Array<Dynamic>();
    cache.push(a);
    while( true ) {
      var c = stream.peekByte();
      if( c == "h".code ) {
        stream.readByte();
        break;
      }
      if( c == "u".code ) {
        stream.readByte();
        var n = readDigits();
        a[a.length+n-1] = null;
      } else {
        a.push(unserialize());
      }
    }
    return a;
  }

  inline function unserializeList() : Dynamic {
    var l = new List();
    cache.push(l);
    while( stream.peekByte() != "h".code )
      l.add(unserialize());
    stream.readByte();
    return l;
  }

  inline function unserializeStringMap() : Dynamic {
    var h = new haxe.ds.StringMap();
    cache.push(h);
    while( stream.peekByte() != "h".code ) {
      var s = unserialize();
      h.set(s,unserialize());
    }
    stream.readByte();
    return h;
  }

  inline function unserializeIntMap() : Dynamic {
    var h = new haxe.ds.IntMap();
    cache.push(h);
    var c = stream.readByte();
    while( c == ":".code ) {
      var i = readDigits();
      h.set(i,unserialize());
      c = stream.readByte();
    }
    if( c != "h".code )
      throw "Invalid IntMap format";
    return h;
  }

  inline function unserializeObjectMap() : Dynamic {
    var h = new haxe.ds.ObjectMap();
    cache.push(h);
    while( stream.peekByte() != "h".code ) {
      var s = unserialize();
      h.set(s,unserialize());
    }
    stream.readByte();
    return h;
  }

  inline function unserializeDate() : Dynamic {
    var d = Date.fromString(stream.readString(19));
    cache.push(d);
    return d;
  }

  inline function unserializeBytes() : Dynamic {
    var len = readDigits();
    if( stream.readByte() != ":".code || length - stream.getPos() < len )
      throw "Invalid bytes length";
    var codes = CODES;
    if( codes == null ) {
      codes = initCodes();
      CODES = codes;
    }
    var i = 0;
    var rest = len & 3;
    var size = (len >> 2) * 3 + ((rest >= 2) ? rest - 1 : 0);
    var max = len - rest;
    var bytes = haxe.io.Bytes.alloc(size);
    var bpos = 0;
    while( i < max ) {
      var c1 = codes[stream.readByte()];
      var c2 = codes[stream.readByte()];
      bytes.set(bpos++,(c1 << 2) | (c2 >> 4));
      var c3 = codes[stream.readByte()];
      bytes.set(bpos++,(c2 << 4) | (c3 >> 2));
      var c4 = codes[stream.readByte()];
      bytes.set(bpos++,(c3 << 6) | c4);
      i += 4;
    }
    if( rest >= 2 ) {
      var c1 = codes[stream.readByte()];
      var c2 = codes[stream.readByte()];
      bytes.set(bpos++,(c1 << 2) | (c2 >> 4));
      if( rest == 3 ) {
        var c3 = codes[stream.readByte()];
        bytes.set(bpos++,(c2 << 4) | (c3 >> 2));
      }
    }
    cache.push(bytes);
    return bytes;
  }

  inline function unserializeCustom() : Dynamic {
    var name = unserialize();
    var cl = Type.resolveClass(name);
    if( cl == null )
      throw "Class not found " + name;
    var o : Dynamic = Type.createEmptyInstance(cl);
    cache.push(o);
    o.hxUnserialize(this);
    if( stream.readByte() != "g".code )
      throw "Invalid custom data";
    return o;
  }

  /**
    Unserializes the next part of [this] Inflater instance and returns
    the according value.

    This function may call Type.resolveClass to determine a
    Class from a String, and Type.resolveEnum to determine an
    Enum from a String.

    If [this] Inflater instance contains no more or invalid data, an
    exception is thrown.

    This operation may fail on structurally valid data if a type cannot be
    resolved or if a field cannot be set. This can happen when unserializing
    Strings that were serialized on a different haxe target, in which the
    serialization side has to make sure not to include platform-specific
    data.

    Classes are created from Type.createEmptyInstance, which means their
    constructors are not called.
  **/
  public function unserialize() : Dynamic {
    var byte = stream.readByte();
    switch( byte ) {
    case "T".code, "V".code, "W".code:
      // wind back so unserializeInstance can re-read the character code
      stream.seekTo(stream.getPos()-1);
      return unserializeInstance();
    case '!'.code, '#'.code, '~'.code:
      // radix-tree serialized strings
      stream.seekTo(stream.getPos()-1);
      return rtree.unserialize(this, typeInflater == null);
    case "|".code, "=".code, "_".code:
      stream.seekTo(stream.getPos()-1);
      return unserializeEnumValue();
    case "Y".code: // raw string
      return unserializeRawString();
    case "N".code:
      return unserializeEnumValueMap();
    case "n".code:
      return null;
    case "t".code:
      return true;
    case "f".code:
      return false;
    case "z".code:
      return 0;
    case "i".code:
      return readDigits();
    case "d".code:
      return unserializeFloat();
    case "y".code:
      return unserializeURLEncodedString();
    case "k".code:
      return Math.NaN;
    case "m".code:
      return Math.NEGATIVE_INFINITY;
    case "p".code:
      return Math.POSITIVE_INFINITY;
    case "a".code:
      return unserializeArray();
    case "o".code:
      return unserializeObject();
    case "r".code:
      return unserializeReference();
    case "R".code:
      return unserializeRawStringReference();
    case "x".code:
      throw unserialize();
    case "w".code, "j".code:
      return unserializeOldEnumValue(byte == "j".code);
    case "l".code:
      return unserializeList();
    case "b".code:
      return unserializeStringMap();
    case "q".code:
      return unserializeIntMap();
    case "M".code:
      return unserializeObjectMap();
    case "v".code:
      return unserializeDate();
    case "s".code:
      return unserializeBytes();
    case "C".code:
      // Can we remove this? I don't think we've been using it
      return unserializeCustom();
    default:
    }
    throw ('Invalid char ${String.fromCharCode(byte)} at position ${stream.getPos()-1}');
  }

  /**
    Unserializes `v` and returns the according value.

    This is a convenience function for creating a new instance of
    Inflater with `v` as buffer and calling its unserialize() method
    once.
  **/
  public static function run( v : String, ?options:InflaterOptions ) : Dynamic {
    return new Inflater(new StringInflateStream(v), options).unserialize();
  }
}