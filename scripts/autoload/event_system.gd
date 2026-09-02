extends Node
## フラグ駆動のイベントシステム。data/events.json を読み、トリガーに応じてアクション列を順に実行する。
## ゲーム内容は JSON に寄せ、ここにはアクションの実行機構だけを書く。
## メッセージ表示は register_message_window() で渡されたノード（show_message / closed）に委ね、閉じるまで待つ。
## アクション種別は register_action() で他の autoload が追加できる（play_sound / raise_suspicion / entity_speak …）。

signal event_started(event_id: String)
signal event_finished(event_id: String)
signal action_failed(event_id: String, action: Dictionary, reason: String)
signal load_failed(errors: PackedStringArray)

const EVENTS_PATH: String = "res://data/events.json"
const ITEMS_PATH: String = "res://data/items.json"
const TRIGGER_ENTER: String = "on_enter"
const TRIGGER_INTERACT: String = "on_interact"
const TRIGGER_DAY_START: String = "on_day_start"
const TRIGGER_MANUAL: String = "manual"

var is_loaded: bool = false
var is_running: bool = false
var load_errors: PackedStringArray = PackedStringArray()
var validation_errors: PackedStringArray = PackedStringArray()

var _events: Dictionary = {}
var _by_trigger: Dictionary = {}
var _handlers: Dictionary = {}
var _item_ids: PackedStringArray = PackedStringArray()
var _message_window: Node = null
var _queue: Array[String] = []


func _ready() -> void:
	_register_builtin_actions()
	_load_items(ITEMS_PATH)
	load_events(EVENTS_PATH)
	# 他の autoload が register_action を終えた後（同フレーム末）に参照を検証する
	validate.call_deferred()


# ── 登録 ──

## アクション種別を登録する。handler(action: Dictionary, ctx: Dictionary) -> void（コルーチン可）
func register_action(type: String, handler: Callable) -> void:
	if _handlers.has(type):
		push_error("EventSystem: アクション '%s' は既に登録されています" % type)
		return
	_handlers[type] = handler


func known_actions() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: String in _handlers.keys():
		out.append(k)
	return out


## メッセージ表示ノード（show_message(title, text) と signal closed を持つ）
func register_message_window(window: Node) -> void:
	_message_window = window


func get_item_ids() -> PackedStringArray:
	return _item_ids.duplicate()


# ── 読み込み ──

func load_events(path: String) -> bool:
	_events.clear()
	_by_trigger.clear()
	load_errors.clear()
	is_loaded = false
	var root: Dictionary = _read_json(path, load_errors)
	if root.is_empty():
		_report_load()
		return false
	var list: Variant = root.get("events", null)
	if not list is Array:
		load_errors.append("%s: 'events' 配列がありません" % path)
		_report_load()
		return false
	for item: Variant in list as Array:
		if not item is Dictionary:
			load_errors.append("events の要素が辞書ではありません")
			continue
		var e: EventData = EventData.from_dict(item, load_errors)
		if e.id.is_empty():
			continue
		if _events.has(e.id):
			load_errors.append("イベント ID '%s' が重複しています" % e.id)
			continue
		_events[e.id] = e
		if not _by_trigger.has(e.trigger):
			_by_trigger[e.trigger] = []
		(_by_trigger[e.trigger] as Array).append(e)
	_report_load()
	is_loaded = not _events.is_empty()
	return is_loaded


func _load_items(path: String) -> void:
	var root: Dictionary = _read_json(path, load_errors)
	var list: Variant = root.get("items", [])
	if list is Array:
		for item: Variant in list as Array:
			if item is Dictionary:
				_item_ids.append(str((item as Dictionary).get("id", "")))


## 起動時の全件検証。問題は validation_errors に残し push_error する
func validate() -> void:
	validation_errors = EventValidator.validate(_events, known_actions(), _item_ids)
	for msg: String in validation_errors:
		push_error("EventSystem: " + msg)
	if validation_errors.is_empty():
		print("EventSystem: %d イベントの参照検証を通過" % _events.size())


