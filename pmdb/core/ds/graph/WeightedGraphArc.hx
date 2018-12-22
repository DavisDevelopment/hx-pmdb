package pmdb.core.ds.graph;

#if generic
@:generic
#end
class WeightedGraphArc<T> {
	public function new(node:WeightedGraphNode<T>, ?userData:Dynamic) {
		this.node = node;
		this.userData = userData;
		next = null;
		prev = null;
	}
	
	public var val(get, never):T;
	inline function get_val():T return node.val;

	public var key(default, null):Int = HashKey.next();
	public var node: WeightedGraphNode<T>;
	public var next:WeightedGraphArc<T>;
	public var prev:WeightedGraphArc<T>;

	public var userData: Float;
	
	public function free() {
		node = null;
		next = prev = null;
	}
}
