extends Node
## 画面効果。ワールドの上・UI の下の CanvasLayer に画面いっぱいの矩形を敷き、post_fx.gdshader で
## にじみ（ブルーム）・上下端のぼかし（被写界深度風）・周辺減光をかける。あわせて舞う葉・埃・蛍の粒子をカメラに付ける。
## 設定 screen_fx（既定オン）で丸ごと切れる。ゲームの判定には一切関わらない（Lighting.light_level_at 等は見ない）。
## 色は Palette から取り、粒子のテクスチャは resources/fx/*.png（tools/fx/paint_particles.py が描く）。

const SETTING_KEY: String = "screen_fx"
const SHADER_PATH: String = "res://resources/shaders/post_fx.gdshader"
## ワールド（0）と UI（10）の間
const CANVAS_LAYER: int = 5
## にじみ・ぼかし・周辺減光の強さ
const BLOOM_STRENGTH: float = 0.35
const BLOOM_THRESHOLD: float = 0.55
const BLUR_STRENGTH: float = 1.0
const BLUR_BAND: float = 0.25
const VIGNETTE: float = 0.35

## 粒子の種類 → テクスチャ
const PARTICLE_TEXTURES: Dictionary = {
	"leaf": "res://resources/fx/leaf.png",
	"leaf_dry": "res://resources/fx/leaf_dry.png",
	"dust": "res://resources/fx/dust.png",
	"firefly": "res://resources/fx/firefly.png",
}
## 生態系（fields.json の biome）→ 屋外で舞うもの。無ければ埃だけ
const LEAVES_BY_BIOME: Dictionary = {
	"orchard_valley": "leaf", "temple_precinct": "leaf", "hilltop_shrine": "leaf", "castle_ruins": "leaf_dry",
	"forbidden_valley_temple": "leaf_dry", "paddy_shrine": "leaf", "riverbank_bridge": "leaf",
}
## 夜に蛍が出る生態系
const FIREFLY_BIOMES: PackedStringArray = ["paddy_shrine", "riverbank_bridge", "riverside_ground", "orchard_valley", "forbidden_valley_temple"]
## 画面外から入ってくるための余白（タイル）
const EMIT_MARGIN_TILES: float = 2.0

var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _emitters: Array[CPUParticles2D] = []


func _ready() -> void:
	_build_layer()
	Lighting.darkness_changed.connect(func(_d: float) -> void: _apply_uniforms())
	SaveManager.setting_changed.connect(func(key: String, _v: Variant) -> void:
		if key == SETTING_KEY:
			_apply_enabled())
	SceneRouter.field_entered.connect(func(_id: String, _from: String) -> void: _rebuild_particles())
	Calendar.time_of_day_changed.connect(func(_t: String, _p: String) -> void: _rebuild_particles())
	get_viewport().size_changed.connect(_apply_uniforms)
	_apply_uniforms()
	_apply_enabled()


func is_enabled() -> bool:
	return bool(SaveManager.get_setting(SETTING_KEY))


# ── 画面全体の効果 ──

func _build_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ScreenFxLayer"
	_layer.layer = CANVAS_LAYER
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.name = "PostFx"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.WHITE
	var shader: Shader = load(SHADER_PATH) as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	_layer.add_child(_rect)


func _apply_uniforms() -> void:
	if _material == null:
		return
	var window_height: float = float(get_viewport().get_visible_rect().size.y)
	_material.set_shader_parameter("scale", maxf(1.0, window_height / float(GameConstants.VIEWPORT_HEIGHT)))
	_material.set_shader_parameter("bloom_strength", BLOOM_STRENGTH)
	_material.set_shader_parameter("bloom_threshold", BLOOM_THRESHOLD)
	_material.set_shader_parameter("blur_strength", BLUR_STRENGTH)
	_material.set_shader_parameter("blur_band", BLUR_BAND)
	_material.set_shader_parameter("vignette", VIGNETTE)
	_material.set_shader_parameter("darkness", Lighting.darkness)


func _apply_enabled() -> void:
	var on: bool = is_enabled()
	if _rect != null:
		_rect.visible = on
	for e: CPUParticles2D in _emitters:
		if is_instance_valid(e):
			e.emitting = on


# ── 粒子 ──

## 現在のフィールド・時間帯に合わせて粒子を作り直す。カメラの子にして画面の範囲に撒く（座標はワールド）
func _rebuild_particles() -> void:
	_clear_particles()
	var camera: Camera2D = SceneRouter.camera
	var field: FieldBase = SceneRouter.current_field
	if camera == null or field == null or field.field_def == null:
		return
	if not field.floor_changed.is_connected(_on_floor_changed):
		field.floor_changed.connect(_on_floor_changed)
	var outside: bool = field.current_floor == FieldFloors.OUTSIDE
	var biome: String = field.field_def.biome
	var night: bool = Calendar.time_of_day == "night"
	if outside:
		var leaf: String = str(LEAVES_BY_BIOME.get(biome, ""))
		if not leaf.is_empty():
			_add_emitter(camera, leaf, 10, 7.0, Vector2(-6.0, 12.0), 12.0, true)
		if night and FIREFLY_BIOMES.has(biome):
			_add_emitter(camera, "firefly", 6, 5.0, Vector2.ZERO, 6.0, false, true)
		elif not night:
			_add_emitter(camera, "dust", 8, 9.0, Vector2(3.0, -2.0), 4.0, false)
	else:
		_add_emitter(camera, "dust", 6, 9.0, Vector2(0.0, 1.5), 3.0, false)
	_apply_enabled()


func _on_floor_changed(_floor_id: String) -> void:
	_rebuild_particles()


func _add_emitter(camera: Camera2D, kind: String, amount: int, lifetime: float, gravity: Vector2, speed: float, spin: bool, blink: bool = false) -> void:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "Particles_" + kind
	p.texture = load(str(PARTICLE_TEXTURES[kind])) as Texture2D
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var half: Vector2 = Vector2(GameConstants.VIEWPORT_SIZE) * 0.5 + Vector2.ONE * EMIT_MARGIN_TILES * GameConstants.TILE_SIZE
	p.emission_rect_extents = half
	p.gravity = gravity
	p.direction = Vector2(1, 0)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 0.0
	p.damping_max = 2.0
	if spin:
		p.angular_velocity_min = -90.0
		p.angular_velocity_max = 90.0
		p.angle_min = 0.0
		p.angle_max = 360.0
	var ramp: Gradient = Gradient.new()
	var tint: Color = Palette.get_color(Palette.STREETLAMP_GLOW) if blink else Color.WHITE
	ramp.set_color(0, Color(tint, 0.0))
	ramp.set_color(1, Color(tint, 0.0))
	ramp.add_point(0.15, Color(tint, 0.85 if blink else 0.7))
	ramp.add_point(0.8, Color(tint, 0.85 if blink else 0.7))
	if blink:
		ramp.add_point(0.4, Color(tint, 0.1))
		ramp.add_point(0.55, Color(tint, 0.9))
	p.color_ramp = ramp
	p.z_index = 1
	camera.add_child(p)
	_emitters.append(p)


func _clear_particles() -> void:
	for e: CPUParticles2D in _emitters:
		if is_instance_valid(e):
			e.queue_free()
	_emitters.clear()
