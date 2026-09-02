extends CharacterBody2D
## 町の別の怪異「追跡者」。プレイヤー（と同行中の澪）を追う。
## 状態機械：idle / patrol / suspicious / chase / search / retreat
## **聴覚を主とする。** AudioManager の直近の音源（位置・強度）で気づき、忍び足なら気づかれにくい。
## 視界は狭い扇形。darkness（0〜1、照明系が設定）が大きいほど視界は狭く、聴覚は鋭くなる。
## 捕まってもゲームオーバーにせず、指定フィールドへ押し戻す。ヒロインも狙うが、憑いた怪異の影響で主人公はわずかに狙われにくい（数値のみ）。
## 描写方針：血・遺体・ジャンプスケアに頼らない。捕獲は暗転と押し戻しだけ。

signal state_changed(state: int, previous: int)
signal captured(target: Node2D)

enum State { IDLE, PATROL, SUSPICIOUS, CHASE, SEARCH, RETREAT }
const STATE_NAMES: PackedStringArray = ["idle", "patrol", "suspicious", "chase", "search", "retreat"]

const WALK_SPEED: float = 34.0
const CHASE_SPEED: float = 62.0
const ACCEL: float = 300.0
## 聴覚：音源の半径 × この倍率以内なら聞こえる。暗いほど鋭くなる
const HEARING_BASE: float = 1.0
const HEARING_DARK_BONUS: float = 0.8
## 視界：扇形の半径と半角（度）。暗いほど狭い
const VISION_RANGE: float = 80.0
const VISION_RANGE_DARK: float = 40.0
## 照らされている対象は昼の視認距離のこの倍率まで見える
const LIT_TARGET_RANGE_BONUS: float = 1.4
const VISION_HALF_ANGLE_DEG: float = 32.0
const VISION_HALF_ANGLE_DARK_DEG: float = 18.0
const CAPTURE_DISTANCE: float = 10.0
const SUSPICIOUS_SECONDS: float = 1.2
const SEARCH_SECONDS: float = 4.0
const LOSE_SIGHT_SECONDS: float = 3.0
const PATROL_RADIUS_TILES: int = 5
const PATROL_WAIT: float = 1.5
const ANIM_FRAME_TIME: float = 0.22
const PUSHBACK_DEFAULT_FIELD: String = "F01"

## 照明系が設定する暗さ（0 明るい〜1 暗い）
var darkness: float = 0.0
var state: int = State.IDLE
var facing: Vector2i = Vector2i.DOWN
var home_position: Vector2 = Vector2.ZERO
var retreat_field_id: String = PUSHBACK_DEFAULT_FIELD

var _target: Node2D = null
var _interest_point: Vector2 = Vector2.INF
var _timer: float = 0.0
var _lost_timer: float = 0.0
var _patrol_point: Vector2 = Vector2.INF
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.seed = int(global_position.x) * 73856093 ^ int(global_position.y) * 19349663
	home_position = global_position
	AudioManager.noise_reported.connect(_on_noise)
	darkness = Lighting.darkness
	Lighting.darkness_changed.connect(func(value: float) -> void: darkness = value)
	_update_sprite()
	_set_state(State.PATROL)


func _exit_tree() -> void:
	if AudioManager.tension_active:
		AudioManager.set_tension(false)


# ── 感覚 ──

func hearing_multiplier() -> float:
	return HEARING_BASE + HEARING_DARK_BONUS * clampf(darkness, 0.0, 1.0)


func vision_range() -> float:
	return lerpf(VISION_RANGE, VISION_RANGE_DARK, clampf(darkness, 0.0, 1.0))


func vision_half_angle() -> float:
	return deg_to_rad(lerpf(VISION_HALF_ANGLE_DEG, VISION_HALF_ANGLE_DARK_DEG, clampf(darkness, 0.0, 1.0)))


func _on_noise(position: Vector2, radius: float) -> void:
	if state == State.CHASE:
		return
	if global_position.distance_to(position) <= radius * hearing_multiplier():
		_interest_point = position
		if state != State.SUSPICIOUS:
			_set_state(State.SUSPICIOUS)


