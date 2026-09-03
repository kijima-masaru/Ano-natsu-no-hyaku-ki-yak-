class_name StalkerView
extends RefCounted
## 追跡者のデバッグ表示（状態名・聴覚半径・視界扇形）。判断と移動は stalker.gd。ここは描くだけで状態を変えない。


## デバッグ表示（設定 debug_overlay がオンのとき）。stalker の draw_* を使う
static func draw_debug(stalker: Node2D, state_name: String, chasing: bool, facing: Vector2i, hearing_radius: float, vision_range: float, vision_half_angle: float) -> void:
	stalker.draw_arc(Vector2.ZERO, maxf(hearing_radius, 8.0), 0.0, TAU, 32, Palette.with_alpha(Palette.FLUORESCENT, 0.5), 1.0)
	var forward: float = Vector2(facing).angle()
	var pts: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i: int in 9:
		var a: float = forward - vision_half_angle + vision_half_angle * 2.0 * i / 8.0
		pts.append(Vector2.from_angle(a) * vision_range)
	stalker.draw_colored_polygon(pts, Palette.with_alpha(Palette.VENDING_RED if chasing else Palette.STREETLAMP_GLOW, 0.2))
	stalker.draw_string(ThemeDB.fallback_font, Vector2(-16, -26), state_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.get_color(Palette.FLUORESCENT))
