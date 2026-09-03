extends Control
## 真相到達時の提示画面。プレイヤーが「調べた」だけだったものの一覧と、実際に悠がしたことを重ねて示す。
## 本作最大の一撃なので、初回は文字送りをスキップできない（ページ送りは可）。周回（クリア記録あり）だけ長押しで飛ばせる。
## 構成は docs/CONCEALMENT_LIST.md「提示画面」に従う：
##   黒地に「あなたが調べたもの」→ 1 件ずつ、まず「あなたが見た文」→ 間 → 「実際にしたこと」を真相の色で重ねる
##   → 件と件の間は暗転と無音 → 最後は黒のまま（hold）で、呼び出し側がナツの台詞を出してから close() する。

signal finished()

const FONT_SIZE: int = 12
const CHARS_PER_SECOND_SHOWN: float = 18.0
const CHARS_PER_SECOND_ACTION: float = 12.0
const LINE_CHARS: int = 28
## 見た文を出し終えてから実際の行動を出すまでの間
const PAUSE_BEFORE_ACTION: float = 1.4
## 件と件の間の暗転
const FADE_SEC: float = 0.7
const BLACK_HOLD_SEC: float = 0.5
## 周回時のスキップ長押し
const SKIP_HOLD_SEC: float = 1.5
## 真相版の文字色（実際にしたこと）
const TRUTH_COLOR: int = Palette.OCHRE

var _items: Array[Dictionary] = []
var _index: int = -1
var _can_advance: bool = false
var _skip_allowed: bool = false
var _skip_hold: float = 0.0
var _closing: bool = false
## true なら最後の件の後も黒のまま残り、close() で消える
var hold_after_last: bool = true

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $Title
@onready var _counter: Label = $Counter
@onready var _shown: Label = $Shown
@onready var _action: Label = $Action
@onready var _hint: Label = $Hint
@onready var _veil: ColorRect = $Veil


func _ready() -> void:
	_bg.color = Palette.get_color(Palette.SUMI)
	_veil.color = Palette.get_color(Palette.SUMI)
	for label: Label in [_title, _counter, _shown, _action, _hint]:
		label.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_counter.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_shown.add_theme_color_override("font_color", Palette.get_color(Palette.BONE_WHITE))
	_action.add_theme_color_override("font_color", Palette.get_color(TRUTH_COLOR))
	_hint.add_theme_color_override("font_color", Palette.get_color(Palette.UI_TEXT_DIM))
	_title.text = MessageResolver.text("ui_reveal_title")
	_hint.text = InputDevice.hint("ui_reveal_hint")
	_hint.visible = false
	_skip_allowed = not (SaveManager.system.get("cleared_endings", []) as Array).is_empty()
	_build_items()
	_run()


## 各証拠を 1 件に：表示文 → 実際の行動（目撃されたものは澪の行）
func _build_items() -> void:
	var ids: PackedStringArray = GameState.concealed_evidence.duplicate()
	for id: String in GameState.witnessed_concealments:
		if not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		_items.append({"shown": MessageResolver.text("ui_reveal_empty"), "action": ""})
		return
	for id: String in ids:
		var e: EvidenceData = EvidenceRegistry.get_evidence(id)
		if e == null:
			continue
		if GameState.witnessed_concealments.has(id):
			_items.append({"shown": MessageResolver.text("msg_conceal_witnessed"), "action": MessageResolver.text("ui_reveal_witnessed")})
		else:
			_items.append({"shown": MessageResolver.text(e.shown_id), "action": MessageResolver.text(e.action_id)})


func _run() -> void:
	# 最初は黒から。題だけ先に出す
	_veil.modulate.a = 1.0
	_shown.text = ""
	_action.text = ""
	_counter.text = ""
	await _fade_veil(0.0, FADE_SEC)
	await _wait(BLACK_HOLD_SEC)
	for i: int in _items.size():
		if _closing:
			return
		_index = i
		await _present(_items[i], i + 1, _items.size())
		if _closing:
			return
		await _fade_veil(1.0, FADE_SEC)
		_shown.text = ""
		_action.text = ""
		_hint.visible = false
		await _wait(BLACK_HOLD_SEC)
		if i < _items.size() - 1:
			await _fade_veil(0.0, FADE_SEC)
	_counter.text = ""
	_title.visible = false
	finished.emit()
	if not hold_after_last:
		queue_free()


func _present(item: Dictionary, number: int, total: int) -> void:
	_counter.text = MessageResolver.text("ui_reveal_count", [number, total])
	_can_advance = false
	_hint.visible = false
	await _typewrite(_shown, "\n".join(TextLayout.wrap_line(str(item["shown"]), LINE_CHARS)), CHARS_PER_SECOND_SHOWN)
	if _closing:
		return
	await _wait(PAUSE_BEFORE_ACTION)
	if not str(item["action"]).is_empty():
		await _typewrite(_action, "\n".join(TextLayout.wrap_line(str(item["action"]), LINE_CHARS)), CHARS_PER_SECOND_ACTION)
	if _closing:
		return
	_hint.visible = true
	_can_advance = true
	while _can_advance and not _closing:
		await get_tree().process_frame


## 1 文字ずつ。初回はスキップ不可。周回のみ長押しで全件を飛ばす
func _typewrite(label: Label, text: String, cps: float) -> void:
	label.text = text
	label.visible_characters = 0
	var shown: float = 0.0
	while label.visible_characters < text.length() and not _closing:
		await get_tree().process_frame
		shown += cps * get_process_delta_time()
		label.visible_characters = mini(int(shown), text.length())
	label.visible_characters = -1


func _process(delta: float) -> void:
	if not _skip_allowed or _closing:
		return
	if Input.is_action_pressed("cancel"):
		_skip_hold += delta
		if _skip_hold >= SKIP_HOLD_SEC:
			_skip_all()
	else:
		_skip_hold = 0.0


func _skip_all() -> void:
	_closing = true
	_index = _items.size()
	_shown.text = ""
	_action.text = ""
	_counter.text = ""
	_hint.visible = false
	_veil.modulate.a = 1.0
	_title.visible = false
	finished.emit()
	if not hold_after_last:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_advance:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_can_advance = false


## 黒のまま残した画面を消す（呼び出し側の close_concealment_reveal アクション）
func close() -> void:
	_closing = true
	await _fade_veil(1.0, FADE_SEC * 0.5)
	queue_free()


func _fade_veil(target: float, sec: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_veil, "modulate:a", target, sec)
	await tween.finished


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
