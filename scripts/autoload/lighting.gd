extends Node
## 照明。時間帯ごとの全体色調（CanvasModulate）、タイル光源（PointLight2D）、月光、プレイヤーの懐中電灯を管理する。
## 暗さ darkness（0 明るい〜1 暗い）は Calendar.time_of_day から決まり、Stalker の視界・聴覚に渡る。
## 彩度ある色は光源にしか使わない（Palette.LIGHT_SOURCES）。全体色調はパレット色と Color.WHITE の補間で作る。
## 384×216 で暗すぎて見えない事故を防ぐため、MIN_CHANNEL を下限とし、設定 brightness で持ち上げる。

signal darkness_changed(darkness: float)

## 時間帯 → 暗さ
const DARKNESS_BY_TIME: Dictionary = {"morning": 0.15, "noon": 0.0, "evening": 0.55, "night": 1.0}
## 時間帯 → 色調の元になるパレット色と、その混ぜ具合（0 で無変化）
const TINT_BY_TIME: Dictionary = {
	"morning": {"color": Palette.OCHRE, "mix": 0.12},
	"noon": {"color": Palette.BONE_WHITE, "mix": 0.0},
	"evening": {"color": Palette.RUST, "mix": 0.35},
	"night": {"color": Palette.NIGHT_SKY, "mix": 0.82},
}
## 全体色調の各チャンネルの下限（これ以下には暗くしない）
const MIN_CHANNEL: float = 0.22
## 設定 brightness（0〜1）で色調を白へ戻す最大量。0.5 を既定の見え方とする
const BRIGHTNESS_LIFT_MAX: float = 0.5
const BRIGHTNESS_DEFAULT: float = 0.5
## タイル光源：真昼でも僅かに残す
const LIGHT_ENERGY_DAY_FLOOR: float = 0.15
const LIGHT_TEXTURE_PX: int = 128
## 月光（夜のみ）
const MOON_ENERGY_MAX: float = 0.18
## 懐中電灯
const FLASHLIGHT_RANGE_TILES: float = 5.0
const FLASHLIGHT_HALF_ANGLE_DEG: float = 26.0
const FLASHLIGHT_ENERGY: float = 1.0
const FLASHLIGHT_TEXTURE_PX: int = 352
## この明るさ以上なら「照らされている」（Stalker の視認距離が伸びる）
const LIT_THRESHOLD: float = 0.35

var darkness: float = 0.0
var flashlight_on: bool = false
## 屋内などで時間帯と独立に暗さを固定する（負なら無効）
var darkness_override: float = -1.0

var _modulate: CanvasModulate = null
var _moon: DirectionalLight2D = null
var _flashlight: PointLight2D = null
var _lights: Array[PointLight2D] = []


func _ready() -> void:
	Calendar.time_of_day_changed.connect(func(_t: String, _p: String) -> void: refresh())
	SceneRouter.field_entered.connect(func(_id: String, _from: String) -> void: _ensure_world_nodes())
	SaveManager.setting_changed.connect(func(key: String, _v: Variant) -> void:
		if key == "brightness":
			refresh())
	refresh()


## 現在の暗さと色調を再計算して適用する
func refresh() -> void:
	var previous: float = darkness
	darkness = darkness_override if darkness_override >= 0.0 else float(DARKNESS_BY_TIME.get(Calendar.time_of_day, 0.0))
	_ensure_world_nodes()
	if _modulate != null:
		_modulate.color = tint_for(Calendar.time_of_day) if darkness_override < 0.0 else tint_for_darkness(darkness_override)
	if _moon != null:
		_moon.energy = MOON_ENERGY_MAX * darkness
	# 解放済みの光源を外す（filter は型付き配列を返さず、解放済みの要素は PointLight2D に変換できない）
	var alive: Array[PointLight2D] = []
	for l: Variant in _lights:
		if is_instance_valid(l):
			alive.append(l as PointLight2D)
	_lights = alive
	for light: PointLight2D in _lights:
		_apply_energy(light)
	if _flashlight != null:
		_flashlight.visible = flashlight_on
	if not is_equal_approx(previous, darkness):
		darkness_changed.emit(darkness)


## 時間帯の全体色調。パレット色と白の補間 → brightness で持ち上げ → 下限
func tint_for(time_of_day: String) -> Color:
	var spec: Dictionary = TINT_BY_TIME.get(time_of_day, TINT_BY_TIME["noon"])
	var tint: Color = Color.WHITE.lerp(Palette.get_color(int(spec["color"])), float(spec["mix"]))
	var brightness: float = float(SaveManager.get_setting("brightness"))
	tint = tint.lerp(Color.WHITE, (brightness - BRIGHTNESS_DEFAULT) * BRIGHTNESS_LIFT_MAX + BRIGHTNESS_LIFT_MAX * 0.5)
	return Color(maxf(tint.r, MIN_CHANNEL), maxf(tint.g, MIN_CHANNEL), maxf(tint.b, MIN_CHANNEL), 1.0)


## 暗さの値から直接色調を作る（屋内用）。夜のパレット色と白を暗さで直接補間するので、
## 暗さ 0.82 で屋外の夜と同じ色調になり、それ以上なら夜より暗い（懐中電灯が要る）
func tint_for_darkness(value: float) -> Color:
	var tint: Color = Color.WHITE.lerp(Palette.get_color(int(TINT_BY_TIME["night"]["color"])), clampf(value, 0.0, 1.0))
	var brightness: float = float(SaveManager.get_setting("brightness"))
	tint = tint.lerp(Color.WHITE, (brightness - BRIGHTNESS_DEFAULT) * BRIGHTNESS_LIFT_MAX + BRIGHTNESS_LIFT_MAX * 0.5)
	return Color(maxf(tint.r, MIN_CHANNEL), maxf(tint.g, MIN_CHANNEL), maxf(tint.b, MIN_CHANNEL), 1.0)


