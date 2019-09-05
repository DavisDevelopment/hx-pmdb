package pmdb.storage;

interface IFormat<A, B> {
    function encode(data: A):B;
    function encodeException(e: Dynamic):String;
    
    function decode(data: B):A;
}
