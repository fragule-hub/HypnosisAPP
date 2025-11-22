## 目标
- 将“设置面板”的所有用户选项持久化到本地，打开应用时自动读取并应用；每次修改时立即保存。
- 使用 Godot 4 的 Resource 进行结构化保存，文件保存在 `user://` 目录（沙盒本地存储）。

## 技术方案
- 新增 Resource 类型：`SettingsResource.gd`（`class_name SettingsResource`），集中存放所有设置项。
- 存储位置：`user://hypnosis_settings.tres`（人类可读的 `.tres`），可选增加 JSON 备份 `user://hypnosis_settings.json`。
- 在 `HypnosisAPP` 中集成“加载/应用/保存”逻辑，避免额外 Autoload。

## SettingsResource 字段（示例）
- 基础与显示：
  - `fullscreen: bool`
  - `panel_anim_duration: float`
  - `panel_slide_ratio: float`
  - `use_ratio_thresholds: bool`
  - `threshold_ratio: float`
- 心场景：
  - `heart_visible: bool`
  - `heartbeat_enabled: bool`
  - `heart_size_ui: float`（UI 每 10 → 实际 100；应用时乘以 10）
  - `heart_fill: Color`
  - `heart_inner: Color`
  - `heart_outer: Color`
  - `stroke_inner_px: float`
  - `stroke_outer_px: float`
  - `softness_px: float`
  - `glow_enabled: bool`
  - `glow_size: float`
  - `glow_strength: float`
  - `pulse_speed_ui: float`（UI 每 0.1 → 着色器 0.01；应用时乘以 0.1）
  - `pulse_amount_ui: float`（同上）
  - `preserve_aspect: bool`
- 波纹场景：
  - `use_single_color_mode: bool`
  - `single_color: Color`
  - `wave_speed: float`
  - `wave_color_count: int`（1–4）
  - `wave_colors: Array[Color]`（长度最多 4）
  - `wave_thickness_ui: Array[float]`（每 1 → 着色器 0.01；应用时乘以 0.01）

## 代码改动点
1. 新建 `res://settings/SettingsResource.gd`
   - `extends Resource`
   - `@export` 上述字段，设定默认值与类型（使用 `Array[Color]`、`Array[float]`）。
2. 修改 `HypnosisAPP`
   - 字段：
     - `var settings: SettingsResource`
     - `const SETTINGS_PATH := "user://hypnosis_settings.tres"`
     - `var _loading: bool = false`（初始化期间避免触发保存与循环事件）
   - 方法：
     - `load_settings()`：若存在则 `ResourceLoader.load(SETTINGS_PATH)`，否则创建新实例并用当前 UI 默认值填充；随后调用 `save_settings()` 首次写盘。
     - `apply_settings_to_ui()`：用 `settings` 的值初始化所有 UI 控件（CheckButton/SpinBox/ColorPickerButton），并根据波纹数量控制选项的显示；注意抑制 `_loading` 期间的保存。
     - `apply_settings_to_scenes()`：将 `settings` 映射到“心”与“波纹”的脚本与着色器（做 UI→着色器的换算）。
     - `save_settings()`：`ResourceSaver.save(settings, SETTINGS_PATH)`；可选同时写入 JSON 备份。
   - `HypnosisAPP._ready()`：
     - 在现有初始化后调用 `load_settings()` → `apply_settings_to_ui()` → `apply_settings_to_scenes()`。
3. 信号回调中写入与保存
   - 在所有 UI 信号处理函数中：先更新 `settings` 对应字段，再调用 `save_settings()`，最后调用已有的应用逻辑（如 `_apply_wave_rings_from_ui()` 等）。
   - 纯色模式切换：更新 `settings.use_single_color_mode` 与 `settings.single_color`，保存后应用模式。
   - 波纹颜色数量与各颜色/厚度：更新 `settings.wave_color_count`、`settings.wave_colors[i]`、`settings.wave_thickness_ui[i]` 并保存。
   - 心跳速度/幅度：更新 `pulse_speed_ui`、`pulse_amount_ui` 并保存；应用时乘 0.1。
   - 心大小：更新 `heart_size_ui` 并保存；应用时乘 10 到 `target_size`。
   - 心颜色与描边宽度：更新对应颜色与像素宽度并保存。
4. 边界与健壮性
   - 颜色数量 clamp 到 1–4；数组长度动态扩展或截断。
   - 首次运行如未找到文件，创建并保存默认设置。
   - 防抖：可选用 `Timer` 合并短时间内多次保存，但按你的需求“每当修改时就进行保存”将立即保存。

## 验证
- 启动后读取本地 `user://hypnosis_settings.tres` 并正确恢复 UI 与场景。
- 更改任一设置项后即时写入文件；重启应用能恢复上一状态。
- 在移动端（触摸）下反复开关面板与修改选项，持久化与应用行为正常。

## 扩展（可选）
- 提供“重置为默认”按钮：删除或覆盖 `user://` 文件并刷新 UI。
- 增加版本字段 `settings_version`，未来变更字段时可做迁移。
- 允许导入/导出 `.tres` 到共享位置（如 `res://`）以分享预设。