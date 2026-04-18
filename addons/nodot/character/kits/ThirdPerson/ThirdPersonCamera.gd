## A camera for use with third person games
class_name ThirdPersonCamera extends Camera3D

## Distance from the camera to the character
@export var distance: float = 5.0:
	set(new_value):
		distance = clamp(new_value, distance_clamp.x, distance_clamp.y)
## The distance clamp for zooming
@export var distance_clamp := Vector2(5.0, 5.0)
## Move the camera to the initial position after some inactivity (0.0 to disable)
@export var time_to_reset: float = 2.0
## The speed at which the camera moves into position when the character is moving
@export var chase_speed: float = 2.0
## Collision excluded objects
@export var collision_ignored: Array[PhysicsBody3D] = [] # WARNING: Modifying the type here causes an infinite recursion crash.
## Angle threshold (in radians) at which camera starts sliding closer
@export var slide_angle_threshold: float = -0.7
## Minimum distance when looking straight down
@export var min_slide_distance: float = 2.0
## Speed at which distance adjusts
@export var distance_adjust_speed: float = 8.0

var current_distance: float = 5.0
var container: Node3D
var springarm: SpringArm3D
var target_node: Node3D
var time_since_last_move: float = 0.0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if !(get_parent() is ThirdPersonCharacter):
		warnings.append("Parent should be a ThirdPersonCharacter")
	return warnings

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	
	springarm = SpringArm3D.new()
	for node in collision_ignored:
		springarm.add_excluded_object(node.get_rid())
	springarm.transform = transform
	springarm.spring_length = distance
	target_node = Node3D.new()
	springarm.add_child(target_node)
	get_parent().add_child.call_deferred(springarm)
	top_level = true
	
func _ready():
	container = get_parent()
	current_distance = distance

func _process(delta: float) -> void:
	global_position = lerp(global_position, target_node.global_position, chase_speed * 5 * delta)
	quaternion = quaternion.slerp(target_node.global_transform.basis.get_rotation_quaternion(), chase_speed * 5 * delta)
	springarm.spring_length = lerp(springarm.spring_length, current_distance, chase_speed * delta)
	
	if !current: return
	
	# Adjust distance based on camera pitch (looking down)
	if container:
		var pitch: float = container.rotation.x
		var target_distance: float = distance

		# When looking down past the threshold, reduce distance
		if pitch < slide_angle_threshold:
			# Calculate how far past the threshold we are (0.0 to 1.0)
			var slide_factor: float = clamp((slide_angle_threshold - pitch) / abs(slide_angle_threshold), 0.0, 1.0)
			# Interpolate between base distance and minimum slide distance
			target_distance = lerp(distance, min_slide_distance, slide_factor)

		# Smoothly adjust to target distance
		current_distance = lerp(current_distance, target_distance, distance_adjust_speed * delta)
	
	if time_to_reset > 0.0:
		if container.rotation != Vector3.ZERO:
			time_since_last_move += delta
			if time_since_last_move > time_to_reset:
				container.rotation = container.rotation.slerp(Vector3.ZERO, chase_speed * delta)
		else:
			time_since_last_move = 0.0
