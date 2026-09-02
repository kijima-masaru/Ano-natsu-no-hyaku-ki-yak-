extends SceneTree
## フィールド雛形の生成（ヘッドレス）。プロジェクトルートで：
##   godot --headless --path . -s scripts/tools/field_scaffold.gd -- F03 [--force]
## エディタから実行するなら scripts/tools/field_scaffold_editor.gd（File > Run）。

const USAGE: String = "使い方: godot --headless --path . -s scripts/tools/field_scaffold.gd -- F03 [--force]"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var field_id: String = ""
	var force: bool = false
	for a: String in args:
		if a == "--force":
			force = true
		elif a.begins_with("F"):
			field_id = a
	if field_id.is_empty():
		push_error(USAGE)
		quit(2)
		return
	var written: PackedStringArray = FieldScaffold.generate(field_id, force)
	if written.is_empty():
		print("何も書き出しませんでした（既存ファイルかエラー）")
		quit(1)
		return
	for p: String in written:
		print("書き出し: %s" % p)
	print("次の手順は docs/FIELD_IMPLEMENTATION_GUIDE.md を参照")
	quit(0)
