extends CharacterBody2D
## ヒロイン・澪。プレイヤーに追従し、接近度の段階に応じて振る舞いが変わる。
## - 無自覚：近く（2 タイル）を歩く　- 違和感：半歩下がる（3 タイル）
## - 疑念：距離を取り（4 タイル）、主人公が止まると先回りする　- 確信：さらに離れ（5 タイル）、頻繁に主人公を見る
## 障害物や遷移で見失ったら瞬間的に復帰する。特定の証拠の前で独自の発言をする。
## 隠蔽の目撃判定（is_near）を EvidenceRegistry に登録する。

signal remarked(evidence_id: String)

const SPEED: float = 3.75 * GameConstants.TILE_SIZE
const ACCEL: float = 22.5 * GameConstants.TILE_SIZE
const TRAIL_STEP: float = 0.5 * GameConstants.TILE_SIZE
const TRAIL_MAX: int = 96
const ARRIVE_DISTANCE: float = 0.25 * GameConstants.TILE_SIZE
## 段階（無自覚／違和感／疑念／確信）ごとの目撃半径（px）。
## 必ず追従距離 FOLLOW_TILES × 16px より小さくする。普通に追従している澪には見られず、
## 遷移直後や先回りで近くにいるとき、澪が追いつく前に調べなかったときだけ目撃される。
## （実機検証で、追従距離 ≥ 目撃半径だと同行中の隠蔽が全て失敗すると分かったため。docs/PLAYTEST_LOG.md）
const WITNESS_RADIUS_BY_STAGE: PackedFloat32Array = [1.5 * GameConstants.TILE_SIZE, 2.5 * GameConstants.TILE_SIZE, 3.5 * GameConstants.TILE_SIZE, 4.5 * GameConstants.TILE_SIZE]
const LOST_DISTANCE: float = 10.0 * GameConstants.TILE_SIZE
const STUCK_SECONDS: float = 1.2
const AHEAD_IDLE_SECONDS: float = 2.0
## 段階ごとの追従距離（タイル）／先回りする確率／主人公を見る間隔（秒、0 は見ない）
const FOLLOW_TILES: PackedInt32Array = [2, 3, 4, 5]
const AHEAD_CHANCE: PackedFloat32Array = [0.0, 0.0, 0.3, 0.5]
const LOOK_INTERVAL: PackedFloat32Array = [0.0, 6.0, 3.0, 1.5]
const LOOK_HOLD: float = 1.0
const ANIM_FRAME_TIME: float = 0.18
## 足音の間隔（秒）。主人公より軽く少し速い
const STEP_INTERVAL: float = 0.34

var facing: Vector2i = Vector2i.DOWN
var is_active: bool = true

var _trail: Array[Vector2] = []
var _last_trail_pos: Vector2 = Vector2.INF
var _stuck_timer: float = 0.0
var _idle_timer: float = 0.0
var _look_timer: float = 0.0
var _look_hold: float = 0.0
var _ahead_target: Vector2 = Vector2.INF
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _step_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_rng.seed = 20260801
	EvidenceRegistry.set_witness_check(is_near)
	EvidenceRegistry.evidence_gained.connect(_on_evidence_gained)
	_update_sprite()


## 隠蔽の目撃判定。同行中で、位置から目撃半径以内なら true。接近度の段階が進むほど半径が広がる（第二幕で失敗しやすくなる）
func is_near(position: Vector2) -> bool:
	if not is_active or not is_inside_tree():
		return false
	var stage: int = clampi(Suspicion.get_stage(), 0, WITNESS_RADIUS_BY_STAGE.size() - 1)
	return global_position.distance_to(position) <= WITNESS_RADIUS_BY_STAGE[stage]


## プレイヤーの隣（後ろ）に即座に配置する（遷移直後・見失い時）
func snap_behind(player: Node2D, player_facing: Vector2i) -> void:
	global_position = player.global_position - Vector2(player_facing) * GameConstants.TILE_SIZE
	velocity = Vector2.ZERO
	_trail.clear()
	_last_trail_pos = Vector2.INF
	facing = player_facing
	_update_sprite()


