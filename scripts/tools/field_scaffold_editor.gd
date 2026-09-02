@tool
extends EditorScript
## エディタから雛形を生成する（File > Run、または Ctrl+Shift+X）。FIELD_ID を書き換えて実行する。
## CLI 版は scripts/tools/field_scaffold.gd

const FIELD_ID: String = "F03"
const FORCE: bool = false


func _run() -> void:
	var written: PackedStringArray = FieldScaffold.generate(FIELD_ID, FORCE)
	for p: String in written:
		print("書き出し: %s" % p)
	if written.is_empty():
		print("何も書き出しませんでした（既存ファイルかエラー）")
	else:
		EditorInterface.get_resource_filesystem().scan()
