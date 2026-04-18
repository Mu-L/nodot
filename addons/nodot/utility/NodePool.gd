## A node pool implementation for efficient node reuse
## Manages a pool of nodes that can be reused instead of constantly instantiating and freeing
class_name NodePool extends Node

## The maximum number of objects allowed in the pool
@export var pool_limit: int = 10

## The node template to duplicate for the pool
@export var target_node: Node: set = _set_target_node

## The parent node where new nodes should be spawned
@export var spawn_root: Node

# Internal array storing the pool of nodes
var pool: Array[Node] = []
var cached_node: Node

## Sets the target node and initializes the pool
func _set_target_node(new_node: Node) -> void:
	target_node = new_node
	clear()
	target_node.get_parent().remove_child(target_node)
	cached_node = target_node.duplicate()
	if cached_node.get_parent() != null:
		cached_node.reparent(self)
	var first_instance := cached_node.duplicate()
	_add_node_to_tree(first_instance)
	pool = [first_instance]
	
## Adds a node to the scene tree if it's not already in one
func _add_node_to_tree(node: Node) -> void:
	if is_instance_valid(spawn_root):
		if node.is_inside_tree():
			node.reparent(spawn_root)
		else:
			if node.get_parent():
				node.reparent(spawn_root)
			spawn_root.add_child.call_deferred(node)
	else:
		if node.is_inside_tree():
			node.reparent(self)
		else:
			if node.get_parent():
				node.reparent(spawn_root)
			add_child(node)
			
## Gets the next available node from the pool
## If the pool is at its limit, reuses the oldest node
## Otherwise, creates a new node by duplicating the target
func next() -> Node:
	var node = pool.pop_front() if pool.size() >= pool_limit else cached_node.duplicate()
	if !is_instance_valid(node): return null
	pool.append(node)
	_add_node_to_tree(node)
	return node

## Clears the pool and frees all nodes
func clear():
	for node in pool:
		if node.is_instance_valid():
			node.queue_free()
	pool = []
