extends Node
## 最後に使った入力装置（キーボード／ゲームパッド）を覚え、操作案内の文言を切り替える。
## 案内の文言は messages.json の ui_hint_* と、その「_pad」版（無ければキーボード版を返す）。
## 装置が変わったら device_changed を出すので、案内を出している画面はそれを受けて文言を差し替える。

signal device_changed(is_joypad: bool)

const PAD_SUFFIX: String = "_pad"
## スティックの遊びをまたぐ微小な動きで切り替わらないよう、軸はこの値以上で「操作した」とみなす
const AXIS_THRESHOLD: float = 0.5

var is_joypad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var joypad: bool
	if event is InputEventJoypadButton:
		joypad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < AXIS_THRESHOLD:
			return
		joypad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		joypad = false
	else:
		return
	if joypad != is_joypad:
		is_joypad = joypad
		device_changed.emit(is_joypad)


## 操作案内の文言。ゲームパッドなら <id>_pad を優先する
func hint(id: String) -> String:
	if is_joypad and MessageResolver.has_message(id + PAD_SUFFIX):
		return MessageResolver.text(id + PAD_SUFFIX)
	return MessageResolver.text(id)
