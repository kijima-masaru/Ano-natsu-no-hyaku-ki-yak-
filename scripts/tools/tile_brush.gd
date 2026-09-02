class_name TileBrush
extends RefCounted
## 16×16 の Image にパレット色でプリミティブを描くブラシ。
## 色は常にパレットのインデックスで受け取る。tile_painters_*.gd からのみ使うこと。
## 乱数は座標ハッシュで決定的に生成し、同じ種別は常に同じ絵になる。

const SIZE: int = GameConstants.TILE_SIZE

var image: Image
var _seed: int


func _init(seed_value: int = 0) -> void:
	image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_seed = seed_value


## Dictionary から int パラメータを既定値付きで取り出す
static func param(p: Dictionary, key: String, default_value: int) -> int:
	return int(p.get(key, default_value))


static func paramf(p: Dictionary, key: String, default_value: float) -> float:
	return float(p.get(key, default_value))


static func paramb(p: Dictionary, key: String, default_value: bool) -> bool:
	return bool(p.get(key, default_value))


## 0.0〜1.0 の決定的な擬似乱数（座標とシード依存）
func rand(x: int, y: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + _seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func fill(index: int) -> void:
	image.fill(Palette.get_color(index))


func fill_alpha(index: int, alpha: float) -> void:
	image.fill(Palette.with_alpha(index, alpha))


func px(x: int, y: int, index: int) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	image.set_pixel(x, y, Palette.get_color(index))


func rect(x: int, y: int, w: int, h: int, index: int) -> void:
	for yy: int in range(maxi(y, 0), mini(y + h, SIZE)):
		for xx: int in range(maxi(x, 0), mini(x + w, SIZE)):
			image.set_pixel(xx, yy, Palette.get_color(index))


## 枠線だけ描く
func frame(x: int, y: int, w: int, h: int, index: int) -> void:
	hline(y, x, x + w - 1, index)
	hline(y + h - 1, x, x + w - 1, index)
	vline(x, y, y + h - 1, index)
	vline(x + w - 1, y, y + h - 1, index)


func hline(y: int, x0: int, x1: int, index: int) -> void:
	for x: int in range(x0, x1 + 1):
		px(x, y, index)


func vline(x: int, y0: int, y1: int, index: int) -> void:
	for y: int in range(y0, y1 + 1):
		px(x, y, index)


## 密度 density（0〜1）で点をまく
func noise(index: int, density: float, x0: int = 0, y0: int = 0, w: int = SIZE, h: int = SIZE) -> void:
	for y: int in range(y0, y0 + h):
		for x: int in range(x0, x0 + w):
			if rand(x, y) < density:
				px(x, y, index)


## 市松模様
func checker(a: int, b: int, cell: int = 2) -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			@warning_ignore("integer_division")
			var odd: bool = ((x / cell) + (y / cell)) % 2 == 1
			px(x, y, b if odd else a)


## 等間隔のドット
func dots(index: int, spacing: int, offset_x: int = 0, offset_y: int = 0) -> void:
	var y: int = offset_y
	while y < SIZE:
		var x: int = offset_x
		while x < SIZE:
			px(x, y, index)
			x += spacing
		y += spacing


## 斜線ハッチ（step 間隔）
func diag(index: int, step: int = 4, offset: int = 0) -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			if (x + y + offset) % step == 0:
				px(x, y, index)


## レンガ／ブロック積み。bw×bh のブロック、目地 1px
func bricks(fg: int, mortar: int, bw: int = 8, bh: int = 4) -> void:
	fill(fg)
	var row: int = 0
	var y: int = 0
	while y < SIZE:
		hline(y, 0, SIZE - 1, mortar)
		@warning_ignore("integer_division")
		var shift: int = (bw / 2) if row % 2 == 1 else 0
		var x: int = shift
		while x < SIZE:
			vline(x, y, mini(y + bh - 1, SIZE - 1), mortar)
			x += bw
		y += bh
		row += 1


## 文字コードを 4×4 のビットパターンとして中央に描く（フォールバック識別用）
func glyph_bits(code: int, index: int, x0: int = 6, y0: int = 6) -> void:
	var bits: int = (code ^ (code >> 7) ^ (code >> 13)) & 0xffff
	for i: int in 16:
		if (bits >> i) & 1 == 1:
			@warning_ignore("integer_division")
			px(x0 + (i % 4), y0 + (i / 4), index)
