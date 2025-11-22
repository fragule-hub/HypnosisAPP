extends Control

const MAX_COLORS := 8

@onready var waves: ColorRect = $Waves
@onready var shader_mat: ShaderMaterial = waves.material as ShaderMaterial

@export var target_size: Vector2 = Vector2(540, 1170)
@export var follow_rect_for_tex: bool = true
@export var tex_size_override: Vector2 = Vector2(256, 256)

@export var center: Vector2 = Vector2(0.5, 0.5)
@export var speed: float = 0.6

@export var use_single_color: bool = false
@export var single_color: Color = Color.WHITE

@export var rings: Dictionary = {
	"colors": [Color(1, 0, 1, 1), Color(1, 0.078, 0.576, 1)],
	"thicknesses": [0.1, 0.1],
	"count": 2,
}

func _ready() -> void:
	_apply_layout()
	_apply_mode_and_params()

func _apply_layout() -> void:
	custom_minimum_size = target_size
	waves.custom_minimum_size = target_size

func _apply_mode_and_params() -> void:
	if use_single_color:
		waves.material = null
		shader_mat = null
		waves.color = single_color
	else:
		if waves.material == null:
			var sh := load("res://scenes/波纹/波纹.gdshader") as Shader
			shader_mat = ShaderMaterial.new()
			shader_mat.shader = sh
			waves.material = shader_mat
		else:
			shader_mat = waves.material as ShaderMaterial
		waves.color = Color(1, 1, 1, 1)
		_apply_shader_params()

func _apply_shader_params() -> void:
	if shader_mat == null:
		return
	var tex_sz := waves.size if follow_rect_for_tex else tex_size_override
	shader_mat.set_shader_parameter("tex_size", tex_sz)
	shader_mat.set_shader_parameter("center", center)
	shader_mat.set_shader_parameter("speed", speed)

	var colors_arr: Array = rings.get("colors", [])
	var thick_arr: Array = rings.get("thicknesses", [])
	var count: int = int(rings.get("count", colors_arr.size()))
	count = clamp(count, 1, min(MAX_COLORS, colors_arr.size()))

	var vecs: Array = []
	var floats: Array = []
	for i in range(MAX_COLORS):
		if i < count:
			var c: Color = colors_arr[i]
			vecs.append(Vector4(c.r, c.g, c.b, c.a))
			var w: float = float(thick_arr[i]) if i < thick_arr.size() else 0.03
			floats.append(w)
		else:
			vecs.append(Vector4(0, 0, 0, 0))
			floats.append(0.0)
	shader_mat.set_shader_parameter("colors", PackedVector4Array(vecs))
	shader_mat.set_shader_parameter("color_count", count)
	shader_mat.set_shader_parameter("thicknesses", PackedFloat32Array(floats))

func set_single_color_enabled(flag: bool) -> void:
	use_single_color = flag
	_apply_mode_and_params()

func set_rings_config(config: Dictionary) -> void:
	rings = config
	_apply_mode_and_params()

func set_speed(v: float) -> void:
	speed = v
	if shader_mat:
		shader_mat.set_shader_parameter("speed", speed)

func set_tex_size(v: Vector2) -> void:
	tex_size_override = v
	follow_rect_for_tex = false
	if shader_mat:
		shader_mat.set_shader_parameter("tex_size", tex_size_override)
