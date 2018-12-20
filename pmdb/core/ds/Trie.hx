package pmdb.core.ds;

import haxe.ds.Option;

class Trie<T> {
    public var root: TrieNode<T>;
    private var elements: Int = 0;

    public function new() {
        root = new TrieNode();
        elements = 0;
    }

    public function contains(key: String):Bool {
        final node = getNode( key );
        return node != null;
    }

    public var length(get, never): Int;
    inline function get_length() return elements;

    public function get(key: String):Null<T> {
        final node = getNode( key );
        if (node != null) {
            return node.value;
        }
        return null;
    }

    public function insert(key:String, ?value:T) {
        var node = root,
        remaining = key;

        while (remaining.length > 0) {
            var child:Null<TrieNode<T>> = null;
            for (childKey in node.children.keys()) {
                var prefix = common(remaining, childKey);
                if (prefix.length == 0) {
                    continue;
                }
                if (prefix.length == childKey.length) {
                    child = node.children[childKey];
                    remaining = remaining.substring(childKey.length);
                    break;
                }
                else {
                    // split the child
                    child = new TrieNode();
                    child.children[childKey.substring(prefix.length)] = node.children[childKey];
                    node.children.remove(childKey);
                    node.children[prefix] = child;
                    remaining = remaining.substring(prefix.length);
                }
            }
            if (child == null && remaining.length > 0) {
                child = new TrieNode();
                node.children[remaining] = child;
                remaining = '';
            }
            node = child;
        }

        if (!node.terminal) {
            node.terminal = true;
            elements++;
        }

        node.value = value;
    }

    public function remove(key: String) {
        final node = getNode( key );
        if (node != null) {
            node.terminal = false;
            elements--;
        }
    }

    public function map<U>(prefix:String, func:(key:String, value:T)->U):Array<U> {
        final mapped = [];
        final node = getNode( prefix );
        final stack:Array<{prefix:String,node:TrieNode<T>}> = [];
        if (node != null) {
            stack.push({
                prefix:prefix,
                node:node
            });
        }

        while (stack.length > 0) {
            final entry = stack.pop();
            final key = entry.prefix;
            final node = entry.node;
            trace( node );

            if ( node.terminal ) {
                mapped.push(func(key, node.value));
            }

            for (c in node.children.keys()) {
                stack.push({
                    prefix: key + c,
                    node: node.children.get(c)
                });
            }
        }

        return mapped;
    }

    /**
      obtain a reference to the node with the given key
     **/
    private function getNode(key: String):Null<TrieNode<T>> {
        var node:Null<TrieNode<T>> = this.root;
        var remaining:String = key;

        while (node != null && remaining.length > 0) {
            var child:Null<TrieNode<T>> = null;

            for (i in 0...remaining.length) {
                trace( remaining );
                if (node.children.exists(remaining.substring(0, i))) {
                    child = node.children[remaining.substring(0, i)];
                    remaining = remaining.substring( i );
                    break;
                }
            }

            node = child;
        }

        if (remaining.length == 0 && node != null && node.terminal)
            return node;
        else
            return null;
    }

    inline function commonPrefix(a:String, b:String):String {
        var shortest:Int = Math.floor(Math.min(a.length, b.length));
        var idx = null;
        for (i in 0...shortest) {
            idx = i;
            if (a.charAt(i) != b.charAt(i)) {
                break;
            }
        }
        return a.substring(0, idx);
    }

    inline function common(a:String, b:String, i:Int=0):String {
        if (b.length < a.length) {
            return common(b, a, i);
        }
        else if (i >= a.length) {
            return a;
        }
        else {
            if (a.charAt(i) != b.charAt(i))
                return a.substring(0, i);
            else
                return common(a, b, i + 1);
        }
    }
}

class TrieNode<T> {
    public function new(value=null, terminal=false, ?children) {
        this.terminal = terminal;
        this.value = value;
        this.children = children != null ? children : new Map();
    }

    public var terminal: Bool;
    public var value: Null<T>;
    public var children: Map<String, TrieNode<T>>;
}