func _report_load() -> void:
	for msg: String in load_errors:
		push_error("EventSystem: " + msg)
	if _events.is_empty() and not load_errors.is_empty():
		load_failed.emit(load_errors)


func has_event(id: String) -> bool:
	return _events.has(id)


func get_event(id: String) -> EventData:
	return _events.get(id, null)


# ── 発火 ──

## トリガーに一致するイベントを探して実行する。実行したものがあれば true。
## on_interact は優先度最大の 1 件のみ、それ以外は一致した全件を順に実行する
func fire(trigger: String, field_id: String, target: String = "") -> bool:
	var candidates: Array[EventData] = []
	for e: EventData in _by_trigger.get(trigger, []):
		if not e.field.is_empty() and e.field != field_id:
			continue
		if trigger == TRIGGER_INTERACT and e.target != target:
			continue
		if not e.matches_day(Calendar.day) or not e.matches_time(Calendar.time_of_day):
			continue
		if e.once and GameState.has_flag(e.done_flag()):
			continue
		if not ConditionEvaluator.evaluate_all(e.conditions):
			continue
		candidates.append(e)
	if candidates.is_empty():
		return false
	candidates.sort_custom(func(a: EventData, b: EventData) -> bool: return a.priority > b.priority)
	if trigger == TRIGGER_INTERACT:
		run_event(candidates[0].id)
	else:
		for e: EventData in candidates:
			run_event(e.id)
	return true


## ID で実行する。実行中なら待ち行列に入れる
func run_event(id: String) -> void:
	if not _events.has(id):
		push_error("EventSystem: イベント '%s' が存在しません" % id)
		return
	_queue.append(id)
	if not is_running:
		_drain()


func _drain() -> void:
	is_running = true
	_set_player_input(false)
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		var e: EventData = _events[id]
		event_started.emit(id)
		for action: Dictionary in e.actions:
			await _run_action(e, action)
		if e.once:
			GameState.raise_flag(e.done_flag())
		event_finished.emit(id)
	is_running = false
	_set_player_input(true)


func _run_action(e: EventData, action: Dictionary) -> void:
	var type: String = str(action.get("type", ""))
	if not _handlers.has(type):
		push_error("EventSystem: %s のアクション '%s' は未登録です" % [e.id, type])
		action_failed.emit(e.id, action, "unknown action")
		return
	var handler: Callable = _handlers[type]
	await handler.call(action, {"event_id": e.id, "field_id": SceneRouter.current_field_id})


func _set_player_input(enabled: bool) -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = enabled


# ── 組み込みアクション ──

func _register_builtin_actions() -> void:
	register_action("message", _act_message)
	register_action("set_flag", func(a: Dictionary, _c: Dictionary) -> void:
		if bool(a.get("value", true)):
			GameState.raise_flag(str(a.get("flag", "")))
		else:
			GameState.clear_flag(str(a.get("flag", ""))))
	register_action("clear_flag", func(a: Dictionary, _c: Dictionary) -> void: GameState.clear_flag(str(a.get("flag", ""))))
	register_action("give_item", func(a: Dictionary, _c: Dictionary) -> void: GameState.add_item(str(a.get("item", ""))))
	register_action("remove_item", func(a: Dictionary, _c: Dictionary) -> void: GameState.remove_item(str(a.get("item", ""))))
	register_action("unlock_field", _act_unlock_field)
	register_action("move_player", _act_move_player)
	register_action("advance_day", func(_a: Dictionary, _c: Dictionary) -> void: Calendar.advance_day())
	register_action("set_time", func(a: Dictionary, _c: Dictionary) -> void: Calendar.set_time_of_day(str(a.get("time_of_day", ""))))
	register_action("add_points", func(a: Dictionary, _c: Dictionary) -> void: Calendar.add_investigation_points(int(a.get("amount", 1))))
	register_action("wait", _act_wait)
	register_action("run_event", func(a: Dictionary, _c: Dictionary) -> void: run_event(str(a.get("id", ""))))
	register_action("end_game", _act_end_game)
	register_action("choice", _act_choice)


