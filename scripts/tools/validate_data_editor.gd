@tool
extends EditorScript
## エディタからデータ整合性を検証する（File > Run）。CLI 版は scripts/tools/validate_data.gd

const STRICT: bool = false


func _run() -> void:
	var report: DataReport = DataReport.new()
	var script: GDScript = load("res://scripts/tools/validate_data.gd") as GDScript
	var ok: bool = script.call("run", report, STRICT)
	report.print_all()
	print("validate_data: %s" % ("OK" if ok else "エラーあり"))
