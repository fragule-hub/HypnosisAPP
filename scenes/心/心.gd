extends Control

@onready var heart: ColorRect = $Heart
@onready var shader_mat: ShaderMaterial = heart.material as ShaderMaterial

@export var target_size: Vector2 = Vector2(500, 500)

@export var fill_color: Color = Color.WHITE
@export var inner_color: Color = Color(0.937, 0.212, 0.804, 1.0)
@export var outer_color: Color = Color(0.647, 0.0, 0.631, 1.0)

@export var stroke_outer: float = 20.0
@export var stroke_inner: float = 20.0
@export var softness: float = 2.0

@export var glow_size: float = 40.0
@export var glow_strength: float = 1.2
@export var glow_enabled: bool = true

@export var pulse_speed: float = 1.2
@export var pulse_amount: float = 0.06
@export var rotate_amount: float = 0.04
@export var pulse_enabled: bool = true
@export var preserve_aspect: bool = true

 

func _ready() -> void:
	_apply_layout()
	_apply_params()

func _apply_layout() -> void:
	custom_minimum_size = target_size
	heart.custom_minimum_size = target_size
	if shader_mat:
		shader_mat.set_shader_parameter("rect_size", heart.size)

func _apply_params() -> void:
	if heart.material == null:
		var sh := load("res://scenes/心/心.gdshader") as Shader
		shader_mat = ShaderMaterial.new()
		shader_mat.shader = sh
		heart.material = shader_mat
	else:
		shader_mat = heart.material as ShaderMaterial

	shader_mat.set_shader_parameter("fill_color", fill_color)
	shader_mat.set_shader_parameter("inner_color", inner_color)
	shader_mat.set_shader_parameter("outer_color", outer_color)

	shader_mat.set_shader_parameter("stroke_outer", stroke_outer)
	shader_mat.set_shader_parameter("stroke_inner", stroke_inner)
	shader_mat.set_shader_parameter("softness", softness)

	var gs := glow_size if glow_enabled else 0.0
	var gk := glow_strength if glow_enabled else 0.0
	shader_mat.set_shader_parameter("glow_size", gs)
	shader_mat.set_shader_parameter("glow_strength", gk)

	var pa := pulse_speed if pulse_enabled else 0.0
	var pm := pulse_amount if pulse_enabled else 0.0
	var ra := rotate_amount if pulse_enabled else 0.0
	shader_mat.set_shader_parameter("pulse_speed", pa)
	shader_mat.set_shader_parameter("pulse_amount", pm)
	shader_mat.set_shader_parameter("rotate_amount", ra)
	shader_mat.set_shader_parameter("preserve_aspect", preserve_aspect)
	shader_mat.set_shader_parameter("rect_size", heart.size)

func set_heartbeat(active: bool) -> void:
	pulse_enabled = active
	_apply_params()

func set_glow(active: bool) -> void:
	glow_enabled = active
	_apply_params()

func set_colors(fill: Color, inner: Color, outer: Color) -> void:
	fill_color = fill
	inner_color = inner
	outer_color = outer
	_apply_params()

func set_strokes(inner_w: float, outer_w: float, s: float = softness) -> void:
	stroke_inner = inner_w
	stroke_outer = outer_w
	softness = s
	_apply_params()
