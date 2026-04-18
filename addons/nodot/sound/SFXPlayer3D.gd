@tool
## A sound effect player with randomization and trigger options
class_name SFXPlayer3D extends AudioStreamPlayer3D

@export var enabled: bool = true

## An array of audiostreams chosen at random on action
@export var sfx: Array[AudioStream] = []

@export_subgroup("Trigger")
## (optional) A node path containing a signal to trigger the sound effect
@export var trigger_node: Node:
	set(new_node):
		trigger_node = new_node
		notify_property_list_changed()
		
@export_subgroup("Other")
## Arguments to unbind from signal
@export var unbind_count: int = 0
## Fade speed (used if fade_in_speed or fade_out_speed are not set)
@export var fade_speed: float = 1.0
## Override fade in speed (uses fade_speed if <= 0)
@export var fade_in_speed: float = 0.0
## Override fade out speed (uses fade_speed if <= 0)
@export var fade_out_speed: float = 0.0
## Tweak the pitch a bit to add variety
@export var tweak_pitch: float = 0.0
## Add a delay before playing the sound
@export var delay: float = 0.0

## The name of the signal
var trigger_signal: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var original_volume: float

# Fade state management
enum FadeState { IDLE, FADING_IN, FADING_OUT }
var fade_state: FadeState = FadeState.IDLE
var current_volume: float = 1.0
var target_volume: float = 1.0
var pause_after_fade: bool = false

func _enter_tree() -> void:
	if trigger_signal == "": return
	
	if unbind_count > 0:
		trigger_node.connect(trigger_signal, action.unbind(unbind_count))
	elif trigger_node and !trigger_node.is_connected(trigger_signal, action):
		trigger_node.connect(trigger_signal, action)
		
func _ready():
	original_volume = volume_linear
	current_volume = volume_linear
	target_volume = volume_linear
	set_process(false)

	if !Engine.is_editor_hint() and autoplay:
		action()
	
func _process(delta: float) -> void:
	if fade_state == FadeState.IDLE:
		return

	# Determine which speed to use based on current fade state
	var current_fade_speed: float = fade_speed
	if fade_state == FadeState.FADING_IN and fade_in_speed > 0.0:
		current_fade_speed = fade_in_speed
	elif fade_state == FadeState.FADING_OUT and fade_out_speed > 0.0:
		current_fade_speed = fade_out_speed

	# Smoothly interpolate towards target volume
	var fade_delta = delta / current_fade_speed if current_fade_speed > 0.0 else 1.0
	current_volume = move_toward(current_volume, target_volume, fade_delta)
	volume_linear = current_volume

	# Check if we've reached the target
	if is_equal_approx(current_volume, target_volume):
		fade_state = FadeState.IDLE
		set_process(false)

		# Handle post-fade actions
		if target_volume <= 0.0:
			if pause_after_fade:
				stream_paused = true
			else:
				stop()
			pause_after_fade = false

func _tweak_pitch():
	pitch_scale = rng.randf_range(1.0 - tweak_pitch, 1.0 + tweak_pitch)

## Loads, caches and plays the audio file at the path argument. Use `sfx_root_path` to prefix the path.
func action(index: int = -1) -> void:
	if !enabled: return
	var sfx_size: int = sfx.size()
	if sfx_size <= 0: return
	
	var stream: AudioStream = sfx[0]
	if index >= 0:
		stream = sfx[index]
	else:
		var random_index: int = rng.randi_range(0, sfx_size - 1)
		stream = sfx[random_index]

	set_stream(stream)
	if tweak_pitch > 0.0:
		_tweak_pitch()
	
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		
	play()

## Fade the sound effect in
func fade_in(index: int = -1):
	if !enabled: return

	# Start playing if not already playing
	if !stream_paused and playing == false:
		action(index)

	# Set fade state and target - smoothly transitions from current volume
	fade_state = FadeState.FADING_IN
	set_process(true)
	target_volume = original_volume
	current_volume = volume_linear  # Start from wherever we are now
	stream_paused = false
	pause_after_fade = false

## Fade the sound effect out
func fade_out(pause_on_finish: bool = false, index: int = -1):
	if !enabled: return
	if playing == false: return

	# Set fade state and target - smoothly transitions from current volume
	fade_state = FadeState.FADING_OUT
	set_process(true)
	target_volume = 0.0
	current_volume = volume_linear  # Start from wherever we are now
	pause_after_fade = pause_on_finish

func _get_property_list() -> Array[Dictionary]:
	var property_list: Array[Dictionary] = [{
		name = "Trigger",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_SUBGROUP
	}]
	
	var signal_list = ""
	if is_instance_valid(trigger_node):
		var signal_data = trigger_node.get_signal_list()
		var signals: Array = signal_data.map(func(item): return item.name).filter(
			func(item): return item != ""
		)
		signals.sort()
		signal_list = ",".join(signals)

		property_list.append({
			"name": "trigger_signal",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": signal_list,
		})
		
	return property_list
