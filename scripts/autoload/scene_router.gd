extends Node
## フィールド間の遷移を司る autoload。
## 暗転 → 現在のフィールドを破棄 → 接続先を読み込み → 対応する出口の 1 タイル内側にプレイヤーを配置 → 明転。
## lock 付きの出口は GameState のフラグを満たすまで通れず、passage_blocked を発火する。
## 存在しない ID・未実装シーンはクラッシュさせず、エラーを出してフォールバックする。

signal transition_started(from_id: String, to_id: String)
signal field_entered(field_id: String, from_id: String)
signal transition_finished(field_id: String)
signal passage_blocked(exit: ExitData)
## その日は入れないフィールドへの出口に触れた（Calendar の available_fields 外）
signal passage_closed_today(exit: ExitData)
signal field_load_failed(field_id: String, reason: String)
## プレイヤーを生成した（AudioManager 等が接続する）
signal player_spawned(player: Node)

const PLAYER_SCENE_PATH: String = "res://scenes/actors/player.tscn"
const HEROINE_SCENE_PATH: String = "res://scenes/actors/heroine.tscn"
const COMPANION_FLAG: String = "companion_on"
const PLACEHOLDER_SCENE_PATH: String = "res://scenes/fields/field_placeholder.tscn"
const FADE_DURATION: float = 0.35
const FADE_CANVAS_LAYER: int = 100

var world_root: Node2D = null
var current_field: FieldBase = null
var current_field_id: String = ""
var player: CharacterBody2D = null
var heroine: CharacterBody2D = null
var camera: Camera2D = null
var is_transitioning: bool = false

var _fade: ColorRect = null


func _ready() -> void:
	_build_fade_layer()
	GameState.flag_raised.connect(_on_flag_changed)
	GameState.flag_cleared.connect(_on_flag_changed)


func _on_flag_changed(flag: String) -> void:
	if flag == COMPANION_FLAG:
		_sync_companion()


## 同行を切り替える（set_companion アクション・日程のフラグ操作から）
func set_companion(on: bool) -> void:
	if on:
		GameState.raise_flag(COMPANION_FLAG)
	else:
		GameState.clear_flag(COMPANION_FLAG)


## companion_on とヒロインの存在を一致させる
func _sync_companion() -> void:
	var should_follow: bool = GameState.has_flag(COMPANION_FLAG) and current_field != null and player != null
	if should_follow:
		if heroine == null:
			var packed: PackedScene = load(HEROINE_SCENE_PATH) as PackedScene
			heroine = packed.instantiate() as CharacterBody2D
		if heroine.get_parent() != current_field.get_actor_root():
			if heroine.get_parent() != null:
				heroine.get_parent().remove_child(heroine)
			current_field.get_actor_root().add_child(heroine)
		heroine.snap_behind(player, player.facing)
	elif heroine != null and heroine.get_parent() != null:
		heroine.get_parent().remove_child(heroine)


## Main シーンがワールドのルートを登録する
func register_world(root: Node2D) -> void:
	world_root = root


## ゲームシーンを離れるときに呼ぶ。フィールドとプレイヤーはシーンごと解放されるため参照を捨てる
func reset() -> void:
	world_root = null
	current_field = null
	current_field_id = ""
	player = null
	if heroine != null and heroine.get_parent() == null:
		heroine.free()
	heroine = null
	camera = null
	is_transitioning = false
	_fade.color = Palette.with_alpha(Palette.FADE_BLACK, 0.0)


## 起動時：GameState.current_field_id のフィールドを読み込む
func start() -> void:
	if world_root == null:
		push_error("SceneRouter: register_world() が呼ばれていません")
		return
	_ensure_player()
	var id: String = GameState.current_field_id
	if not FieldRegistry.is_loaded:
		push_error("SceneRouter: FieldRegistry が読み込まれていないため、エラー表示のプレースホルダを出します")
		_mount_field(_make_placeholder(null, "\n".join(FieldRegistry.load_errors)), null, "")
		return
	if not FieldRegistry.has_field(id):
		push_error("SceneRouter: フィールド '%s' は存在しません。初期フィールド %s にフォールバックします" % [id, GameState.INITIAL_FIELD_ID])
		id = GameState.INITIAL_FIELD_ID
		GameState.player_position = Vector2.ZERO
	_load_field(id, "")
	_fade.color = Palette.with_alpha(Palette.FADE_BLACK, 1.0)
	_fade_to(0.0)


## 出口に到達したときの遷移要求（FieldBase.exit_reached から）
func request_transition(exit: ExitData) -> void:
	if exit == null:
		push_error("SceneRouter: null の出口が渡されました")
		return
	if is_transitioning:
		return
	if not FieldRegistry.is_exit_open(exit) or not FieldRegistry.is_unlocked(exit.to_id):
		_push_back_from_exit(exit)
		passage_blocked.emit(exit)
		return
	if not Calendar.is_field_available(exit.to_id):
		_push_back_from_exit(exit)
		passage_closed_today.emit(exit)
		return
	_transition_to(exit.to_id, exit.from_id)


## 捕獲などで指定フィールドへ押し戻す。開放外なら自宅へ。遷移中は無視
func push_back_to(field_id: String) -> void:
	if is_transitioning:
		return
	var target: String = field_id if FieldRegistry.has_field(field_id) and Calendar.is_field_available(field_id) else GameState.HOME_FIELD_ID
	_transition_to(target, current_field_id)


