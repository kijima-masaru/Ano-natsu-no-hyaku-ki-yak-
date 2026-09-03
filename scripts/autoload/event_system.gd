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
## 他のデータ（怪異など）が立てるフラグ。register_defined_flags() で受け取り、参照検証で既知として扱う
var _extra_defined_flags: Dictionary = {}
## 待ち行列。要素はイベント ID（String）か、任意のアクション列 {label, actions}（Dictionary。AnomalySystem 等が使う）
var _queue: Array = []


func _ready() -> void:
	_register_builtin_actions()
	_load_items(ITEMS_PATH)
	load_events(EVENTS_PATH)
	# 他の autoload が register_action を終えた後（同フレーム末）に参照を検証する
	validate.call_deferred()


## 終了時に static の条件登録と自前のアクション登録を空にする。
## ラムダを static 変数や autoload の辞書に残したまま終了すると、エンジン終了時にヒープ破壊で落ちる（Godot 4.7 で実機確認）
func _exit_tree() -> void:
	ConditionEvaluator.clear_registered()
	_handlers.clear()


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


## メッセージウィンドウの親（UI の CanvasLayer）。全画面の提示画面などをウィンドウの下に差し込むために使う。
## ウィンドウが未登録なら null
func get_ui_root() -> Node:
	return _message_window.get_parent() if _message_window != null else null


## メッセージウィンドウを UI 層の最前面へ（全画面の提示画面の上に会話を出すため）
func raise_message_window() -> void:
	if _message_window != null and _message_window.get_parent() != null:
		_message_window.get_parent().move_child(_message_window, _message_window.get_parent().get_child_count() - 1)


func get_item_ids() -> PackedStringArray:
	return _item_ids.duplicate()


# ── 読み込み ──

func load_events(path: String) -> bool:
	is_loaded = false
	var result: Dictionary = EventLoader.load_file(path)
	_events = result[EventLoader.KEY_EVENTS]
	_by_trigger = result[EventLoader.KEY_BY_TRIGGER]
	load_errors = result[EventLoader.KEY_ERRORS]
	_report_load()
	is_loaded = not _events.is_empty()
	return is_loaded


func _load_items(path: String) -> void:
	_item_ids = EventLoader.load_item_ids(path, load_errors)


## 他のシステムが立てるフラグを登録する（AnomalySystem が _ready で呼ぶ。validate は遅延実行なので間に合う）
func register_defined_flags(flags: PackedStringArray) -> void:
	for f: String in flags:
		_extra_defined_flags[f] = true


## events.json が立てるフラグ（AnomalySystem の検証が参照する）
func defined_flags() -> Dictionary:
	return EventValidator.defined_flags_of(_events)


## 起動時の全件検証。問題は validation_errors に残し push_error する
func validate() -> void:
	validation_errors = EventValidator.validate(_events, known_actions(), _item_ids, _extra_defined_flags)
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
		if e.daily and GameState.has_flag(e.daily_flag(Calendar.day)):
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


## events.json に無い任意のアクション列を、イベントと同じ語彙・同じ待ち行列で実行する（怪異など）。
## label は event_started / event_finished とエラー表示に使う
func run_actions(label: String, actions: Array[Dictionary]) -> void:
	if actions.is_empty():
		return
	_queue.append({"label": label, "actions": actions})
	if not is_running:
		_drain()


func _drain() -> void:
	is_running = true
	_set_player_input(false)
	while not _queue.is_empty():
		var entry: Variant = _queue.pop_front()
		if entry is String:
			var e: EventData = _events[entry]
			event_started.emit(e.id)
			for action: Dictionary in e.actions:
				await _run_action(e.id, action)
			if e.once:
				GameState.raise_flag(e.done_flag())
			if e.daily:
				GameState.raise_flag(e.daily_flag(Calendar.day))
			event_finished.emit(e.id)
		else:
			var label: String = str((entry as Dictionary).get("label", ""))
			event_started.emit(label)
			for action: Dictionary in (entry as Dictionary).get("actions", []):
				await _run_action(label, action)
			event_finished.emit(label)
	is_running = false
	_set_player_input(true)


## アクション列を待ち行列に入れず、その場で順に実行する（branch アクションの then / else 用）
func run_actions_inline(label: String, actions: Array) -> void:
	for action: Variant in actions:
		if action is Dictionary:
			await _run_action(label, action)


func _run_action(label: String, action: Dictionary) -> void:
	var type: String = str(action.get("type", ""))
	if not _handlers.has(type):
		push_error("EventSystem: %s のアクション '%s' は未登録です" % [label, type])
		action_failed.emit(label, action, "unknown action")
		return
	var handler: Callable = _handlers[type]
	await handler.call(action, {"event_id": label, "field_id": SceneRouter.current_field_id})


func _set_player_input(enabled: bool) -> void:
	if SceneRouter.player != null:
		SceneRouter.player.input_enabled = enabled


# ── 組み込みアクション（EventActions に定義） ──

func _register_builtin_actions() -> void:
	EventActions.register_all(self)


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


## 選択肢の前置き本文（閉じるのを待たず、ウィンドウに保留中の選択肢を渡す）
func show_prompt(entry: MessageEntry) -> void:
	if _message_window != null and _message_window.has_method("show_entry"):
		_message_window.call("show_entry", entry)


## 選択肢を出して結果の index を返す（-1 は表示不可）
func show_choice(labels: PackedStringArray) -> int:
	if _message_window == null or not _message_window.has_method("show_choice"):
		push_error("EventSystem: 選択肢を表示できるウィンドウが未登録です")
		return -1
	_message_window.call("show_choice", labels)
	var index: int = await Signal(_message_window, "choice_made")
	return index


func emit_action_failed(event_id: String, action: Dictionary, reason: String) -> void:
	action_failed.emit(event_id, action, reason)
