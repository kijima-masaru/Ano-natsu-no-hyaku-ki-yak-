extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/<name>.gd [引数]
## ゲーム本体からは参照しない（実機検証専用。docs/PLAYTEST_LOG.md）
## ドライバの起動役。change_scene で自分が解放されても走り続けるよう、Runner を root 直下に置く。
## 実行するスクリプトは --runner=res://scripts/tools/playtest/<name>.gd で指定（既定は driver_play.gd）

func _ready() -> void:
	var path: String = "res://scripts/tools/playtest/driver_play.gd"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--runner="):
			path = a.trim_prefix("--runner=")
	var runner: Node = Node.new()
	runner.name = "DriverRunner"
	runner.set_script(load(path))
	get_tree().root.call_deferred("add_child", runner)
