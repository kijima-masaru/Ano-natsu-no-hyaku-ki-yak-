class_name DataReport
extends RefCounted
## validate_data の結果の入れ物。error は終了コードを非 0 にし、warn は表示のみ。

var errors: PackedStringArray = PackedStringArray()
var warnings: PackedStringArray = PackedStringArray()


func error(category: String, message: String) -> void:
	errors.append("[%s] %s" % [category, message])


func warn(category: String, message: String) -> void:
	warnings.append("[%s] %s" % [category, message])


func print_all() -> void:
	for w: String in warnings:
		print("注意 " + w)
	for e: String in errors:
		printerr("エラー " + e)
	print("エラー %d 件・注意 %d 件" % [errors.size(), warnings.size()])
