extends Control
## スタッフロール。黒地に messages.json の ui_credits_<n> を順に流す。エンディングの後、タイトルへ戻る前に出す。
## 最低 MIN_SECONDS は飛ばせない。以後は決定で終える

signal finished()

const FONT_SIZE: int = 12
const MIN_SECONDS: float = 3.0
const SCROLL_PX_PER_SEC: float = 23.0
const LINE_GAP_PX: float = 37.0
const MAX_LINES: int = 40

var _elapsed: float = 0.0
var _done: bool = false

@onready var _bg: ColorRect = $Background
@onready var _lines: Control = $Lines


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.SUMI)
	AudioManager.play_bgm("bgm_credits")
	var y: float = float(GameConstants.VIEWPORT_HEIGHT)
	for i: int in range(1, MAX_LINES + 1):
		var id: String = "ui_credits_%02d" % i
		if not MessageResolver.has_message(id):
			break
		var label: Label = Label.new()
		label.text = MessageResolver.text(id)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM if i == 1 else Palette.UI_TEXT))
		label.position = Vector2(40.0, y)
		_lines.add_child(label)
		y += LINE_GAP_PX


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_lines.position.y -= SCROLL_PX_PER_SEC * delta
	var last: Control = _lines.get_child(_lines.get_child_count() - 1) as Control if _lines.get_child_count() > 0 else null
	if last == null or _lines.position.y + last.position.y < -LINE_GAP_PX:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _elapsed < MIN_SECONDS:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	_done = true
	finished.emit()
	queue_free()
