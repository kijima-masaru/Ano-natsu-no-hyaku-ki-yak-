extends Node
## ストーリーフラグ・所持アイテム・現在フィールド・プレイヤー座標を保持する autoload。
## セーブ／ロードは API（シグネチャ）だけを定義し、ファイル I/O は後のステップで実装する。
## 状態の変更は必ずこのクラスの関数経由で行い、変更はシグナルで通知する。

signal flag_raised(flag: String)
signal flag_cleared(flag: String)
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal current_field_changed(field_id: String, previous_id: String)
signal state_reset()

## 自宅（就寝できる唯一の場所）。schedule.json の meta.home_field と一致させる
const HOME_FIELD_ID: String = "F12"
## 起動時に読み込むフィールド。8/1 は自宅で目覚める（SCENARIO.md §5）
const INITIAL_FIELD_ID: String = HOME_FIELD_ID
const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"

var flags: Dictionary[String, bool] = {}
var items: PackedStringArray = PackedStringArray()
var current_field_id: String = INITIAL_FIELD_ID
## ワールド座標（フィールド内のピクセル位置）
var player_position: Vector2 = Vector2.ZERO
## 向き。上下左右の単位ベクトル
var player_facing: Vector2i = Vector2i.DOWN
var play_time_sec: float = 0.0


func _process(delta: float) -> void:
	play_time_sec += delta


# ── フラグ ──

func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func raise_flag(flag: String) -> void:
	if flag.is_empty():
		push_error("GameState: 空のフラグ名は立てられません")
		return
	if has_flag(flag):
		return
	flags[flag] = true
	flag_raised.emit(flag)


func clear_flag(flag: String) -> void:
	if not flags.has(flag):
		return
	flags.erase(flag)
	flag_cleared.emit(flag)


# ── アイテム ──

func has_item(item_id: String) -> bool:
	return items.has(item_id)


func add_item(item_id: String) -> void:
	if item_id.is_empty():
		push_error("GameState: 空のアイテム ID は追加できません")
		return
	if has_item(item_id):
		return
	items.append(item_id)
	item_added.emit(item_id)


func remove_item(item_id: String) -> bool:
	var index: int = items.find(item_id)
	if index < 0:
		return false
	items.remove_at(index)
	item_removed.emit(item_id)
	return true


# ── 位置 ──

func set_current_field(field_id: String) -> void:
	if field_id == current_field_id:
		return
	var previous: String = current_field_id
	current_field_id = field_id
	current_field_changed.emit(field_id, previous)


func set_player_pose(position: Vector2, facing: Vector2i) -> void:
	player_position = position
	player_facing = facing


# ── シリアライズ（セーブ形式の定義。I/O は後のステップ） ──

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"flags": flags.duplicate(),
		"items": Array(items),
		"current_field_id": current_field_id,
		"player_position": [player_position.x, player_position.y],
		"player_facing": [player_facing.x, player_facing.y],
		"play_time_sec": play_time_sec,
	}


## 辞書から状態を復元する。形式が不正なら false（状態は変更しない）
func from_dict(d: Dictionary) -> bool:
	if int(d.get("version", -1)) != SAVE_VERSION:
		push_error("GameState: セーブデータの version %s は未対応です（対応 %d）" % [str(d.get("version", "?")), SAVE_VERSION])
		return false
	var pos: Variant = d.get("player_position", [0, 0])
	var facing: Variant = d.get("player_facing", [0, 1])
	if not (pos is Array and (pos as Array).size() == 2 and facing is Array and (facing as Array).size() == 2):
		push_error("GameState: player_position / player_facing の形式が不正です")
		return false
	reset()
	var flag_dict: Variant = d.get("flags", {})
	if flag_dict is Dictionary:
		for key: Variant in (flag_dict as Dictionary).keys():
			if bool((flag_dict as Dictionary)[key]):
				flags[str(key)] = true
	var item_list: Variant = d.get("items", [])
	if item_list is Array:
		for v: Variant in item_list as Array:
			items.append(str(v))
	current_field_id = str(d.get("current_field_id", INITIAL_FIELD_ID))
	player_position = Vector2(float((pos as Array)[0]), float((pos as Array)[1]))
	player_facing = Vector2i(int((facing as Array)[0]), int((facing as Array)[1]))
	play_time_sec = float(d.get("play_time_sec", 0.0))
	return true


## 全状態を初期化する（ニューゲーム）
func reset() -> void:
	flags.clear()
	items.clear()
	current_field_id = INITIAL_FIELD_ID
	player_position = Vector2.ZERO
	player_facing = Vector2i.DOWN
	play_time_sec = 0.0
	state_reset.emit()


# ── セーブ／ロード（インターフェースのみ） ──

## 指定スロットへ保存する。TODO(step-final): user://saves への書き出しと SteamBridge.cloud_save 連携
func save_game(slot: int) -> Error:
	push_warning("GameState.save_game(%d) は未実装です（ステップ最終で実装）" % slot)
	return ERR_UNAVAILABLE


## 指定スロットから読み込む。TODO(step-final): user://saves の読み出しと from_dict の適用
func load_game(slot: int) -> Error:
	push_warning("GameState.load_game(%d) は未実装です（ステップ最終で実装）" % slot)
	return ERR_UNAVAILABLE


func has_save(slot: int) -> bool:
	return FileAccess.file_exists("%s/slot_%02d.json" % [SAVE_DIR, slot])
