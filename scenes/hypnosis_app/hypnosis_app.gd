extends Node2D
class_name HypnosisAPP

@onready var 波纹: Control = $波纹
@onready var Heart: Control = $心
@onready var 设置面板: Control = $设置面板
@onready var 面板容器: PanelContainer = $设置面板/PanelContainer

@onready var 全屏: CheckButton = %全屏
@onready var 心: CheckButton = %心
@onready var 心跳: CheckButton = %心跳
@onready var 纯色: CheckButton = %纯色
@onready var 波纹速度: SpinBox = %波纹速度
@onready var 心跳速度: SpinBox = %心跳速度
@onready var 心跳幅度: SpinBox = %心跳幅度
@onready var 心大小: SpinBox = %心大小

@onready var 颜色数量: SpinBox = %颜色数量
@onready var 颜色选项1: HBoxContainer = %颜色选项1
@onready var 颜色选项2: HBoxContainer = %颜色选项2
@onready var 颜色选项3: HBoxContainer = %颜色选项3
@onready var 颜色选项4: HBoxContainer = %颜色选项4

@onready var 填充颜色: HBoxContainer = %填充颜色
@onready var 内边框颜色: HBoxContainer = %内边框颜色
@onready var 外边框颜色: HBoxContainer = %外边框颜色

@onready var 退出: Button = %退出

@export var swipe_open_threshold: float = 120.0
@export var swipe_close_threshold: float = 120.0
@export var panel_anim_duration: float = 0.25
@export var panel_slide_ratio: float = 0.25
@export var use_ratio_thresholds: bool = true
@export var threshold_ratio: float = 0.12

const SETTINGS_PATH: String = "user://hypnosis_settings.tres"
var settings: SettingsResource
var _loading: bool = false

var _pressing: bool = false
var _press_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_window_size(_get_visible_size())
	_connect_ui()
	_apply_all_from_ui()
	_set_settings_visible(false)
	面板容器.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	面板容器.anchor_left = 0.0
	面板容器.anchor_top = 0.0
	面板容器.anchor_right = 1.0
	面板容器.anchor_bottom = 1.0
	await get_tree().process_frame
	_apply_window_size(_get_visible_size())
	load_settings()

func _on_viewport_size_changed() -> void:
	_apply_window_size(_get_visible_size())

func _apply_window_size(sz: Vector2) -> void:
	if 波纹:
		波纹.target_size = sz
		波纹.follow_rect_for_tex = true
		波纹._apply_layout()
		波纹._apply_mode_and_params()

func _set_settings_visible(visible_on: bool) -> void:
	设置面板.visible = visible_on
	if visible_on:
		面板容器.queue_sort()
		面板容器.queue_redraw()

func _animate_settings(open: bool) -> void:
	var tw := create_tween()
	var h := float(_get_visible_size().y)
	var slide := -h * panel_slide_ratio
	if open:
		设置面板.visible = true
		面板容器.queue_sort()
		面板容器.queue_redraw()
		设置面板.modulate.a = 0.0
		设置面板.position = Vector2(设置面板.position.x, slide)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(设置面板, "modulate:a", 1.0, panel_anim_duration)
		tw.parallel().tween_property(设置面板, "position:y", 0.0, panel_anim_duration)
	else:
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(设置面板, "modulate:a", 0.0, panel_anim_duration)
		tw.parallel().tween_property(设置面板, "position:y", slide, panel_anim_duration)
		tw.finished.connect(func():
			设置面板.visible = false
		)

func load_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		settings = ResourceLoader.load(SETTINGS_PATH) as SettingsResource
	else:
		settings = SettingsResource.new()
		save_settings()
	_loading = true
	apply_settings_to_ui()
	_loading = false
	apply_settings_to_scenes()

func save_settings() -> void:
	if settings == null:
		return
	ResourceSaver.save(settings, SETTINGS_PATH)

