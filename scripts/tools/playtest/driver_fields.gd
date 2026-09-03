extends Node
## 使い方：xvfb-run ... godot --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_fields.gd --out=<dir>
## レビュー用：16 フィールドを昼と夜で 1 枚ずつ撮る（8/26 の状態、プレイヤーは既定の出現位置）

var _out: String = "user://fields/"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	SaveManager.set_setting("instant_text", true)
	await get_tree().process_frame
	GameState.reset()
	Calendar.ignore_availability = true
	for f: String in ["flag_yakushi_open", "old_school_opened", "key_tunnel_fence", "notebook_unlocked", "flag_minimap_unlocked"]:
		GameState.raise_flag(f)
	Calendar.set_day(26)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var w: Control = get_tree().current_scene.get("_message_window")
	await _settle(w)
	for tod: String in ["noon", "night"]:
		Calendar.set_time_of_day(tod)
		for i: int in 16:
			var fid: String = "F%02d" % (i + 1)
			SceneRouter.go_to(fid)
			await _settle(w)
			Lighting.set_flashlight(tod == "night")
			for k: int in 20:
				await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(_out + "%s_%s.png" % [fid, tod])
			print("shot %s %s" % [fid, tod])
	get_tree().quit(0)


func _settle(w: Control) -> void:
	var idle: int = 0
	for i: int in 2400:
		await get_tree().process_frame
		if not is_instance_valid(w):
			return
		var busy: bool = SceneRouter.is_transitioning or EventSystem.is_running
		if bool(w.get("is_choosing")):
			busy = true; w.call("_on_choice_activated", 0, "0")
		elif bool(w.get("is_open")):
			busy = true
			var ev: InputEventAction = InputEventAction.new(); ev.action = "interact"; ev.pressed = true
			w.call("_unhandled_input", ev)
		idle = 0 if busy else idle + 1
		if idle >= 3:
			return