## 屋内の暗さを固定する。負で解除。FieldFloors が階の切替で呼ぶ
func set_darkness_override(value: float) -> void:
	darkness_override = value
	refresh()


# ── タイル光源 ──

## タイルに種別名の光源を同期する。光源でなければ既存の光を消す
func sync_tile_light(parent: Node2D, tile: Vector2i, type_name: String) -> void:
	var name: String = "Light_%d_%d" % [tile.x, tile.y]
	var existing: PointLight2D = parent.get_node_or_null(name) as PointLight2D
	var spec: Dictionary = LightCatalog.get_light(type_name)
	if spec.is_empty():
		if existing != null:
			_lights.erase(existing)
			existing.queue_free()
		return
	if existing == null:
		existing = PointLight2D.new()
		existing.name = name
		existing.position = GameConstants.tile_to_world(tile)
		existing.shadow_enabled = false
		existing.blend_mode = Light2D.BLEND_MODE_ADD
		parent.add_child(existing)
		_lights.append(existing)
	existing.texture = LightTextureGenerator.radial(LIGHT_TEXTURE_PX)
	existing.texture_scale = float(spec["radius"]) * GameConstants.TILE_SIZE * 2.0 / float(LIGHT_TEXTURE_PX)
	existing.color = Palette.get_color(int(spec["color"]))
	existing.set_meta("base_energy", float(spec["energy"]))
	_apply_energy(existing)


func _apply_energy(light: PointLight2D) -> void:
	var base: float = float(light.get_meta("base_energy", 0.8))
	light.energy = base * lerpf(LIGHT_ENERGY_DAY_FLOOR, 1.0, darkness)


## その地点がどれだけ照らされているか（0〜1）。タイル光源と懐中電灯を見る。暗さが 0 なら常に 1
func light_level_at(world_pos: Vector2) -> float:
	if darkness <= 0.0:
		return 1.0
	var level: float = 1.0 - darkness
	for light: PointLight2D in _lights:
		if not is_instance_valid(light) or not light.is_inside_tree():
			continue
		var radius: float = light.texture_scale * LIGHT_TEXTURE_PX * 0.5
		var d: float = light.global_position.distance_to(world_pos)
		if d < radius:
			level = maxf(level, (1.0 - d / radius) * darkness + (1.0 - darkness))
	if flashlight_on and _flashlight != null and _flashlight.is_inside_tree():
		var to: Vector2 = world_pos - _flashlight.global_position
		var range_px: float = FLASHLIGHT_RANGE_TILES * GameConstants.TILE_SIZE
		if to.length() < range_px and absf(Vector2.from_angle(_flashlight.global_rotation).angle_to(to)) <= deg_to_rad(FLASHLIGHT_HALF_ANGLE_DEG):
			level = 1.0
	return clampf(level, 0.0, 1.0)


func is_lit_at(world_pos: Vector2) -> bool:
	return light_level_at(world_pos) >= LIT_THRESHOLD


# ── 懐中電灯 ──

## プレイヤーに懐中電灯を付ける。向きは Player が rotation で回す
func attach_flashlight(owner: Node2D) -> PointLight2D:
	if _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.queue_free()
	_flashlight = PointLight2D.new()
	_flashlight.name = "Flashlight"
	_flashlight.texture = LightTextureGenerator.cone(FLASHLIGHT_TEXTURE_PX, FLASHLIGHT_HALF_ANGLE_DEG)
	_flashlight.texture_scale = FLASHLIGHT_RANGE_TILES * GameConstants.TILE_SIZE * 2.0 / float(FLASHLIGHT_TEXTURE_PX)
	_flashlight.color = Palette.get_color(Palette.BONE_WHITE)
	_flashlight.energy = FLASHLIGHT_ENERGY
	_flashlight.shadow_enabled = false
	_flashlight.blend_mode = Light2D.BLEND_MODE_ADD
	_flashlight.visible = flashlight_on
	owner.add_child(_flashlight)
	return _flashlight


func set_flashlight(on: bool) -> void:
	if on != flashlight_on:
		AudioManager.play_se("se_flashlight_on" if on else "se_flashlight_off")
	flashlight_on = on
	if _flashlight != null and is_instance_valid(_flashlight):
		_flashlight.visible = on


# ── 内部 ──

## ワールドのルートに CanvasModulate と月光を置く（UI は別 CanvasLayer なので影響しない）
func _ensure_world_nodes() -> void:
	var root: Node2D = SceneRouter.world_root
	if root == null:
		return
	if _modulate == null or not is_instance_valid(_modulate) or _modulate.get_parent() != root:
		_modulate = root.get_node_or_null("TimeOfDayModulate") as CanvasModulate
		if _modulate == null:
			_modulate = CanvasModulate.new()
			_modulate.name = "TimeOfDayModulate"
			root.add_child(_modulate)
		_modulate.color = tint_for(Calendar.time_of_day)
	if _moon == null or not is_instance_valid(_moon) or _moon.get_parent() != root:
		_moon = root.get_node_or_null("Moon") as DirectionalLight2D
		if _moon == null:
			_moon = DirectionalLight2D.new()
			_moon.name = "Moon"
			_moon.color = Palette.get_color(Palette.FOG_INDIGO)
			_moon.shadow_enabled = false
			_moon.blend_mode = Light2D.BLEND_MODE_ADD
			root.add_child(_moon)
		_moon.energy = MOON_ENERGY_MAX * darkness
