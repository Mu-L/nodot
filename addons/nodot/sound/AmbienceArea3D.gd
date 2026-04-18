class_name AmbienceArea3D extends Area3D

## The ambient sound this zone will trigger. Drag an audio file here.
@export var stream: AudioStream: set = _set_stream
## The volume for the stream
@export_range(0.0, 1.0) var max_volume: float = 0.8
## How far from the edge of this zone the sound will fade out.
@export var fade_distance: float = 15.0
## If true, shows a small pink sphere at the sound's calculated position.
@export var enable_debug_visualization: bool = false

# --- Private variables ---
var _audio_player: AudioStreamPlayer3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# --- Cached Data for Performance ---
var _local_shape_aabb: AABB
var _debug_sphere: MeshInstance3D # For visualizing the sound source

func _ready() -> void:
	# 1. Validate required components and data.
	if not stream:
		print_rich("[color=orange]Warning:[/color] AmbienceArea3D at %s has no AudioStream assigned. Disabling." % get_path())
		set_process(false)
		return

	if not is_instance_valid(collision_shape) or not is_instance_valid(collision_shape.shape):
		print_rich("[color=red]Error:[/color] AmbienceArea3D at %s has a missing or invalid CollisionShape3D/Shape. Disabling." % get_path())
		set_process(false)
		return

	# 2. **PERFORMANCE OPTIMIZATION:**
	# We cache the shape's local AABB here. Calculating a debug mesh every frame
	# is very slow. This way, we do the inexpensive calculation once.
	update_aabb()

	# 3. Create and configure the AudioStreamPlayer3D.
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = stream
	_audio_player.name = "DynamicAmbiencePlayer"
	_audio_player.autoplay = true
	add_child(_audio_player)
	
	# 4. Start playing the sound, but muted. The volume will be controlled in _process.
	_audio_player.volume_linear = 0.0
	_audio_player.play()
	
	if enable_debug_visualization:
		_create_debug_sphere()


func _exit_tree() -> void:
	# If the audio player was created, free it when this area is removed from the scene.
	if is_instance_valid(_audio_player):
		_audio_player.queue_free()
	if is_instance_valid(_debug_sphere):
		_debug_sphere.queue_free()

func _set_stream(new_stream: AudioStream):
	stream = new_stream
	if _audio_player:
		_audio_player.stream = stream
		_audio_player.play()

## Recalculates the cached AABB. Call this if the CollisionShape3D's shape resource changes.
func update_aabb() -> void:
	var shape_node = collision_shape
	if not is_instance_valid(shape_node):
		shape_node = get_node_or_null("CollisionShape3D")
	
	if is_instance_valid(shape_node) and is_instance_valid(shape_node.shape):
		_local_shape_aabb = shape_node.shape.get_debug_mesh().get_aabb()

func _physics_process(delta: float) -> void:
	# 1. Get the listener's position (usually the camera).
	var camera := get_viewport().get_camera_3d()
	if not camera:
		_audio_player.volume_linear = 0.0
		return

	var listener_pos: Vector3 = camera.global_position

	# 2. & 3. Calculate volume and the sound's position.
	# Transform listener position to the collision shape's local space to account for rotation.
	var local_listener_pos: Vector3 = collision_shape.to_local(listener_pos)
	
	# Clamp inside the local AABB.
	var local_closest_point: Vector3 = local_listener_pos.clamp(_local_shape_aabb.position, _local_shape_aabb.end)
	
	# Transform back to global space.
	var closest_point: Vector3 = collision_shape.to_global(local_closest_point)
	
	var distance: float = listener_pos.distance_to(closest_point)
	
	if is_instance_valid(_debug_sphere):
		_debug_sphere.global_position = closest_point
		
	var volume_factor: float
	if fade_distance <= 0.01:
		volume_factor = 1.0 if distance < 0.01 else 0.0
	elif distance > fade_distance:
		volume_factor = 0.0
	else:
		volume_factor = 1.0 - (distance / fade_distance) * 2.0
	
	# 4. Update the audio player's position and volume.
	_audio_player.global_position = closest_point
	_audio_player.volume_linear = clampf(volume_factor, 0.0, max_volume)
	
func get_closest_point_to(aabb: AABB, pos: Vector3):
	var local_test_point = to_local(pos)
	var local_closest_point = local_test_point.clamp(aabb.position, aabb.end)
	return to_global(local_closest_point)

func _create_debug_sphere() -> void:
	_debug_sphere = MeshInstance3D.new()
	_debug_sphere.name = "DebugAudioPoint"
	
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.DEEP_PINK
	# Make it unshaded so it's always visible, regardless of lighting.
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	# Assign the material to the mesh resource.
	sphere_mesh.surface_set_material(0, material)
	
	_debug_sphere.mesh = sphere_mesh
	add_child(_debug_sphere)