## 任意のフィールドへ直接移動する（デバッグ・イベント用）
func go_to(field_id: String, from_id: String = "") -> void:
	if is_transitioning:
		return
	if not FieldRegistry.has_field(field_id):
		push_error("SceneRouter: go_to('%s') 存在しないフィールドです" % field_id)
		return
	if not Calendar.is_field_available(field_id):
		push_warning("SceneRouter: go_to('%s') は day %d の開放外です（デバッグ移動として続行）" % [field_id, Calendar.day])
	_transition_to(field_id, from_id)


func _transition_to(to_id: String, from_id: String) -> void:
	is_transitioning = true
	player.input_enabled = false
	transition_started.emit(from_id, to_id)
	await _fade_to(1.0)
	_load_field(to_id, from_id)
	await _fade_to(0.0)
	player.input_enabled = true
	is_transitioning = false
	transition_finished.emit(to_id)


## 現在のフィールドを外し、to_id のフィールドを組み立てて配置する
func _load_field(to_id: String, from_id: String) -> void:
	var def: FieldData = FieldRegistry.get_field(to_id)
	var scene: FieldBase = _instantiate_field(def, to_id)
	_mount_field(scene, def, from_id)


func _mount_field(scene: FieldBase, def: FieldData, from_id: String) -> void:
	_unmount_current()
	scene.setup(def)
	world_root.add_child(scene)
	scene.get_actor_root().add_child(player)
	scene.exit_reached.connect(request_transition)
	# 出現位置：出口から来たならその内側、起動直後でセーブ座標があればそこ、無ければ既定位置
	if from_id.is_empty() and GameState.player_position != Vector2.ZERO and GameState.current_field_id == (def.id if def != null else ""):
		player.global_position = GameState.player_position
		player.facing = GameState.player_facing
		player.velocity = Vector2.ZERO
	else:
		player.place_at_tile(scene.get_spawn_tile(from_id), scene.get_spawn_facing(from_id))
	_apply_camera_limits(scene)
	current_field = scene
	current_field_id = def.id if def != null else ""
	_sync_companion()
	if def != null:
		GameState.set_current_field(def.id)
	GameState.set_player_pose(player.global_position, player.facing)
	if def != null:
		GameState.mark_visited(def.id)
	field_entered.emit(current_field_id, from_id)


func _unmount_current() -> void:
	if current_field == null:
		return
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	if heroine != null and heroine.get_parent() != null:
		heroine.get_parent().remove_child(heroine)
	world_root.remove_child(current_field)
	current_field.queue_free()
	current_field = null


## scene_path が存在し FieldBase を継承していればそれを、そうでなければプレースホルダを返す
func _instantiate_field(def: FieldData, id: String) -> FieldBase:
	if def == null:
		field_load_failed.emit(id, "定義が存在しない")
		return _make_placeholder(null, "フィールド '%s' の定義がありません" % id)
	if not ResourceLoader.exists(def.scene_path):
		push_warning("SceneRouter: %s のシーン %s は未実装のためプレースホルダを表示します" % [def.id, def.scene_path])
		return _make_placeholder(def, "")
	var packed: PackedScene = load(def.scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: %s を PackedScene として読み込めません" % def.scene_path)
		field_load_failed.emit(id, "PackedScene ではない")
		return _make_placeholder(def, "")
	var instance: Node = packed.instantiate()
	var field: FieldBase = instance as FieldBase
	if field == null:
		push_error("SceneRouter: %s のルートは FieldBase を継承する必要があります" % def.scene_path)
		field_load_failed.emit(id, "ルートが FieldBase ではない")
		instance.free()
		return _make_placeholder(def, "")
	return field


func _make_placeholder(def: FieldData, reason: String) -> FieldBase:
	var packed: PackedScene = load(PLACEHOLDER_SCENE_PATH) as PackedScene
	var placeholder: FieldBase = packed.instantiate() as FieldBase
	placeholder.set("failure_reason", reason)
	if def == null and reason.is_empty():
		placeholder.set("failure_reason", "定義なし")
	return placeholder


func _ensure_player() -> void:
	if player != null:
		return
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	player = packed.instantiate() as CharacterBody2D
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = false
	camera.position = Vector2(0, -GameConstants.TILE_SIZE * 0.5)
	# enabled=true のカメラはツリーに入った時点で current になる（ツリー外で make_current は呼べない）
	camera.enabled = true
	player.add_child(camera)
	player_spawned.emit(player)


## 階の切替などで寸法が変わったときに呼ぶ
func refresh_camera_limits() -> void:
	if current_field != null and camera != null:
		_apply_camera_limits(current_field)


## カメラをフィールドの外へ出さない
func _apply_camera_limits(scene: FieldBase) -> void:
	var bounds: Rect2i = scene.get_bounds_px()
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
	camera.reset_smoothing()


## 通れない出口に触れたプレイヤーを 1 タイル内側へ戻す（トリガーの連続発火を防ぐ）
func _push_back_from_exit(exit: ExitData) -> void:
	if current_field == null or exit.from_id != current_field_id:
		return
	player.place_at_tile(exit.inward_tile(), player.facing)


func _build_fade_layer() -> void:
	_fade = ScreenFade.build(self, FADE_CANVAS_LAYER)


## 画面の暗転を明示的に行う（fade アクション。終幕の間の取り方に使う）
func fade_screen(alpha: float, seconds: float) -> void:
	await ScreenFade.fade(self, _fade, alpha, seconds)


func _fade_to(alpha: float) -> void:
	await ScreenFade.fade(self, _fade, alpha, FADE_DURATION)
