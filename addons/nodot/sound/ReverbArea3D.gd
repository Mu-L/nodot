## Sets reverb when the player enters the area
class_name ReverbArea3D extends Area3D

## Enable the sfx area
@export var enabled: bool = true
@export var bus: String = "SFX"
@export_range(0.0, 1.0) var room_size = 0.8
@export_range(0.0, 1.0) var damping = 0.5
@export_range(0.0, 1.0) var spread = 1.0
@export_range(0.0, 1.0) var hipass = 0.0
@export_range(0.0, 1.0) var dry = 1.0
@export_range(0.0, 1.0) var wet = 0.5
## Lerp speed for reverb transitions (0 = instant)
@export_range(0.0, 20.0) var lerp_speed: float = 0.5

var _current_reverb: Dictionary = {}
var _target_reverb: Dictionary = {}
var _is_lerping: bool = false

var defaults: Dictionary = {
	"room_size": 0.0,
	"damping": 0.0,
	"spread": 0.0,
	"hipass": 0.0,
	"dry": 1.0,
	"wet": 0.0
}

func _enter_tree():
	connect("body_entered", _detect_character_and_play)
	connect("body_exited", _detect_character_and_stop)
	_current_reverb = defaults.duplicate()
	_target_reverb = defaults.duplicate()

func _exit_tree() -> void:
	AudioManager.set_reverb(bus, defaults)

func _process(delta: float):
	if not _is_lerping:
		return

	var all_reached: bool = true
	for key in _current_reverb.keys():
		if not is_equal_approx(_current_reverb[key], _target_reverb[key]):
			_current_reverb[key] = lerp(_current_reverb[key], _target_reverb[key], lerp_speed * delta)
			all_reached = false

	AudioManager.set_reverb(bus, _current_reverb)

	if all_reached:
		_is_lerping = false

func _detect_character_and_play(body: Node3D):
	if body is CharacterBody3D:
		action()
		
func _detect_character_and_stop(body: Node3D):
	if body is CharacterBody3D:
		deactivate()

## Set the reverb
func action():
	if not enabled:
		return

	var target: Dictionary = {
		"room_size": room_size,
		"damping": damping,
		"spread": spread,
		"hipass": hipass,
		"dry": dry,
		"wet": wet
	}

	if lerp_speed <= 0.0:
		AudioManager.set_reverb(bus, target)
		_current_reverb = target.duplicate()
	else:
		_target_reverb = target
		_is_lerping = true


## Stop the reverb
func deactivate():
	if not enabled:
		return

	if lerp_speed <= 0.0:
		AudioManager.set_reverb(bus, defaults)
		_current_reverb = defaults.duplicate()
	else:
		_target_reverb = defaults.duplicate()
		_is_lerping = true
