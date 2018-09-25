package pmdb.ql.ast;

enum OpKind {
    // search along unique index
    ReadPrimary;
    
    // search along non-unique index
    ReadSecondary;

    // obtain all documents which are matched by a filter-pattern
    Find;

    // obtain (incrementally?) a single document matched by a filter-pattern
    FindOne;
}
