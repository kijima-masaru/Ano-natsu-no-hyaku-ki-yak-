extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_smoke.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## 実機検証ドライバ 1：autoload の読み込み結果、全フィールドの組み立て、光源数、F11 の階切替

func _ready() -> void:
	await get_tree().process_frame
	print("== autoloads ==")
	for n: String in ["Palette","GameState","MessageResolver","FieldRegistry","Calendar","SceneRouter","SaveManager","EventSystem","Suspicion","EvidenceRegistry","AudioManager","Lighting","AttachedEntity","AnomalySystem","SteamBridge"]:
		print("  %s: %s" % [n, "ok" if get_tree().root.get_node_or_null(n) != null else "MISSING"])
	print("MessageResolver errors: ", MessageResolver.load_errors)
	print("FieldRegistry errors: ", FieldRegistry.load_errors, " loaded=", FieldRegistry.is_loaded)
	print("EventSystem load_errors: ", EventSystem.load_errors)
	print("EventSystem validation_errors: ", EventSystem.validation_errors)
	print("EvidenceRegistry errors: ", EvidenceRegistry.get("load_errors"))
	print("AnomalySystem errors: ", AnomalySystem.get("load_errors"))
	print("Calendar day=%d tod=%s" % [Calendar.day, Calendar.time_of_day])
	print("== fields ==")
	var holder: Node2D = Node2D.new()
	add_child(holder)
	for id: String in FieldRegistry.get_field_ids():
		var def: FieldData = FieldRegistry.get_field(id)
		var t0: int = Time.get_ticks_usec()
		var packed: PackedScene = load(def.scene_path) as PackedScene
		if packed == null:
			print("  %s: scene missing %s" % [id, def.scene_path]); continue
		var f: FieldBase = packed.instantiate() as FieldBase
		f.setup(def)
		holder.add_child(f)
		await get_tree().process_frame
		var lights: int = _count(f, "PointLight2D")
		var inter: int = f.triggers.get_child_count()
		var t1: int = Time.get_ticks_usec()
		var consts: Dictionary = f.get_script().get_script_constant_map()
		print("  %s %s size=%s lights=%d triggers=%d build=%.1fms floors=%s" % [id, def.name, f.get_size_tiles(), lights, inter, (t1 - t0) / 1000.0, str(consts.has("FLOORS"))])
		if consts.has("FLOORS"):
			var floors: Dictionary = consts["FLOORS"]
			for fl: String in floors.keys():
				var ok: bool = f.switch_floor(fl, Vector2i(2, 2))
				await get_tree().process_frame
				print("    switch_floor(%s) -> %s current=%s size=%s lights=%d triggers=%d" % [fl, ok, f.current_floor, f.get_size_tiles(), _count(f, "PointLight2D"), f.triggers.get_child_count()])
			var back: bool = f.switch_floor(FieldFloors.OUTSIDE, Vector2i(2, 2))
			await get_tree().process_frame
			print("    switch_floor(outside) -> %s current=%s size=%s" % [back, f.current_floor, f.get_size_tiles()])
		holder.remove_child(f)
		f.free()
	print("== done ==")
	get_tree().quit(0)


func _count(node: Node, cls: String) -> int:
	var n: int = 1 if node.get_class() == cls else 0
	for c: Node in node.get_children():
		n += _count(c, cls)
	return n
