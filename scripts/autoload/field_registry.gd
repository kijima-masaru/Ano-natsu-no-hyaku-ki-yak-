extends Node
## data/fields.json を起動時に読み込み、FieldData として提供する autoload。
##
## 失敗時の挙動（握り潰さない）：
## - ファイル欠落・JSON 構文エラー・トップレベル構造の不備 → is_loaded=false、レジストリは空、
##   push_error の上で load_failed を発火。呼び出し側（SceneRouter）はエラーシーンにフォールバックする。
## - 意味的な不整合（必須キー欠落、不正な ID 参照、双方向でない接続 等）→ データは保持し is_loaded=true、
##   全件を push_error し、validation_errors に残す。

signal loaded(field_count: int)
signal load_failed(errors: PackedStringArray)

const FIELDS_JSON_PATH: String = "res://data/fields.json"

var is_loaded: bool = false
## 意味的な検証エラー（読み込み成功時も残る）
var validation_errors: PackedStringArray = PackedStringArray()
## 読み込み失敗の理由（構文・構造）
var load_errors: PackedStringArray = PackedStringArray()

var _fields: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _locks: Dictionary = {}
var _meta: Dictionary = {}


func _ready() -> void:
	load_from_file(FIELDS_JSON_PATH)


## JSON を読み込んでレジストリを構築する。成功で true
func load_from_file(path: String) -> bool:
	_reset()
	var root: Dictionary = _read_root(path)
	if root.is_empty():
		_fail()
		return false
	_meta = root.get("meta", {}) if root.get("meta", {}) is Dictionary else {}
	_locks = _meta.get("locks", {}) if _meta.get("locks", {}) is Dictionary else {}
	var fields_value: Variant = root.get("fields", null)
	if not fields_value is Array:
		load_errors.append("%s: トップレベルに 'fields' 配列がありません" % path)
		_fail()
		return false
	for item: Variant in fields_value as Array:
		if not item is Dictionary:
			validation_errors.append("fields の要素が辞書ではありません: %s" % str(item))
			continue
		var f: FieldData = FieldData.from_dict(item, validation_errors)
		if f.id.is_empty():
			continue
		if _fields.has(f.id):
			validation_errors.append("%s: id が重複しています" % f.id)
			continue
		_fields[f.id] = f
		_order.append(f.id)
	if _fields.is_empty():
		load_errors.append("%s: フィールドが 1 件も読み込めませんでした" % path)
		_fail()
		return false
	validation_errors.append_array(FieldSchemaValidator.validate(_fields, _locks, _palette_hex()))
	for msg: String in validation_errors:
		push_error("FieldRegistry: " + msg)
	is_loaded = true
	loaded.emit(_fields.size())
	return true


## ファイルを開いて JSON を解析し、トップレベル辞書を返す。失敗は空辞書＋load_errors
func _read_root(path: String) -> Dictionary:
	return JsonFile.read_dict(path, load_errors, true)


func _palette_hex() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var palette: Variant = _meta.get("palette", [])
	if palette is Array:
		for entry: Variant in palette as Array:
			if entry is Dictionary:
				out.append(str((entry as Dictionary).get("hex", "")))
	return out


func _reset() -> void:
	is_loaded = false
	validation_errors.clear()
	load_errors.clear()
	_fields.clear()
	_order.clear()
	_locks.clear()
	_meta.clear()


func _fail() -> void:
	for msg: String in load_errors:
		push_error("FieldRegistry: " + msg)
	load_failed.emit(load_errors)


# ── 公開 API ──

func has_field(id: String) -> bool:
	return _fields.has(id)


## フィールド定義。存在しなければ push_error の上で null
func get_field(id: String) -> FieldData:
	if not _fields.has(id):
		push_error("FieldRegistry: フィールド '%s' は存在しません" % id)
		return null
	return _fields[id]


## JSON の記載順で全フィールド
func get_all_fields() -> Array[FieldData]:
	var out: Array[FieldData] = []
	for id: String in _order:
		out.append(_fields[id])
	return out


func get_field_ids() -> PackedStringArray:
	return _order.duplicate()


## 出口一覧。存在しないフィールドは空配列
func get_exits(id: String) -> Array[ExitData]:
	var f: FieldData = get_field(id)
	if f == null:
		return []
	return f.exits


## 進入可能か。unlock_flag が無ければ常に true、あれば GameState のフラグで判定
func is_unlocked(id: String) -> bool:
	var f: FieldData = get_field(id)
	if f == null:
		return false
	if f.unlock_flag.is_empty():
		return true
	return GameState.has_flag(f.unlock_flag)


## 出口を通れるか。lock が無ければ true、あれば GameState のフラグで判定
func is_exit_open(exit: ExitData) -> bool:
	if exit == null:
		return false
	if not exit.is_locked():
		return true
	return GameState.has_flag(exit.lock)


## 鍵・フラグの説明文（meta.locks）。未定義なら空文字
func get_lock_description(lock: String) -> String:
	return str(_locks.get(lock, ""))


func get_lock_names() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: String in _locks.keys():
		out.append(key)
	return out
