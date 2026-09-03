class_name ScreenFade
extends RefCounted
## 画面全体の暗転（黒の ColorRect を最前面の CanvasLayer に置き、アルファを Tween で動かす）。
## SceneRouter が持ち、フィールド遷移と fade アクションから使う。


## 暗転用の層を owner の下に作り、黒の矩形を返す（初期は透明）
static func build(owner: Node, layer_index: int) -> ColorRect:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = layer_index
	owner.add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.name = "Fade"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Palette.with_alpha(Palette.FADE_BLACK, 0.0)
	layer.add_child(rect)
	return rect


## アルファを seconds かけて alpha へ。終わるまで待てる
static func fade(owner: Node, rect: ColorRect, alpha: float, seconds: float) -> void:
	if rect == null:
		return
	var tween: Tween = owner.create_tween()
	tween.tween_property(rect, "color:a", clampf(alpha, 0.0, 1.0), maxf(0.0, seconds))
	await tween.finished