func apply_settings_to_ui() -> void:
	全屏.button_pressed = settings.fullscreen
	心.button_pressed = settings.heart_visible
	心跳.button_pressed = settings.heartbeat_enabled
	纯色.button_pressed = settings.use_single_color_mode
	波纹速度.value = settings.wave_speed
	心跳速度.value = settings.pulse_speed_ui
	心跳幅度.value = settings.pulse_amount_ui
	心大小.value = settings.heart_size_ui
	颜色数量.value = float(settings.wave_color_count)
	_set_color_options_visibility(settings.wave_color_count)
	var containers := [颜色选项1, 颜色选项2, 颜色选项3, 颜色选项4]
	for i in range(min(settings.wave_color_count, containers.size())):
		(containers[i].get_node("ColorPickerButton") as ColorPickerButton).color = settings.wave_colors[i]
		(containers[i].get_node("SpinBox") as SpinBox).value = settings.wave_thickness_ui[i]
	# Heart colors and strokes
	(填充颜色.get_node("ColorPickerButton") as ColorPickerButton).color = settings.heart_fill
	(内边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color = settings.heart_inner
	(外边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color = settings.heart_outer
	(内边框颜色.get_node("SpinBox") as SpinBox).value = settings.stroke_inner_px
	(外边框颜色.get_node("SpinBox") as SpinBox).value = settings.stroke_outer_px

func apply_settings_to_scenes() -> void:
	_on_fullscreen_toggled(settings.fullscreen)
	_on_heart_visible_toggled(settings.heart_visible)
	_on_heartbeat_toggled(settings.heartbeat_enabled)
	_on_wave_speed_changed(settings.wave_speed)
	_on_heart_speed_changed(settings.pulse_speed_ui)
	_on_heart_amp_changed(settings.pulse_amount_ui)
	_on_heart_size_changed(settings.heart_size_ui)
	_on_color_count_changed(float(settings.wave_color_count))
	_apply_wave_rings_from_ui()
	_apply_heart_colors_from_ui()
	_apply_heart_strokes_from_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			_pressing = true
			_press_start_pos = ev.position
		else:
			if _pressing:
				var dy := ev.position.y - _press_start_pos.y
				_pressing = false
				var open_th := _calc_open_threshold()
				var close_th := _calc_close_threshold()
				if dy >= open_th:
					_animate_settings(true)
				elif -dy >= close_th:
					_animate_settings(false)
	elif event is InputEventScreenDrag:
		if _pressing:
			var dv := (event as InputEventScreenDrag).position - _press_start_pos
			var open_th2 := _calc_open_threshold()
			var close_th2 := _calc_close_threshold()
			if dv.y >= open_th2:
				_pressing = false
				_animate_settings(true)
			elif -dv.y >= close_th2:
				_pressing = false
				_animate_settings(false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_press_start_pos = mb.position
			else:
				if _pressing:
					var dy2 := mb.position.y - _press_start_pos.y
					_pressing = false
					var open_th3 := _calc_open_threshold()
					var close_th3 := _calc_close_threshold()
					if dy2 >= open_th3:
						_animate_settings(true)
					elif -dy2 >= close_th3:
						_animate_settings(false)

func _calc_open_threshold() -> float:
	if use_ratio_thresholds:
		return float(_get_visible_size().y) * threshold_ratio
	return swipe_open_threshold

func _calc_close_threshold() -> float:
	if use_ratio_thresholds:
		return float(_get_visible_size().y) * threshold_ratio
	return swipe_close_threshold

func _get_visible_size() -> Vector2:
	var rect := get_viewport().get_visible_rect()
	if rect:
		return rect.size
	return Vector2(get_viewport().size)

func _connect_ui() -> void:
	全屏.toggled.connect(_on_fullscreen_toggled)
	心.toggled.connect(_on_heart_visible_toggled)
	心跳.toggled.connect(_on_heartbeat_toggled)
	纯色.toggled.connect(_on_single_color_toggled)
	波纹速度.value_changed.connect(_on_wave_speed_changed)
	心跳速度.value_changed.connect(_on_heart_speed_changed)
	心跳幅度.value_changed.connect(_on_heart_amp_changed)
	心大小.value_changed.connect(_on_heart_size_changed)
	颜色数量.value_changed.connect(_on_color_count_changed)
	for i in [颜色选项1, 颜色选项2, 颜色选项3, 颜色选项4]:
		var cp := i.get_node("ColorPickerButton") as ColorPickerButton
		var sp := i.get_node("SpinBox") as SpinBox
		cp.color_changed.connect(_on_wave_colors_changed)
		sp.value_changed.connect(_on_wave_colors_changed)
	var fill_cp := 填充颜色.get_node("ColorPickerButton") as ColorPickerButton
	fill_cp.color_changed.connect(_on_heart_colors_changed)
	var inner_cp := 内边框颜色.get_node("ColorPickerButton") as ColorPickerButton
	inner_cp.color_changed.connect(_on_heart_colors_changed)
	var inner_sp := 内边框颜色.get_node("SpinBox") as SpinBox
	inner_sp.value_changed.connect(_on_heart_strokes_changed)
	var outer_cp := 外边框颜色.get_node("ColorPickerButton") as ColorPickerButton
	outer_cp.color_changed.connect(_on_heart_colors_changed)
	var outer_sp := 外边框颜色.get_node("SpinBox") as SpinBox
	outer_sp.value_changed.connect(_on_heart_strokes_changed)

func _apply_all_from_ui() -> void:
	_on_fullscreen_toggled(全屏.button_pressed)
	_on_heart_visible_toggled(心.button_pressed)
	_on_heartbeat_toggled(心跳.button_pressed)
	_on_single_color_toggled(纯色.button_pressed)
	_on_wave_speed_changed(波纹速度.value)
	_on_heart_speed_changed(心跳速度.value)
	_on_heart_amp_changed(心跳幅度.value)
	_on_heart_size_changed(心大小.value)
	_on_color_count_changed(颜色数量.value)
	_apply_wave_rings_from_ui()
	_apply_heart_colors_from_ui()
	_apply_heart_strokes_from_ui()

func _on_fullscreen_toggled(on: bool) -> void:
	if settings and not _loading:
		settings.fullscreen = on
		save_settings()
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_window_size(_get_visible_size())

func _on_heart_visible_toggled(on: bool) -> void:
	if settings and not _loading:
		settings.heart_visible = on
		save_settings()
	Heart.visible = on

func _on_heartbeat_toggled(on: bool) -> void:
	if settings and not _loading:
		settings.heartbeat_enabled = on
		save_settings()
	Heart.set_heartbeat(on)

func _on_single_color_toggled(on: bool) -> void:
	if settings and not _loading:
		settings.use_single_color_mode = on
	if on:
		var c: Color = (_get_color_thickness(颜色选项1)["color"]) as Color
		波纹.set_single_color_enabled(true)
		波纹.single_color = c
		if settings and not _loading:
			settings.single_color = c
			save_settings()
		_set_color_options_visibility(1)
	else:
		波纹.set_single_color_enabled(false)
		_set_color_options_visibility(int(颜色数量.value))
	_apply_wave_rings_from_ui()

func _on_wave_speed_changed(v: float) -> void:
	if settings and not _loading:
		settings.wave_speed = v
		save_settings()
	波纹.set_speed(v)

func _on_heart_speed_changed(v: float) -> void:
	if settings and not _loading:
		settings.pulse_speed_ui = v
		save_settings()
	Heart.pulse_speed = v * TAU
	Heart._apply_params()

func _on_heart_amp_changed(v: float) -> void:
	if settings and not _loading:
		settings.pulse_amount_ui = v
		save_settings()
	Heart.pulse_amount = v * 0.1
	Heart._apply_params()

func _on_heart_size_changed(v: float) -> void:
	if settings and not _loading:
		settings.heart_size_ui = v
		save_settings()
	var sz := v * 10.0
	Heart.target_size = Vector2(sz, sz)
	Heart._apply_layout()
	Heart._apply_params()

func _on_color_count_changed(v: float) -> void:
	if settings and not _loading:
		settings.wave_color_count = int(v)
		save_settings()
	if 纯色.button_pressed:
		_set_color_options_visibility(1)
	else:
		_set_color_options_visibility(int(v))
	_apply_wave_rings_from_ui()

func _on_wave_colors_changed(_v) -> void:
	if settings and not _loading:
		var count: int = 1 if 纯色.button_pressed else int(颜色数量.value)
		count = clamp(count, 1, 4)
		var containers := [颜色选项1, 颜色选项2, 颜色选项3, 颜色选项4]
		settings.wave_colors = []
		settings.wave_thickness_ui = []
		for i in range(count):
			var cp := (containers[i].get_node("ColorPickerButton") as ColorPickerButton).color
			var spv := float((containers[i].get_node("SpinBox") as SpinBox).value)
			settings.wave_colors.append(cp)
			settings.wave_thickness_ui.append(spv)
		save_settings()
	_apply_wave_rings_from_ui()

func _on_heart_colors_changed(_c: Color) -> void:
	if settings and not _loading:
		var fill := (填充颜色.get_node("ColorPickerButton") as ColorPickerButton).color
		var inner := (内边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color
		var outer := (外边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color
		settings.heart_fill = fill
		settings.heart_inner = inner
		settings.heart_outer = outer
		save_settings()
	_apply_heart_colors_from_ui()

func _on_heart_strokes_changed(_v: float) -> void:
	if settings and not _loading:
		var inner_w := float((内边框颜色.get_node("SpinBox") as SpinBox).value)
		var outer_w := float((外边框颜色.get_node("SpinBox") as SpinBox).value)
		settings.stroke_inner_px = inner_w
		settings.stroke_outer_px = outer_w
		save_settings()
	_apply_heart_strokes_from_ui()

func _set_color_options_visibility(n: int) -> void:
	var list := [颜色选项1, 颜色选项2, 颜色选项3, 颜色选项4]
	for idx in list.size():
		list[idx].visible = idx < n

func _get_color_thickness(container: HBoxContainer) -> Dictionary:
	var cp := container.get_node("ColorPickerButton") as ColorPickerButton
	var sp := container.get_node("SpinBox") as SpinBox
	var data := {
		"color": cp.color,
		"thickness": float(sp.value) * 0.01,
	}
	return data

func _apply_wave_rings_from_ui() -> void:
	var count: int = 1 if 纯色.button_pressed else int(颜色数量.value)
	count = clamp(count, 1, 4)
	var containers := [颜色选项1, 颜色选项2, 颜色选项3, 颜色选项4]
	var colors: Array = []
	var thicks: Array = []
	for i in range(count):
		var dt := _get_color_thickness(containers[i])
		var c: Color = dt["color"]
		var th: float = dt["thickness"]
		colors.append(c)
		thicks.append(th)
	var rings := {
		"colors": colors,
		"thicknesses": thicks,
		"count": count,
	}
	波纹.set_rings_config(rings)
	if 纯色.button_pressed:
		波纹.single_color = colors[0]
		波纹.set_single_color_enabled(true)

func _apply_heart_colors_from_ui() -> void:
	var fill := (填充颜色.get_node("ColorPickerButton") as ColorPickerButton).color
	var inner := (内边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color
	var outer := (外边框颜色.get_node("ColorPickerButton") as ColorPickerButton).color
	Heart.set_colors(fill, inner, outer)

func _apply_heart_strokes_from_ui() -> void:
	var inner_w := float((内边框颜色.get_node("SpinBox") as SpinBox).value)
	var outer_w := float((外边框颜色.get_node("SpinBox") as SpinBox).value)
	Heart.set_strokes(inner_w, outer_w)

func _on_退出_pressed() -> void:
	get_tree().quit()
