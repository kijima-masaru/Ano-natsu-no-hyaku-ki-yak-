extends CanvasLayer
## デバッグ用オーバーレイ。接近度・段階・隠蔽リスト・日付・所持品・主要フラグを左上に表示する。
## 設定 debug_overlay または F3 で切り替え。F4 で truth_revealed を反転（二層テキストの確認用）。
## 製品ビルドでは設定項目ごと隠す想定（ステップ5）。

const FONT_SIZE: int = 10
const REFRESH_INTERVAL: float = 0.25

var _label: Label
var _timer: float = 0.0


func _ready() -> void:
	layer = 90
	_label = Label.new()
	_label.position = Vector2(2, 2)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.get_color(Palette.FLUORESCENT))
	_label.add_theme_color_override("font_shadow_color", Palette.get_color(Palette.SUMI))
	add_child(_label)
	visible = bool(SaveManager.get_setting("debug_overlay"))
	SaveManager.setting_changed.connect(func(key: String, value: Variant) -> void:
		if key == "debug_overlay":
			visible = bool(value))


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer < REFRESH_INTERVAL:
		return
	_timer = 0.0
	_label.text = "\n".join([
		"day %d %s | field %s | pts %d" % [Calendar.day, Calendar.time_of_day, SceneRouter.current_field_id, Calendar.investigation_points],
		"suspicion %d (%s) | truth %s" % [Suspicion.value, Suspicion.stage_key(), str(GameState.has_flag("truth_revealed"))],
		"concealed: %s" % ", ".join(GameState.concealed_evidence),
		"witnessed: %s" % ", ".join(GameState.witnessed_concealments),
		"evidence: %s" % ", ".join(GameState.evidence),
		"items: %s | flags %d" % [", ".join(GameState.items), GameState.flags.size()],
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		SaveManager.set_setting("debug_overlay", not visible)
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("debug_truth"):
		if GameState.has_flag("truth_revealed"):
			GameState.clear_flag("truth_revealed")
		else:
			GameState.raise_flag("truth_revealed")
		get_viewport().set_input_as_handled()
