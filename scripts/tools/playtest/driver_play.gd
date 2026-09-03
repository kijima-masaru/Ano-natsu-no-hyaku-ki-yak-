extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_play.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## 実機検証ドライバ 2：タイトル → 8/1 → 指定日まで、開放フィールドの調べ物を総当たりで巡り、就寝で日送りする。
## 進行不能（can_advance にならない）日を BLOCKER として記録する。移動は瞬間移動（SceneRouter.go_to）で代替する。

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MAX_INTERACTIONS_PER_ID: int = 3
const MAX_SWEEPS_PER_DAY: int = 3
const SETTLE_FRAMES_MAX: int = 2400
const STOP_DAY: int = 30

var _main: Node = null
var _window: Node = null
var _log: PackedStringArray = PackedStringArray()
var _failed_actions: PackedStringArray = PackedStringArray()
var _stop_day: int = STOP_DAY
var _witness: bool = false
## true なら必要 P に達しても全フィールドの調べ物を使い切る（後日の供給が最も厳しい経路）
var _thorough: bool = false
var _stats: Dictionary = {}
var _sus: Dictionary = {}
var _sus_n: Dictionary = {}
## 実プレイ時間の見積もり（秒）：歩行＝タイル間距離／歩行速度、遷移＝暗転 0.7 s、本文＝文字数／9 字/s ＋ 頁 0.8 s、選択肢 2 s、就寝 3 s
const READ_CPS: float = 9.0
const PAGE_SEC: float = 0.8
const TRANSITION_SEC: float = 0.7
const CHOICE_SEC: float = 2.0
const SLEEP_SEC: float = 3.0
var _est_walk: float = 0.0
var _est_read: float = 0.0
var _est_misc: float = 0.0
var _last_pos: Vector2 = Vector2.INF
var _pages_seen: int = 0
var _chars_seen: int = 0
## 一度読んだ頁は再読しない前提で数える（同じ看板を毎日読み直す時間は含めない）
var _read_pages: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a: String in args:
		if a.begins_with("--stop-day="):
			_stop_day = int(a.trim_prefix("--stop-day="))
		elif a == "--witness":
			_witness = true
		elif a == "--thorough":
			_thorough = true
	Engine.time_scale = 4.0
	# 監視：一定時間で強制終了（無限ループ対策）
	get_tree().create_timer(420.0, true, false, true).timeout.connect(func() -> void:
		_logline("   WATCHDOG: 420 秒経過で打ち切り（day %d）" % Calendar.day)
		_report(0)
		get_tree().quit(2))
	SaveManager.set_setting("instant_text", true)
	SaveManager.set_setting("text_speed", 1.0)
	EventSystem.action_failed.connect(func(eid: String, action: Dictionary, reason: String) -> void:
		_failed_actions.append("%s: %s (%s)" % [eid, JSON.stringify(action), reason]))
	Suspicion.changed.connect(func(_v: int, delta: int, reason: String) -> void:
		_sus[reason] = int(_sus.get(reason, 0)) + delta
		_sus_n[reason] = int(_sus_n.get(reason, 0)) + 1)
	SceneRouter.field_load_failed.connect(func(fid: String, reason: String) -> void: _failed_actions.append("field_load_failed %s: %s" % [fid, reason]))
	await get_tree().process_frame
	# タイトルの「はじめる」相当
	GameState.reset()
	Calendar.set_day(1)
	get_tree().change_scene_to_file(MAIN_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	_main = get_tree().current_scene
	_window = _main.get("_message_window")
	_window.connect("opened", func() -> void:
		var pages: PackedStringArray = _window.get("_pages")
		_pages_seen += pages.size()
		for pg: String in pages:
			if _read_pages.has(pg):
				continue
			_read_pages[pg] = true
			_chars_seen += pg.length()
			_est_read += pg.length() / READ_CPS + PAGE_SEC)
	SceneRouter.field_entered.connect(func(_fid: String, _from: String) -> void: _last_pos = Vector2.INF)
	var t_start: int = Time.get_ticks_msec()
	await _settle()
	while Calendar.day < _stop_day:
		var ok: bool = await _play_day()
		if not ok:
			break
	_report(t_start)
	_check_two_layer()
	await _check_save_load()
	get_tree().quit(0)


## truth_revealed を立て、truth_id を持つ全メッセージが真相版に差し替わるか
func _check_two_layer() -> void:
	var was: bool = GameState.has_flag("truth_revealed")
	GameState.raise_flag("truth_revealed")
	var pairs: int = 0
	var bad: PackedStringArray = PackedStringArray()
	for id: String in MessageResolver.get_message_ids():
		var surface: MessageEntry = MessageResolver.resolve(id)
		if surface.truth_id.is_empty() and not surface.is_truth:
			continue
		pairs += 1
		if not surface.is_truth:
			bad.append("%s: 真相版にならない" % id)
		elif surface.text == MessageResolver.resolve(surface.id).text and surface.id == id:
			bad.append("%s: 表層と同文" % id)
	GameState.clear_flag("truth_revealed")
	var surface_ok: int = 0
	for id: String in MessageResolver.get_message_ids():
		if not MessageResolver.resolve(id).is_truth:
			surface_ok += 1
	if was:
		GameState.raise_flag("truth_revealed")
	print("二層: truth_id 付き %d 件 → 真相版 %d 件 / 不正 %d 件 / 解除後の表層 %d 件" % [pairs, pairs - bad.size(), bad.size(), surface_ok])
	for b: String in bad:
		print("  " + b)


## セーブ → 状態を壊す → ロード → 復元されるか
func _check_save_load() -> void:
	var before: Dictionary = {"gs": GameState.to_dict(), "cal": Calendar.to_dict(), "sus": Suspicion.to_dict(), "an": AnomalySystem.to_dict(), "ent": AttachedEntity.to_dict()}
	var err: Error = SaveManager.save_game(1)
	print("save_game(1) -> %s" % error_string(err))
	GameState.reset()
	Calendar.set_day(1)
	await get_tree().process_frame
	err = SaveManager.load_game(1)
	print("load_game(1) -> %s" % error_string(err))
	var after: Dictionary = {"gs": GameState.to_dict(), "cal": Calendar.to_dict(), "sus": Suspicion.to_dict(), "an": AnomalySystem.to_dict(), "ent": AttachedEntity.to_dict()}
	for k: String in before.keys():
		var a: String = JSON.stringify(before[k], "", true)
		var b: String = JSON.stringify(after[k], "", true)
		print("  section %s: %s" % [k, "一致" if a == b else "不一致\n    before=%s\n    after=%s" % [a.substr(0, 400), b.substr(0, 400)]])


func _play_day() -> bool:
	var day: int = Calendar.day
	var s: DaySchedule = Calendar.get_schedule(day)
	var flags_before: int = GameState.flags.size()
	_logline("── day %d %s (%s) 必要=%s 開放=%s" % [day, s.title, s.type, str(s.required_points) if s.is_free() else s.condition_flag, ",".join(s.available_fields)])
	var interactions: int = 0
	var counts: Dictionary = {}
	for sweep: int in MAX_SWEEPS_PER_DAY:
		if Calendar.can_advance():
			break
		for fid: String in s.available_fields:
			if Calendar.can_advance() and not _thorough:
				break
			await _go(fid)
			var guard: int = 0
			while guard < 60:
				guard += 1
				var field: FieldBase = SceneRouter.current_field
				if field == null or SceneRouter.current_field_id != fid:
					break
				var next_id: String = _pick_next(field, counts)
				if next_id.is_empty():
					break
				var key: String = "%s/%s/%s" % [fid, field.current_floor, next_id]
				counts[key] = int(counts.get(key, 0)) + 1
				await _interact(next_id)
				interactions += 1
				if Calendar.can_advance() and Calendar.day == day and not _thorough:
					break
			if Calendar.day != day:
				break
		if Calendar.day != day:
			break
	if Calendar.day != day:
		_logline("   （日中に日送りが起きた → day %d）" % Calendar.day)
		return true
	if not Calendar.can_advance():
		_logline("   BLOCKER: day %d の進行条件を満たせない（P=%d flags+%d 調べ=%d）" % [day, Calendar.investigation_points, GameState.flags.size() - flags_before, interactions])
		_logline("   flags: %s" % ", ".join(_new_flags()))
		return false
	_logline("   P=%d tod=%s 調べ=%d 接近度=%d flags+%d 新規: %s" % [Calendar.investigation_points, Calendar.time_of_day, interactions, Suspicion.value, GameState.flags.size() - flags_before, ", ".join(_new_flags())])
	await _sleep_home(day)
	if Calendar.day == day:
		_logline("   BLOCKER: 就寝しても day が進まない")
		return false
	return true


## 未消化の調べ物（save_point と自宅の扉を除く）。同じ ID は最大 MAX_INTERACTIONS_PER_ID 回
func _pick_next(field: FieldBase, counts: Dictionary) -> String:
	for node: Node in field.triggers.get_children():
		var it: Interactable = node as Interactable
		if it == null or it.kind == "save_point":
			continue
		if it.interaction_id == "home_door" and Calendar.can_advance() and not _thorough:
			continue
		var key: String = "%s/%s/%s" % [field.field_id, field.current_floor, it.interaction_id]
		if int(counts.get(key, 0)) < (MAX_INTERACTIONS_PER_ID if _thorough else 2):
			return it.interaction_id
	return ""


func _go(fid: String) -> void:
	if SceneRouter.current_field_id == fid and not SceneRouter.is_transitioning:
		return
	var t0: int = Time.get_ticks_msec()
	if SceneRouter.current_field != null and SceneRouter.player != null:
		var exit: ExitData = SceneRouter.current_field.field_def.find_exit_to(fid) if SceneRouter.current_field.field_def != null else null
		var target: Vector2 = GameConstants.tile_to_world(exit.inward_tile()) if exit != null else Vector2(SceneRouter.current_field.get_bounds_px().size) * 0.5
		_est_walk += _walk_seconds(SceneRouter.player.global_position, target)
	_est_misc += TRANSITION_SEC
	SceneRouter.go_to(fid)
	await _settle()
	var dt: int = Time.get_ticks_msec() - t0
	_stats["transitions"] = int(_stats.get("transitions", 0)) + 1
	_stats["transition_ms_max"] = maxi(int(_stats.get("transition_ms_max", 0)), dt)


func _interact(id: String) -> void:
	var field: FieldBase = SceneRouter.current_field
	var it: Interactable = field.get_interactable(id)
	if it == null:
		return
	if SceneRouter.player != null:
		var dest: Vector2 = it.global_position + Vector2(0, GameConstants.TILE_SIZE)
		_est_walk += _walk_seconds(SceneRouter.player.global_position, dest)
		SceneRouter.player.global_position = dest
		if SceneRouter.heroine != null and SceneRouter.heroine.is_inside_tree():
			# 既定：追従距離（段階ごとのタイル数）だけ後ろ。--witness：1 タイル隣（遷移直後と同じ）
			var follow: PackedInt32Array = SceneRouter.heroine.get_script().get_script_constant_map()["FOLLOW_TILES"]
			var back: int = follow[clampi(Suspicion.get_stage(), 0, follow.size() - 1)] if not _witness else 1
			SceneRouter.heroine.global_position = SceneRouter.player.global_position + Vector2(GameConstants.TILE_SIZE * back, 0)
	it.interact(SceneRouter.player)
	await _settle()


func _walk_seconds(from: Vector2, to: Vector2) -> float:
	var d: float = absf(to.x - from.x) + absf(to.y - from.y)
	return d / 56.0


func _sleep_home(day: int) -> void:
	_est_misc += SLEEP_SEC
	await _go(Calendar.get_home_field_id())
	var field: FieldBase = SceneRouter.current_field
	if field == null or field.get_interactable("home_door") == null:
		_logline("   BLOCKER: 自宅の扉 home_door が無い（field=%s）" % SceneRouter.current_field_id)
		return
	await _interact("home_door")
	var guard: int = 0
	while Calendar.day == day and guard < 600:
		guard += 1
		await get_tree().process_frame
	await _settle()


## イベント・遷移・メッセージが落ち着くまで待つ。開いたメッセージは送り、選択肢は先頭を選ぶ
func _settle() -> void:
	var frames: int = 0
	var idle: int = 0
	while frames < SETTLE_FRAMES_MAX:
		frames += 1
		await get_tree().process_frame
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		if _window != null and bool(_window.get("is_choosing")):
			busy = true
			if not bool(_window.get("is_open")) or not (_window as Control).visible:
				_logline("   BUG: 選択肢がウィンドウ非表示のまま出ている")
			_window.call("_on_choice_activated", 0, "0")
		elif _window != null and bool(_window.get("is_open")):
			busy = true
			if true:
				var ev: InputEventAction = InputEventAction.new()
				ev.action = "interact"
				ev.pressed = true
				_window.call("_unhandled_input", ev)
		if busy:
			idle = 0
		else:
			idle += 1
			if idle >= 3:
				return
	_logline("   WARN: settle がタイムアウト（transitioning=%s running=%s open=%s）" % [SceneRouter.is_transitioning, EventSystem.is_running, bool(_window.get("is_open")) if _window != null else false])


var _known_flags: Dictionary = {}


func _new_flags() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in GameState.flags.keys():
		if not _known_flags.has(f):
			_known_flags[f] = true
			out.append(f)
	return out


func _logline(s: String) -> void:
	_log.append(s)
	print(s)


func _report(t_start: int) -> void:
	print("== 結果 == day=%d 経過=%.1fs（time_scale %.0f）遷移=%d 最大遷移=%dms" % [Calendar.day, (Time.get_ticks_msec() - t_start) / 1000.0, Engine.time_scale, int(_stats.get("transitions", 0)), int(_stats.get("transition_ms_max", 0))])
	print("隠蔽 成功=%s 目撃=%s" % [",".join(GameState.concealed_evidence), ",".join(GameState.witnessed_concealments)])
	print("証拠=%s" % ",".join(GameState.evidence))
	print("接近度=%d 幸運=%d" % [Suspicion.value, AttachedEntity.luck_count])
	print("action_failed %d 件" % _failed_actions.size())
	for f: String in _failed_actions:
		print("  " + f)
	# 未使用フラグ：FLAGS 側の棚卸しは validate_data で行うので、ここでは立ったフラグ数だけ
	print("flags=%d" % GameState.flags.size())
	var keys: Array = _sus.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_sus[a]) > int(_sus[b]))
	for k: String in keys:
		print("  接近度 %-32s %+4d（%d 回）" % [k, int(_sus[k]), int(_sus_n[k])])
	var total: float = _est_walk + _est_read + _est_misc
	print("推定プレイ時間 %.0f 分（歩行 %.0f 分・初読の本文 %.0f 分 %d 頁 %d 字・遷移/選択/就寝 %.0f 分・表示した頁 %d）" % [total / 60.0, _est_walk / 60.0, _est_read / 60.0, _read_pages.size(), _chars_seen, _est_misc / 60.0, _pages_seen])
