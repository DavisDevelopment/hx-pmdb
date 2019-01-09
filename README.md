# hx-pmdb
### An Embedded DataStore Engine for the [Haxe](https://haxe.org/) Language

  Written in pure Haxe code, PmDb aims at being a feature-rich and powerful embedded database to be used in any
Haxe project requiring persistent data management. 
<!--
PmDb is, fundamentally, an ["In-Memory Database"](https://en.wikipedia.org/wiki/In-memory_database#Hybrids_with_on-disk_databases), as the DataStore is kept entirely in-memory and is **never** directly persisted to the disk.
-->

  #### NOTE: Disregard following message. Updated README coming very soon

  PmDb is still *very* much a Work-In-Progress, and should be ruled out entirely for any sort of production use (for now). 
  PmDb's implementation is quite experimental at the moment, and puts a lot of focus on the JavaScript/NodeJS target. That doesn't mean that it won't work on other targets, but the kind of performance that PmDb is designed to coax out of JavaScript should not be expected on any of the other targets (except maybe Flash?), and that's including the Java and C++ targets. It should still be fast enough for many use cases on those targets, but it will most likely be most useful in JavaScript-rich environments (specifically running on Google's V8 engine).
  Lots of implementation details still up in the air, but the goal list so far is this:  
 - [ ] Allow declaration of a schema to improve performance some, without *requiring* one.
   - [ ] When no schema is provided, gather type-information about the data being stored at runtime
   - [ ] Represent queries as trees of nodes, much like an AST, but inextricable from (in fact, identical to) its ["interpreter"](https://en.wikipedia.org/wiki/Interpreter_(computing))
 - [ ] Use hscript (or something similar) for writing out queries a Strings
 - [ ] Support a fluent, Object-Oriented API for query building
 - [ ] Design internal algorithms to take all reasonable measures for maximizing the degree to which V8 (& associated JIT optimizer) JIT-compile the Database-related portions of your application
 
##### Immediate Roadmap:
 - [ ] Finish the prototype for the APIs surrounding query-creation and execution of UPDATE queries
 - [ ] 
