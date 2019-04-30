package pmdb.storage;

interface IFormat<A, B> {
    function encode(data: A):B;
    function decode(data: B):A;
}
