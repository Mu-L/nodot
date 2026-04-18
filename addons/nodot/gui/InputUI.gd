@tool
class_name InputUI extends TextureRect

const input_format_names = ["Flairs", "Generic", "Keyboard & Mouse", "Nintendo Switch", "Nintendo Wii", "Nintendo WiiU", "Playdate", "PlayStation Series", "Steam Controller", "Steam Deck", "Xbox Series"]
const input_type_names = ["Default", "Double", "Vector"]

@export_enum("Flairs", "Generic", "Keyboard & Mouse", "Nintendo Switch", "Nintendo Wii", "Nintendo WiiU", "Playdate", "PlayStation Series", "Steam Controller", "Steam Deck", "Xbox Series") var format: int = 2: set = _change_format
@export_enum("Default", "Double", "Vector") var type: int = 0: set = _change_type
@export var input_name: String = "": set = _change_input_name
## When set, automatically switches between keyboard and controller icons based on the active input device.
@export var action_name: String = "": set = _change_action_name
@export var outline_color: Color = Color.BLACK: set = _change_outline_color
@export var outline_size: float = 3.0: set = _change_outline_size
@export var transparency: float = 1.0: set = _change_transparency

var shader: Shader = ResourceLoader.load("res://addons/nodot/shaders/canvas_outline.gdshader")
var shader_material: ShaderMaterial = ShaderMaterial.new()

func _ready():
	shader_material.shader = shader
	material = shader_material
	set_outline()
	_bind_action_signals()

func _change_action_name(new_value: String) -> void:
	action_name = new_value
	_bind_action_signals()

func _bind_action_signals() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or action_name == "":
		return
	if not InputManager.input_mode_changed.is_connected(_on_input_mode_changed):
		InputManager.input_mode_changed.connect(_on_input_mode_changed)
		InputManager.controller_type_changed.connect(_on_controller_type_changed)
	_update_for_action()

func _on_input_mode_changed(_new_mode) -> void:
	_update_for_action()

func _on_controller_type_changed(_new_type) -> void:
	_update_for_action()

func _update_for_action() -> void:
	if action_name == "":
		return
	var file_path: String
	if InputManager.is_controller_mode():
		var fmt := InputManager.get_inputui_format()
		var tex_name := InputManager.get_joypad_texture_name(action_name)
		file_path = "res://addons/nodot/textures/kenney_inputs/%s/%s/%s.png" % [
			input_format_names[fmt], input_type_names[type], tex_name
		]
	else:
		var key_name := InputManager.get_action_key(action_name)
		file_path = "res://addons/nodot/textures/kenney_inputs/%s/%s/%s.png" % [
			input_format_names[2], input_type_names[type], convert_key(key_name)
		]
	if ResourceLoader.exists(file_path):
		texture = ResourceLoader.load(file_path)

func _change_format(new_value: int):
	format = new_value
	load_material()

func _change_type(new_value: int):
	type = new_value
	load_material()
	
func _change_input_name(new_value: String):
	input_name = new_value
	load_material()

func _change_outline_color(new_value: Color):
	outline_color = new_value
	set_outline()
	
func _change_outline_size(new_value: float):
	outline_size = new_value
	set_outline()
	
func _change_transparency(new_value: float):
	transparency = new_value
	set_outline()

func generate_path() -> String:
	return "res://addons/nodot/textures/kenney_inputs/%s/%s/%s.png" % [input_format_names[format], input_type_names[type], convert_key(input_name)]

func convert_key(input: String):
	if input.contains("Mouse Button"):
		return convert_mouse_button(input)
	else:
		return convert_keyboard_key(input)
	
func convert_keyboard_key(input: String, outline: bool = false):
	var postfix = "_outline" if outline else ""
	return "keyboard_%s%s" % [input.to_lower(), postfix]
	
func convert_mouse_button(input: String):
	if input.contains("Left"):
		return "mouse_left"
	if input.contains("Right"):
		return "mouse_right"
	if input.contains("Middle"):
		return "mouse_scroll"

func load_material():
	var file_path := generate_path()
	if ResourceLoader.exists(file_path):
		var img := ResourceLoader.load(file_path)
		texture = img

func set_outline():
	shader_material.set_shader_parameter("line_color", outline_color)
	shader_material.set_shader_parameter("line_thickness", outline_size)
	shader_material.set_shader_parameter("transparency", transparency)
