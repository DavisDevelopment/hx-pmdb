package pmdb.ql.ast;

enum BoundingValue<T> {
    Edge(v: T);
    Inclusive(v: T);
}
