class_name JsonFile
extends RefCounted
## JSON ファイル（data/*.json と user:// の保存）の読み書きの共通処理。
## 各 autoload の読み込み関数と SaveManager からだけ呼ぶ（FileAccess を直接開くのはここと開発ツールだけ。docs/CONVENTIONS.md §8）。
## 失敗はクラッシュさせず、errors に理由を積んで空辞書を返す。


## トップレベルが辞書の JSON を読む。require_exists なら「見つからない」も理由に残す
static func read_dict(path: String, errors: PackedStringArray, require_exists: bool = false) -> Dictionary:
	if require_exists and not FileAccess.file_exists(path):
		errors.append("%s が見つかりません" % path)
		return {}
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


## 辞書を整形して書く
static func write_dict(path: String, data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	return OK