func _physics_process(delta: float) -> void:
	var player: CharacterBody2D = SceneRouter.player
	if player == null or not is_active:
		return
	# イベント中（会話・隠蔽）は主人公と同じく足を止める。歩き続けると本文を読んでいる間に隣まで来てしまう
	if EventSystem.is_running or not player.input_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
		move_and_slide()
		_tick_animation(delta)
		return
	_record_trail(player.global_position)
	var stage: int = Suspicion.get_stage()
	var target: Vector2 = _pick_target(player, stage, delta)
	var to_target: Vector2 = target - global_position
	if to_target.length() > ARRIVE_DISTANCE:
		velocity = velocity.move_toward(to_target.normalized() * SPEED, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
	move_and_slide()
	_tick_footsteps(delta)
	_check_lost(player, target, delta)
	_update_facing(player, stage, delta)
	_tick_animation(delta)


func _record_trail(player_pos: Vector2) -> void:
	if _last_trail_pos == Vector2.INF or player_pos.distance_to(_last_trail_pos) >= TRAIL_STEP:
		_trail.append(player_pos)
		_last_trail_pos = player_pos
		if _trail.size() > TRAIL_MAX:
			_trail.pop_front()


## 追従先：段階に応じた距離だけ軌跡を遡った点。疑念以上で主人公が止まっていれば先回り点
func _pick_target(player: CharacterBody2D, stage: int, delta: float) -> Vector2:
	var idle: bool = player.velocity.length() < 0.25 * GameConstants.TILE_SIZE
	_idle_timer = _idle_timer + delta if idle else 0.0
	if _ahead_target != Vector2.INF:
		if not idle:
			_ahead_target = Vector2.INF
		else:
			return _ahead_target
	if idle and _idle_timer >= AHEAD_IDLE_SECONDS and _rng.randf() < AHEAD_CHANCE[stage] * delta:
		_ahead_target = player.global_position + Vector2(player.facing) * GameConstants.TILE_SIZE * 3.0
		return _ahead_target
	var steps_back: int = int(FOLLOW_TILES[stage] * GameConstants.TILE_SIZE / TRAIL_STEP)
	var index: int = _trail.size() - 1 - steps_back
	if index >= 0:
		return _trail[index]
	return player.global_position - Vector2(player.facing) * GameConstants.TILE_SIZE * FOLLOW_TILES[stage]


func _check_lost(player: CharacterBody2D, target: Vector2, delta: float) -> void:
	var far: bool = global_position.distance_to(target) > ARRIVE_DISTANCE * 4.0
	_stuck_timer = _stuck_timer + delta if far and velocity.length() < 0.125 * GameConstants.TILE_SIZE else 0.0
	if global_position.distance_to(player.global_position) > LOST_DISTANCE or _stuck_timer > STUCK_SECONDS:
		snap_behind(player, player.facing)
		_stuck_timer = 0.0


## 向き：移動方向。段階が進むほど頻繁に主人公の方を見る
func _update_facing(player: CharacterBody2D, stage: int, delta: float) -> void:
	if _look_hold > 0.0:
		_look_hold -= delta
		_face_toward(player.global_position)
		return
	var interval: float = LOOK_INTERVAL[stage]
	if interval > 0.0:
		_look_timer += delta
		if _look_timer >= interval:
			_look_timer = 0.0
			_look_hold = LOOK_HOLD
			return
	if velocity.length() > 0.25 * GameConstants.TILE_SIZE:
		var dir: Vector2 = velocity
		var new_facing: Vector2i = Vector2i(signi(roundi(dir.x)), 0) if absf(dir.x) > absf(dir.y) else Vector2i(0, signi(roundi(dir.y)))
		if new_facing != Vector2i.ZERO and new_facing != facing:
			facing = new_facing
			_update_sprite()


func _face_toward(point: Vector2) -> void:
	var d: Vector2 = point - global_position
	var new_facing: Vector2i = Vector2i(signi(roundi(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(roundi(d.y)))
	if new_facing != Vector2i.ZERO and new_facing != facing:
		facing = new_facing
		_update_sprite()


func _tick_footsteps(delta: float) -> void:
	if velocity.length() < 0.25 * GameConstants.TILE_SIZE:
		_step_timer = 0.0
		return
	_step_timer += delta
	if _step_timer >= STEP_INTERVAL:
		_step_timer -= STEP_INTERVAL
		AudioManager.play_heroine_footstep()


func _tick_animation(delta: float) -> void:
	if velocity.length() < 0.25 * GameConstants.TILE_SIZE:
		if _anim_frame != 0:
			_anim_frame = 0
			_update_sprite()
		return
	_anim_timer += delta
	if _anim_timer >= ANIM_FRAME_TIME:
		_anim_timer -= ANIM_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % ActorSpriteGenerator.FRAME_COUNT
		_update_sprite()


func _update_sprite() -> void:
	if _sprite != null:
		_sprite.texture = ActorSpriteGenerator.get_texture("heroine", facing, _anim_frame)


## 特定の証拠の前で独自の発言をする。messages.json に heroine_remark_<evidence_id> があれば表示
func _on_evidence_gained(evidence_id: String) -> void:
	if not is_active:
		return
	var id: String = "heroine_remark_%s" % evidence_id
	if not MessageResolver.has_message(id):
		return
	if EventSystem.is_running:
		await EventSystem.event_finished
	_look_hold = LOOK_HOLD
	await EventSystem.show_entry(MessageResolver.resolve(id))
	remarked.emit(evidence_id)
