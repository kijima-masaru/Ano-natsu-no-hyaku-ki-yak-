extends CharacterBody2D
## プレイヤー。4 方向移動（斜め不可）、歩行／忍び足の 2 速度、前方の調べ判定。
## 緊張感のために立ち上がりと停止に僅かな加減速を持たせ、キビキビ動きすぎないようにする。
## 足音は noise_emitted(radius) として周期的に通知し、追跡者の聴覚が拾う。
## 懐中電灯（Lighting.attach_flashlight）は前方の扇形。電池の概念は無い。点けると暗所でも見えるが、追跡者に見つかりやすい。

signal noise_emitted(radius: float)
signal interaction_requested(target: Node)
signal facing_changed(facing: Vector2i)

const WALK_SPEED: float = 4.0 * GameConstants.TILE_SIZE
const SNEAK_SPEED: float = 1.625 * GameConstants.TILE_SIZE
const ACCELERATION: float = 20.0 * GameConstants.TILE_SIZE
const DECELERATION: float = 30.0 * GameConstants.TILE_SIZE
const WALK_NOISE_RADIUS: float = 4.0 * GameConstants.TILE_SIZE
const SNEAK_NOISE_RADIUS: float = 1.0 * GameConstants.TILE_SIZE
const WALK_STEP_INTERVAL: float = 0.34
const SNEAK_STEP_INTERVAL: float = 0.62
const ANIM_FRAME_TIME: float = 0.17
## 前方判定の中心を体の原点からどれだけ離すか（px）
const PROBE_DISTANCE: float = 0.625 * GameConstants.TILE_SIZE
const MOVING_THRESHOLD: float = 0.25 * GameConstants.TILE_SIZE
## 懐中電灯の光源位置（足元より少し上、胸の高さ）
const FLASHLIGHT_HEIGHT_OFFSET: float = -0.5 * GameConstants.TILE_SIZE

## 遷移中などに入力を止める
var input_enabled: bool = true
var facing: Vector2i = Vector2i.DOWN:
	set(value):
		if value == facing or value == Vector2i.ZERO:
			return
		facing = value
		_update_probe()
		_update_sprite()
		_update_flashlight()
		facing_changed.emit(facing)
var is_sneaking: bool = false
## 絵の種別（ActorSpriteGenerator）。8/31 は澪を操作するため "heroine" になる（GameConstants.POV_HEROINE_FLAG）
var sprite_kind: String = "player"

var _step_timer: float = 0.0
var _anim_timer: float = 0.0
var _anim_frame: int = 0

@onready var _sprite: Sprite2D = $Sprite
@onready var _probe: Area2D = $InteractProbe
var _flashlight: PointLight2D = null


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_flashlight = Lighting.attach_flashlight(self)
	GameState.flag_raised.connect(_on_pov_flag_changed)
	GameState.flag_cleared.connect(_on_pov_flag_changed)
	GameState.state_reset.connect(func() -> void: _on_pov_flag_changed(GameConstants.POV_HEROINE_FLAG))
	_refresh_persona()
	_update_probe()
	_update_sprite()
	_update_flashlight()


func _physics_process(delta: float) -> void:
	var direction: Vector2i = _read_direction() if input_enabled else Vector2i.ZERO
	is_sneaking = input_enabled and Input.is_action_pressed("sneak")
	var speed: float = SNEAK_SPEED if is_sneaking else WALK_SPEED
	var target: Vector2 = Vector2(direction) * speed
	var rate: float = ACCELERATION if direction != Vector2i.ZERO else DECELERATION
	velocity = velocity.move_toward(target, rate * delta)
	if direction != Vector2i.ZERO:
		facing = direction
	move_and_slide()
	_tick_footsteps(delta)
	_tick_animation(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("interact"):
		var target: Node = find_interact_target()
		if target != null:
			interaction_requested.emit(target)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("flashlight"):
		Lighting.set_flashlight(not Lighting.flashlight_on)
		get_viewport().set_input_as_handled()


## 4 方向のみ。斜め入力は「今向いている軸」を優先し、どちらでもなければ横を採る
func _read_direction() -> Vector2i:
	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var x: int = signi(roundi(raw.x))
	var y: int = signi(roundi(raw.y))
	if x != 0 and y != 0:
		if facing.y != 0:
			x = 0
		else:
			y = 0
	return Vector2i(x, y)


func _tick_footsteps(delta: float) -> void:
	if velocity.length() < MOVING_THRESHOLD:
		_step_timer = 0.0
		return
	_step_timer += delta
	var interval: float = SNEAK_STEP_INTERVAL if is_sneaking else WALK_STEP_INTERVAL
	if _step_timer >= interval:
		_step_timer -= interval
		noise_emitted.emit(SNEAK_NOISE_RADIUS if is_sneaking else WALK_NOISE_RADIUS)


func _tick_animation(delta: float) -> void:
	if velocity.length() < MOVING_THRESHOLD:
		if _anim_frame != 0:
			_anim_frame = 0
			_update_sprite()
		return
	_anim_timer += delta * (0.6 if is_sneaking else 1.0)
	if _anim_timer >= ANIM_FRAME_TIME:
		_anim_timer -= ANIM_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % ActorSpriteGenerator.FRAME_COUNT
		_update_sprite()


func _on_pov_flag_changed(flag: String) -> void:
	if flag == GameConstants.POV_HEROINE_FLAG:
		_refresh_persona()


func _refresh_persona() -> void:
	sprite_kind = "heroine" if GameState.has_flag(GameConstants.POV_HEROINE_FLAG) else "player"
	_update_sprite()


func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.texture = ActorSpriteGenerator.get_texture(sprite_kind, facing, _anim_frame)


func _update_probe() -> void:
	if _probe == null:
		return
	_probe.position = (Vector2(facing) * PROBE_DISTANCE).round()


## 懐中電灯の扇形（+X 向きのテクスチャ）を向きに合わせて回す
func _update_flashlight() -> void:
	if _flashlight == null:
		return
	_flashlight.rotation = Vector2(facing).angle()
	_flashlight.position = Vector2(0, FLASHLIGHT_HEIGHT_OFFSET)


## 前方にある調べ対象。無ければ null。複数あれば最も近いもの
func find_interact_target() -> Node:
	var best: Node = null
	var best_distance: float = INF
	for area: Area2D in _probe.get_overlapping_areas():
		if not area.is_in_group("interactable"):
			continue
		var d: float = global_position.distance_squared_to(area.global_position)
		if d < best_distance:
			best_distance = d
			best = area
	return best


## タイル座標へ即座に配置する（フィールド遷移時に SceneRouter から呼ぶ）
func place_at_tile(tile: Vector2i, new_facing: Vector2i = Vector2i.ZERO) -> void:
	global_position = GameConstants.tile_to_world(tile) + Vector2(0, GameConstants.TILE_SIZE * 0.5 - 1)
	velocity = Vector2.ZERO
	if new_facing != Vector2i.ZERO:
		facing = new_facing


func get_tile() -> Vector2i:
	return GameConstants.world_to_tile(global_position + Vector2(0, -1))