## message: {id, truth_id?, args?}。二層分岐は MessageResolver.resolve に任せる
func _act_message(a: Dictionary, _c: Dictionary) -> void:
	var id: String = str(a.get("id", ""))
	var args: Array = a.get("args", []) if a.get("args", []) is Array else []
	var entry: MessageEntry = MessageResolver.resolve(id, args)
	await show_entry(entry)


## 解決済みメッセージをウィンドウに出し、閉じるまで待つ（他の autoload からも使う）
func show_entry(entry: MessageEntry) -> void:
	if _message_window == null:
		push_error("EventSystem: メッセージウィンドウが未登録です（'%s'）" % entry.id)
		return
	if _message_window.has_method("show_entry"):
		_message_window.call("show_entry", entry)
	else:
		_message_window.call("show_message", entry.speaker_name, entry.text)
	await Signal(_message_window, "closed")


## choice: {options: [{text_id, set_flag?, run_event?}], prompt_id?}。選んだ選択肢の set_flag / run_event を適用
func _act_choice(a: Dictionary, c: Dictionary) -> void:
	if _message_window == null or not _message_window.has_method("show_choice"):
		push_error("EventSystem: 選択肢を表示できるウィンドウが未登録です")
		return
	var options: Variant = a.get("options", [])
	if not options is Array or (options as Array).is_empty():
		action_failed.emit(str(c["event_id"]), a, "options が空")
		return
	var labels: PackedStringArray = PackedStringArray()
	for opt: Variant in options as Array:
		labels.append(MessageResolver.text(str((opt as Dictionary).get("text_id", ""))))
	if a.has("prompt_id"):
		_message_window.call("show_entry", MessageResolver.resolve(str(a["prompt_id"])))
	_message_window.call("show_choice", labels)
	var index: int = await Signal(_message_window, "choice_made")
	if index < 0 or index >= (options as Array).size():
		return
	var chosen: Dictionary = (options as Array)[index]
	if chosen.has("set_flag"):
		GameState.raise_flag(str(chosen["set_flag"]))
	if chosen.has("run_event"):
		run_event(str(chosen["run_event"]))


func _act_unlock_field(a: Dictionary, c: Dictionary) -> void:
	var def: FieldData = FieldRegistry.get_field(str(a.get("field", "")))
	if def == null:
		action_failed.emit(str(c["event_id"]), a, "unknown field")
		return
	if def.unlock_flag.is_empty():
		push_warning("EventSystem: %s に unlock_flag が無いため unlock_field は何もしません" % def.id)
		return
	GameState.raise_flag(def.unlock_flag)


func _act_move_player(a: Dictionary, _c: Dictionary) -> void:
	var field: String = str(a.get("field", ""))
	if not field.is_empty() and field != SceneRouter.current_field_id:
		SceneRouter.go_to(field)
		await SceneRouter.transition_finished
	var tile: Variant = a.get("tile", null)
	if tile is Array and (tile as Array).size() == 2 and SceneRouter.player != null:
		var facing: Vector2i = Vector2i.ZERO
		var f: Variant = a.get("facing", null)
		if f is Array and (f as Array).size() == 2:
			facing = Vector2i(int((f as Array)[0]), int((f as Array)[1]))
		SceneRouter.player.place_at_tile(Vector2i(int((tile as Array)[0]), int((tile as Array)[1])), facing)


func _act_wait(a: Dictionary, _c: Dictionary) -> void:
	await get_tree().create_timer(maxf(0.0, float(a.get("seconds", 0.5)))).timeout


## end_game: {ending}。クリア記録を残しタイトルへ（本実装はステップ5）
func _act_end_game(a: Dictionary, _c: Dictionary) -> void:
	var ending: String = str(a.get("ending", ""))
	if not ending.is_empty():
		SaveManager.record_cleared_ending(ending)
		GameState.raise_flag("ending_reached")
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")


func _read_json(path: String, errors: PackedStringArray) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s を開けません（%s）" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		errors.append("%s: JSON 構文エラー 行 %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		errors.append("%s: トップレベルは辞書である必要があります" % path)
		return {}
	return json.data
