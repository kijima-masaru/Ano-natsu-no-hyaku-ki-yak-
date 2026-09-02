class_name MessageEntry
extends RefCounted
## messages.json の 1 エントリ。MessageResolver.resolve() が返す解決済みテキスト。

var id: String = ""
var speaker: String = ""
var speaker_name: String = ""
var text: String = ""
var truth_id: String = ""
## 話者の文字色（パレットインデックス）と文字送り倍率
var color_index: int = Palette.UI_TEXT
var speed: float = 1.0
## 真相版として解決されたか
var is_truth: bool = false


func has_truth() -> bool:
	return not truth_id.is_empty()
