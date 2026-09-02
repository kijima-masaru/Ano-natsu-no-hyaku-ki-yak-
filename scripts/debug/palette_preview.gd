extends Node2D
## パレット全 16 色を並べて表示する確認用シーン。
## 上段に 8 色、下段に 8 色。各マスにインデックスと名前、光源色には印を付ける。
## 右端には「基調 4 色の上に光源 4 色を置いたときの見え方」を並べる。

const COLUMNS: int = 8
const SWATCH: int = 40
const GAP: int = 4
const ORIGIN: Vector2i = Vector2i(16, 24)
const FONT_SIZE: int = 12


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(384, 216)), Palette.get_color(Palette.NIGHT_SKY))
	draw_string(font, Vector2(ORIGIN.x, 14), "Palette 16 / 磐戸町奇譚",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.get_color(Palette.UI_TEXT))

	for index: int in Palette.SIZE:
		var col: int = index % COLUMNS
		@warning_ignore("integer_division")
		var row: int = index / COLUMNS
		var x: int = ORIGIN.x + col * (SWATCH + GAP)
		var y: int = ORIGIN.y + row * (SWATCH + GAP + 14)
		var fill: Color = Palette.get_color(index)
		draw_rect(Rect2(x, y, SWATCH, SWATCH), fill)
		draw_rect(Rect2(x, y, SWATCH, SWATCH), Palette.get_color(Palette.SUMI), false, 1.0)
		# 番号は暗い色の上では骨白、明るい色の上では墨で描く
		var label_color: Color = Palette.get_color(Palette.SUMI) if fill.get_luminance() > 0.5 \
			else Palette.get_color(Palette.BONE_WHITE)
		draw_string(font, Vector2(x + 3, y + 12), str(index),
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, label_color)
		if Palette.is_light_source(index):
			draw_rect(Rect2(x + SWATCH - 7, y + 3, 4, 4), label_color)
		draw_string(font, Vector2(x, y + SWATCH + 11), Palette.NAMES[index],
			HORIZONTAL_ALIGNMENT_LEFT, SWATCH, FONT_SIZE - 3, Palette.get_color(Palette.UI_TEXT_DIM))

	_draw_contrast_samples(font)


## 基調色（地面）の上に光源色を置いた見本。夜景での視認性を確認する。
func _draw_contrast_samples(font: Font) -> void:
	var bases: PackedInt32Array = [Palette.SUMI, Palette.NIGHT_SKY, Palette.DUSK_INDIGO, Palette.FOG_INDIGO]
	var x0: int = ORIGIN.x
	var y0: int = ORIGIN.y + 2 * (SWATCH + GAP + 14) + 4
	draw_string(font, Vector2(x0, y0 + 10), "光源 × 基調",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, Palette.get_color(Palette.UI_TEXT_DIM))
	for i: int in bases.size():
		var bx: int = x0 + i * 44
		var by: int = y0 + 14
		draw_rect(Rect2(bx, by, 40, 24), Palette.get_color(bases[i]))
		for j: int in Palette.LIGHT_SOURCES.size():
			draw_rect(Rect2(bx + 4 + j * 9, by + 8, 6, 8), Palette.get_color(Palette.LIGHT_SOURCES[j]))
