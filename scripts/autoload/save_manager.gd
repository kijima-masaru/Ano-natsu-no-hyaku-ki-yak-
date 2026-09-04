extends Node
## セーブ／ロードと、スロットとは別のシステム保存（user://system.json）を担う autoload。
## 各 autoload は register_section() で「名前・to_dict・from_dict」を登録し、SaveManager がまとめて永続化する。
## 破損データはクラッシュさせず、明示的なエラーの上で失敗を返す（呼び出し側は新規開始にフォールバック）。

signal saved(slot: int)
signal loaded(slot: int)
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)
signal setting_changed(key: String, value: Variant)

const SYSTEM_SCHEMA_VERSION: int = 1
## 設定の既定値。設定画面と各 autoload はここのキー名を使う
const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 1.0, "bgm_volume": 0.8, "se_volume": 0.8, "ambience_volume": 0.8,
	"text_speed": 0.7, "instant_text": false, "brightness": 0.5, "screen_fx": true, "debug_overlay": false,
}

## システム保存（周回・既読・設定）。スロットとは独立
var system: Dictionary = {}

var _sections: Dictionary = {}
var _section_order: PackedStringArray = PackedStringArray()


func _ready() -> void:
	load_system()
	register_section("game_state", GameState.to_dict, GameState.from_dict)
	register_section("calendar", Calendar.to_dict, Calendar.from_dict)
	Calendar.day_advanced.connect(_on_day_advanced)


## セクションを登録する。復元は登録順に行う（game_state → calendar → …）
func register_section(section: String, to_dict: Callable, from_dict: Callable) -> void:
	if _sections.has(section):
		push_error("SaveManager: セクション '%s' は既に登録されています" % section)
		return
	_sections[section] = {"to": to_dict, "from": from_dict}
	_section_order.append(section)


# ── スロット ──

func has_save(slot: int) -> bool:
	return SavePaths.is_valid_slot(slot) and FileAccess.file_exists(SavePaths.slot_path(slot))


## スロットの見出し情報（無ければ空辞書）。タイトルの「つづきから」で使う
func peek(slot: int) -> Dictionary:
	var data: Dictionary = _read_json(SavePaths.slot_path(slot), PackedStringArray())
	if data.is_empty():
		return {}
	var sections: Dictionary = data.get("sections", {})
	var cal: Dictionary = sections.get("calendar", {})
	var gs: Dictionary = sections.get("game_state", {})
	return {
		"saved_at": str(data.get("saved_at", "")),
		"day": int(cal.get("day", 1)),
		"time_of_day": str(cal.get("time_of_day", "morning")),
		"field_id": str(gs.get("current_field_id", "")),
		"play_time_sec": float(gs.get("play_time_sec", 0.0)),
	}


func save_game(slot: int) -> Error:
	if not SavePaths.is_valid_slot(slot):
		return _fail_save(slot, "スロット %d は不正です（0〜%d）" % [slot, SavePaths.SLOT_COUNT - 1])
	if SavePaths.ensure_dir() != OK:
		return _fail_save(slot, "保存先ディレクトリを作成できません")
	var sections: Dictionary = {}
	for name: String in _section_order:
		var to_cb: Callable = _sections[name]["to"]
		sections[name] = to_cb.call()
	var root: Dictionary = {
		"schema_version": SaveMigrator.CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"sections": sections,
	}
	var err: Error = _write_json(SavePaths.slot_path(slot), root)
	if err != OK:
		return _fail_save(slot, "書き込みに失敗（%s）" % error_string(err))
	SteamBridge.cloud_save(slot, JSON.stringify(root).to_utf8_buffer())
	saved.emit(slot)
	return OK


func load_game(slot: int) -> Error:
	if not has_save(slot):
		return _fail_load(slot, "セーブデータがありません")
	var errors: PackedStringArray = PackedStringArray()
	var raw: Dictionary = _read_json(SavePaths.slot_path(slot), errors)
	if raw.is_empty():
		return _fail_load(slot, "破損しています：%s" % ", ".join(errors))
	var data: Dictionary = SaveMigrator.migrate(raw, errors)
	if data.is_empty():
		return _fail_load(slot, "移行できません：%s" % ", ".join(errors))
	var sections: Variant = data.get("sections", null)
	if not sections is Dictionary:
		return _fail_load(slot, "sections がありません")
	for name: String in _section_order:
		if not (sections as Dictionary).has(name):
			push_warning("SaveManager: セクション '%s' が無いため既定値のままにします" % name)
			continue
		var from_cb: Callable = _sections[name]["from"]
		var ok: bool = from_cb.call((sections as Dictionary)[name])
		if not ok:
			return _fail_load(slot, "セクション '%s' の復元に失敗" % name)
	loaded.emit(slot)
	return OK