## 扇形の視界に入っているか
## 視界内か。暗所でも対象が照らされていれば（懐中電灯・街灯の下）遠くから見える
func can_see(node: Node2D) -> bool:
	var to: Vector2 = node.global_position - global_position
	var range_px: float = vision_range()
	if darkness > 0.0 and Lighting.is_lit_at(node.global_position):
		range_px = maxf(range_px, VISION_RANGE * LIT_TARGET_RANGE_BONUS)
	if to.length() > range_px:
		return false
	var forward: Vector2 = Vector2(facing)
	return forward.angle_to(to) <= vision_half_angle() and absf(forward.angle_to(to)) <= vision_half_angle()


## 狙う対象。主人公は憑いた怪異の分だけわずかに狙われにくい（プレイヤーには示さない）
func _pick_target() -> Node2D:
	var candidates: Array[Node2D] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	if SceneRouter.player != null and can_see(SceneRouter.player):
		candidates.append(SceneRouter.player)
		weights.append(AttachedEntity.player_target_weight())
	if SceneRouter.heroine != null and SceneRouter.heroine.is_inside_tree() and can_see(SceneRouter.heroine):
		candidates.append(SceneRouter.heroine)
		weights.append(1.0)
	if candidates.is_empty():
		return null
	var best: int = 0
	var best_score: float = -INF
	for i: int in candidates.size():
		var score: float = weights[i] / maxf(8.0, global_position.distance_to(candidates[i].global_position))
		if score > best_score:
			best_score = score
			best = i
	return candidates[best]


# ── 状態機械 ──

func _set_state(new_state: int) -> void:
	if new_state == state:
		return
	var previous: int = state
	state = new_state
	_timer = 0.0
	_lost_timer = 0.0
	if state == State.CHASE:
		AudioManager.set_tension(true)
	elif previous == State.CHASE:
		AudioManager.set_tension(false)
	if state == State.PATROL:
		_patrol_point = Vector2.INF
	state_changed.emit(state, previous)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_timer += delta
	var seen: Node2D = _pick_target()
	match state:
		State.IDLE:
			if seen != null:
				_begin_chase(seen)
			elif _timer > PATROL_WAIT:
				_set_state(State.PATROL)
		State.PATROL:
			if seen != null:
				_begin_chase(seen)
			else:
				_do_patrol()
		State.SUSPICIOUS:
			if seen != null:
				_begin_chase(seen)
			else:
				_move_to(_interest_point, WALK_SPEED, delta)
				if _arrived(_interest_point) or _timer > SUSPICIOUS_SECONDS * 4.0:
					_set_state(State.SEARCH)
		State.CHASE:
			_do_chase(delta)
		State.SEARCH:
			if seen != null:
				_begin_chase(seen)
			else:
				_face_scan()
				velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
				if _timer > SEARCH_SECONDS:
					_set_state(State.RETREAT)
		State.RETREAT:
			if seen != null:
				_begin_chase(seen)
			else:
				_move_to(home_position, WALK_SPEED, delta)
				if _arrived(home_position):
					_set_state(State.IDLE)
	move_and_slide()
	_tick_animation(delta)


func _begin_chase(target: Node2D) -> void:
	_target = target
	_set_state(State.CHASE)


func _do_chase(delta: float) -> void:
	if _target == null or not _target.is_inside_tree():
		_set_state(State.SEARCH)
		return
	var visible: bool = can_see(_target)
	_lost_timer = 0.0 if visible else _lost_timer + delta
	if visible:
		_interest_point = _target.global_position
	elif AudioManager.has_recent_noise():
		_interest_point = AudioManager.last_noise_position
	_move_to(_interest_point, CHASE_SPEED, delta)
	if global_position.distance_to(_target.global_position) <= CAPTURE_DISTANCE:
		_capture(_target)
	elif _lost_timer > LOSE_SIGHT_SECONDS:
		_target = null
		_set_state(State.SEARCH)


