extends Resource
class_name SettingsResource

@export var fullscreen: bool = false

@export var panel_anim_duration: float = 0.25
@export var panel_slide_ratio: float = 0.25
@export var use_ratio_thresholds: bool = true
@export var threshold_ratio: float = 0.12

# Heart scene settings
@export var heart_visible: bool = true
@export var heartbeat_enabled: bool = true
@export var heart_size_ui: float = 20.0

@export var heart_fill: Color = Color.WHITE
@export var heart_inner: Color = Color(0.937, 0.212, 0.804, 1.0)
@export var heart_outer: Color = Color(0.647, 0.0, 0.631, 1.0)

@export var stroke_inner_px: float = 20.0
@export var stroke_outer_px: float = 20.0
@export var softness_px: float = 2.0

@export var glow_enabled: bool = true
@export var glow_size: float = 40.0
@export var glow_strength: float = 1.2

@export var pulse_speed_ui: float = 1.2
@export var pulse_amount_ui: float = 0.6
@export var preserve_aspect: bool = true

# Waves scene settings
@export var use_single_color_mode: bool = false
@export var single_color: Color = Color.WHITE
@export var wave_speed: float = 2.0
@export var wave_color_count: int = 2
@export var wave_colors: Array[Color] = [Color(1, 0, 1, 1), Color(1, 1, 1, 1)]
@export var wave_thickness_ui: Array[float] = [1.0, 1.0]