func delete_save(slot: int) -> Error:
	if not has_save(slot):
		return ERR_DOES_NOT_EXIST
	return DirAccess.remove_absolute(SavePaths.slot_path(slot))


func autosave() -> void:
	if save_game(SavePaths.AUTOSAVE_SLOT) != OK:
		push_warning("SaveManager: オートセーブに失敗しました")


func _on_day_advanced(_day: int, _previous: int) -> void:
	autosave()


# ── システム保存 ──

func load_system() -> void:
	system = {"schema_version": SYSTEM_SCHEMA_VERSION, "content_notice_seen": false, "cleared_endings": [],
		"clear_count": 0, "first_clear_at": "", "last_ending": "", "clears_by_ending": {},
		"settings": DEFAULT_SETTINGS.duplicate()}
	if not FileAccess.file_exists(SavePaths.SYSTEM_FILE):
		return
	var errors: PackedStringArray = PackedStringArray()
	var data: Dictionary = _read_json(SavePaths.SYSTEM_FILE, errors)
	if data.is_empty():
		push_error("SaveManager: system.json が読めません（%s）。既定値で続行します" % ", ".join(errors))
		return
	for key: String in ["content_notice_seen", "cleared_endings", "clear_count", "first_clear_at", "last_ending", "clears_by_ending"]:
		if data.has(key):
			system[key] = data[key]
	var saved_settings: Variant = data.get("settings", {})
	if saved_settings is Dictionary:
		for key: String in DEFAULT_SETTINGS.keys():
			if (saved_settings as Dictionary).has(key):
				system["settings"][key] = (saved_settings as Dictionary)[key]


func save_system() -> Error:
	var err: Error = _write_json(SavePaths.SYSTEM_FILE, system)
	if err != OK:
		push_error("SaveManager: system.json の保存に失敗（%s）" % error_string(err))
	return err


func get_setting(key: String) -> Variant:
	if not DEFAULT_SETTINGS.has(key):
		push_error("SaveManager: 設定キー '%s' は未定義です" % key)
		return null
	return system["settings"].get(key, DEFAULT_SETTINGS[key])


func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_error("SaveManager: 設定キー '%s' は未定義です" % key)
		return
	system["settings"][key] = value
	setting_changed.emit(key, value)
	save_system()


func mark_content_notice_seen() -> void:
	system["content_notice_seen"] = true
	save_system()


## クリア記録：到達エンディングの一覧、クリア回数、初回クリア日時（ISO 8601、ローカル時刻）、最後の ED、ED ごとの回数
func record_cleared_ending(ending_id: String) -> void:
	var list: Array = system["cleared_endings"]
	if not list.has(ending_id):
		list.append(ending_id)
	system["clear_count"] = int(system.get("clear_count", 0)) + 1
	if str(system.get("first_clear_at", "")).is_empty():
		system["first_clear_at"] = Time.get_datetime_string_from_system(false, true)
	system["last_ending"] = ending_id
	var by: Dictionary = system.get("clears_by_ending", {})
	by[ending_id] = int(by.get(ending_id, 0)) + 1
	system["clears_by_ending"] = by
	save_system()


## 一度でもクリアしたか（周回要素の解放）
func has_cleared() -> bool:
	return not (system.get("cleared_endings", []) as Array).is_empty()


# ── I/O ──

func _read_json(path: String, errors: PackedStringArray) -> Dictionary:
	return JsonFile.read_dict(path, errors)


func _write_json(path: String, data: Dictionary) -> Error:
	return JsonFile.write_dict(path, data)


func _fail_save(slot: int, reason: String) -> Error:
	push_error("SaveManager: save_game(%d) %s" % [slot, reason])
	save_failed.emit(slot, reason)
	return ERR_CANT_CREATE


func _fail_load(slot: int, reason: String) -> Error:
	push_error("SaveManager: load_game(%d) %s" % [slot, reason])
	load_failed.emit(slot, reason)
	return ERR_FILE_CORRUPT