func _do_patrol() -> void:
	if _patrol_point == Vector2.INF or _arrived(_patrol_point):
		if _timer < PATROL_WAIT:
			velocity = Vector2.ZERO
			return
		_timer = 0.0
		var offset: Vector2 = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * PATROL_RADIUS_TILES * GameConstants.TILE_SIZE
		_patrol_point = home_position + offset
	_move_to(_patrol_point, WALK_SPEED, get_physics_process_delta_time())


func _move_to(point: Vector2, speed: float, delta: float) -> void:
	if point == Vector2.INF:
		return
	var to: Vector2 = point - global_position
	if to.length() <= 2.0:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
		return
	velocity = velocity.move_toward(to.normalized() * speed, ACCEL * delta)
	# 壁に当たって進めないときは横へずらす
	if get_slide_collision_count() > 0 and velocity.length() < speed * 0.3:
		velocity += to.normalized().orthogonal() * speed * 0.5
	var new_facing: Vector2i = Vector2i(signi(roundi(velocity.x)), 0) if absf(velocity.x) > absf(velocity.y) else Vector2i(0, signi(roundi(velocity.y)))
	if new_facing != Vector2i.ZERO and new_facing != facing:
		facing = new_facing
		_update_sprite()
		queue_redraw()


func _arrived(point: Vector2) -> bool:
	return point != Vector2.INF and global_position.distance_to(point) <= 6.0


## 探索中はゆっくり向きを変えて周囲を見る
func _face_scan() -> void:
	var dirs: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	var index: int = int(_timer / (SEARCH_SECONDS / 4.0)) % dirs.size()
	if dirs[index] != facing:
		facing = dirs[index]
		_update_sprite()
		queue_redraw()


## 捕獲。ゲームオーバーにせず押し戻す。主人公は憑いた怪異の庇護で稀に「見失われる」
func _capture(target: Node2D) -> void:
	if target == SceneRouter.player and AttachedEntity.try_protect("stalker"):
		_target = null
		_set_state(State.RETREAT)
		AttachedEntity.comfort("after_stalker")
		return
	captured.emit(target)
	_set_state(State.RETREAT)
	if target == SceneRouter.player:
		SceneRouter.push_back_to(retreat_field_id)
	elif target == SceneRouter.heroine and SceneRouter.player != null:
		SceneRouter.heroine.snap_behind(SceneRouter.player, SceneRouter.player.facing)
		Suspicion.add(3, "heroine_caught")


func _tick_animation(delta: float) -> void:
	if velocity.length() < 3.0:
		return
	_anim_timer += delta
	if _anim_timer >= ANIM_FRAME_TIME:
		_anim_timer -= ANIM_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % ActorSpriteGenerator.FRAME_COUNT
		_update_sprite()


func _update_sprite() -> void:
	if _sprite != null:
		_sprite.texture = ActorSpriteGenerator.get_texture("stalker", facing, _anim_frame)


## デバッグ表示：状態名・聴覚半径・視界扇形（設定 debug_overlay がオンのとき）
func _draw() -> void:
	if not bool(SaveManager.get_setting("debug_overlay")):
		return
	var hearing: float = AudioManager.last_noise_radius * hearing_multiplier()
	draw_arc(Vector2.ZERO, maxf(hearing, 8.0), 0.0, TAU, 32, Palette.with_alpha(Palette.FLUORESCENT, 0.5), 1.0)
	var forward: float = Vector2(facing).angle()
	var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i: int in 9:
		var a: float = forward - vision_half_angle() + vision_half_angle() * 2.0 * i / 8.0
		pts.append(Vector2.from_angle(a) * vision_range())
	draw_colored_polygon(pts, Palette.with_alpha(Palette.VENDING_RED if state == State.CHASE else Palette.STREETLAMP_GLOW, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(-16, -26), STATE_NAMES[state], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.get_color(Palette.FLUORESCENT))


func _process(_delta: float) -> void:
	if bool(SaveManager.get_setting("debug_overlay")):
		queue_redraw()
