extends Node
## data/messages.json を読み込み、ID からテキストを解決する autoload。
## **二層テキストの分岐はここ（resolve）だけで行う。** 他の場所で truth_revealed を見てテキストを選んではならない。
## 表層版を表示した時点で seen_<id> フラグを立て、真相到達時の「あなたが読んだ嘘」一覧に使う。

signal load_failed(errors: PackedStringArray)

const MESSAGES_PATH: String = "res://data/messages.json"
const TRUTH_FLAG: String = "truth_revealed"
const MISSING_FORMAT: String = "［%s］"
## 話者定義の color 文字列 → パレットインデックス
const COLOR_NAMES: Dictionary = {
	"SUMI": Palette.SUMI, "NIGHT_SKY": Palette.NIGHT_SKY, "DEEP_INDIGO": Palette.DEEP_INDIGO,
	"DUSK_INDIGO": Palette.DUSK_INDIGO, "FOG_INDIGO": Palette.FOG_INDIGO, "CONCRETE": Palette.CONCRETE,
	"MOSS_DARK": Palette.MOSS_DARK, "FADED_GREEN": Palette.FADED_GREEN, "FADED_GREEN_LIGHT": Palette.FADED_GREEN_LIGHT,
	"RUST_DARK": Palette.RUST_DARK, "RUST": Palette.RUST, "OCHRE": Palette.OCHRE, "BONE_WHITE": Palette.BONE_WHITE,
	"STREETLAMP_GLOW": Palette.STREETLAMP_GLOW, "VENDING_RED": Palette.VENDING_RED, "FLUORESCENT": Palette.FLUORESCENT,
	"UI_TEXT": Palette.UI_TEXT, "UI_TEXT_DIM": Palette.UI_TEXT_DIM, "UI_ACCENT": Palette.UI_ACCENT,
}

var is_loaded: bool = false
var load_errors: PackedStringArray = PackedStringArray()

var _messages: Dictionary = {}
var _speakers: Dictionary = {}


func _ready() -> void:
	load_file(MESSAGES_PATH)


func load_file(path: String) -> bool:
	_messages.clear()
	_speakers.clear()
	load_errors.clear()
	is_loaded = false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("%s を開けません（%s）" % [path, error_string(FileAccess.get_open_error())])
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _fail("%s: JSON 構文エラー 行 %d: %s" % [path, json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary:
		return _fail("%s: トップレベルは辞書である必要があります" % path)
	var root: Dictionary = json.data
	var meta: Dictionary = root.get("meta", {}) if root.get("meta", {}) is Dictionary else {}
	if meta.get("speakers", {}) is Dictionary:
		_speakers = meta.get("speakers", {})
	var list: Variant = root.get("messages", null)
	if not list is Array:
		return _fail("%s: 'messages' 配列がありません" % path)
	for item: Variant in list as Array:
		if not item is Dictionary:
			load_errors.append("messages の要素が辞書ではありません")
			continue
		var d: Dictionary = item
		var id: String = str(d.get("id", ""))
		if id.is_empty():
			load_errors.append("id の無いメッセージがあります")
			continue
		if _messages.has(id):
			load_errors.append("メッセージ ID '%s' が重複しています" % id)
		_messages[id] = d
	_validate()
	for msg: String in load_errors:
		push_error("MessageResolver: " + msg)
	is_loaded = not _messages.is_empty()
	return is_loaded


## truth_id の参照先と話者の存在を検証する
func _validate() -> void:
	for id: String in _messages.keys():
		var d: Dictionary = _messages[id]
		var truth: String = str(d.get("truth_id", ""))
		if not truth.is_empty() and not _messages.has(truth):
			load_errors.append("'%s' の truth_id '%s' が存在しません（二層テキストの片側欠落）" % [id, truth])
		var speaker: String = str(d.get("speaker", ""))
		if not _speakers.has(speaker):
			load_errors.append("'%s' の話者 '%s' は meta.speakers に定義されていません" % [id, speaker])


func _fail(msg: String) -> bool:
	load_errors.append(msg)
	push_error("MessageResolver: " + msg)
	load_failed.emit(load_errors)
	return false


func has_message(id: String) -> bool:
	return _messages.has(id)


func get_message_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: String in _messages.keys():
		out.append(key)
	return out


## **唯一の解決関数。** truth_revealed が立ち、かつ truth_id があれば真相版を返す。
## 表層版を返すときは seen_<id> を立てる。args は %s の置換に使う。
func resolve(id: String, args: Array = []) -> MessageEntry:
	var entry: MessageEntry = MessageEntry.new()
	if not _messages.has(id):
		push_error("MessageResolver: メッセージ ID '%s' が存在しません" % id)
		entry.id = id
		entry.text = MISSING_FORMAT % id
		return entry
	var d: Dictionary = _messages[id]
	var truth_id: String = str(d.get("truth_id", ""))
	if not truth_id.is_empty() and GameState.has_flag(TRUTH_FLAG) and _messages.has(truth_id):
		var truth: MessageEntry = _build(truth_id, _messages[truth_id], args)
		truth.is_truth = true
		truth.truth_id = truth_id
		# 話者に truth_color があれば真相版はその色（ナツ：文言が同じでも色だけ変わる。docs/DECEPTION_MAP.md §D）
		var truth_color: String = str(get_speaker(truth.speaker).get("truth_color", ""))
		if COLOR_NAMES.has(truth_color):
			truth.color_index = COLOR_NAMES[truth_color]
		return truth
	if not truth_id.is_empty():
		GameState.raise_flag("seen_%s" % id)
	return _build(id, d, args)


## テキストだけ欲しいときの短縮形
func text(id: String, args: Array = []) -> String:
	return resolve(id, args).text


func get_speaker(speaker: String) -> Dictionary:
	return _speakers.get(speaker, _speakers.get("", {}))


func _build(id: String, d: Dictionary, args: Array) -> MessageEntry:
	var entry: MessageEntry = MessageEntry.new()
	entry.id = id
	entry.speaker = str(d.get("speaker", ""))
	entry.truth_id = str(d.get("truth_id", ""))
	var raw: String = str(d.get("text", ""))
	entry.text = raw % args if not args.is_empty() else raw
	var sp: Dictionary = get_speaker(entry.speaker)
	entry.speaker_name = str(sp.get("name", ""))
	entry.speed = float(sp.get("speed", 1.0))
	var color_name: String = str(sp.get("color", "UI_TEXT"))
	if COLOR_NAMES.has(color_name):
		entry.color_index = COLOR_NAMES[color_name]
	else:
		push_error("MessageResolver: 話者 '%s' の色 '%s' は未定義です" % [entry.speaker, color_name])
	return entry
