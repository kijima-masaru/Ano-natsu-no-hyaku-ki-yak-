class_name TilePaintersObjects
extends RefCounted
## 人工物の「物」系（看板・光源・設備・石造物・門・鳥居・遊具・フォールバック）のペインタ群。
## 使い方は TilePaintersGround と同じ。paint() で名前 dispatch する。

const S: int = TileBrush.SIZE


static func paint(painter: String, b: TileBrush, p: Dictionary) -> bool:
	match painter:
		"sign": _sign(b, p)
		"pole": _pole(b, p)
		"lamp": _lamp(b, p)
		"light_bar": _light_bar(b, p)
		"vending": _vending(b, p)
		"box": _box(b, p)
		"bench": _bench(b, p)
		"tower": _tower(b, p)
		"car": _car(b, p)
		"slab": _slab(b, p)
		"torii": _torii(b, p)
		"gate": _gate(b, p)
		"masks": _masks(b, p)
		"slide": _slide(b, p)
		"fallback": _fallback(b, p)
		_:
			return false
	return true


## 看板・掲示板：板と文字列のダッシュ。glow で照明付き
static func _sign(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "wall", Palette.DUSK_INDIGO))
	var board: int = TileBrush.param(p, "board", Palette.OCHRE)
	b.rect(1, 2, 14, 11, board)
	b.frame(1, 2, 14, 11, TileBrush.param(p, "frame", Palette.RUST_DARK))
	var ink: int = TileBrush.param(p, "ink", Palette.SUMI)
	for y: int in range(4, 12, 2):
		b.hline(y, 3, 3 + int(b.rand(y, 0) * 8.0) + 2, ink)
	if p.has("glow"):
		b.hline(0, 2, 13, TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW))
	b.rect(7, 13, 2, 3, Palette.FOG_INDIGO)


## 電柱：柱・腕木・電線
static func _pole(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	b.rect(7, 0, 2, S, TileBrush.param(p, "pole", Palette.FOG_INDIGO))
	b.hline(2, 2, 13, Palette.CONCRETE)
	b.hline(0, 0, S - 1, Palette.SUMI)
	b.hline(1, 0, S - 1, Palette.SUMI)
	b.vline(7, 0, S - 1, Palette.CONCRETE)


## 街灯・常夜灯・橋灯：柱の先に光
static func _lamp(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var glow: int = TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW)
	if TileBrush.paramb(p, "stone", false):
		b.rect(5, 6, 6, 10, Palette.CONCRETE)
		b.rect(4, 3, 8, 3, Palette.FOG_INDIGO)
		b.rect(6, 4, 4, 2, glow)
		return
	b.rect(7, 4, 2, 12, TileBrush.param(p, "pole", Palette.FOG_INDIGO))
	b.rect(5, 1, 6, 3, glow)
	b.px(4, 2, glow)
	b.px(11, 2, glow)
	b.rect(6, 4, 4, 1, Palette.BONE_WHITE)


## 蛍光灯・非常灯：暗い天井に光る棒
static func _light_bar(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.NIGHT_SKY))
	var glow: int = TileBrush.param(p, "glow", Palette.FLUORESCENT)
	b.rect(2, 6, 12, 3, glow)
	b.rect(3, 7, 10, 1, Palette.BONE_WHITE)
	if TileBrush.paramb(p, "small", false):
		b.fill(Palette.NIGHT_SKY)
		b.rect(5, 5, 6, 5, glow)
		b.frame(4, 4, 8, 7, Palette.SUMI)


## 自販機正面：光る前面パネルと赤い帯、取り出し口
static func _vending(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "body", Palette.FOG_INDIGO))
	b.frame(0, 0, S, S, Palette.SUMI)
	b.rect(2, 2, 9, 7, TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW))
	b.rect(3, 3, 7, 5, Palette.BONE_WHITE)
	b.rect(11, 2, 3, 12, TileBrush.param(p, "accent", Palette.VENDING_RED))
	b.rect(2, 11, 8, 3, Palette.SUMI)
	if TileBrush.paramb(p, "broken", false):
		b.rect(2, 2, 9, 7, Palette.DEEP_INDIGO)
		b.diag(Palette.SUMI, 5)


## 汎用の箱型設備：本体・上面ハイライト・アクセント
static func _box(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var body: int = TileBrush.param(p, "body", Palette.CONCRETE)
	var x: int = TileBrush.param(p, "x", 3)
	var y: int = TileBrush.param(p, "y", 2)
	var w: int = TileBrush.param(p, "w", 10)
	var h: int = TileBrush.param(p, "h", 12)
	b.rect(x, y, w, h, body)
	b.frame(x, y, w, h, TileBrush.param(p, "edge", Palette.SUMI))
	b.hline(y + 1, x + 1, x + w - 2, TileBrush.param(p, "hi", Palette.BONE_WHITE))
	if p.has("accent"):
		b.rect(x + 2, y + 3, w - 4, TileBrush.param(p, "accent_h", 3), TileBrush.param(p, "accent", Palette.FLUORESCENT))
	if TileBrush.paramb(p, "slots", false):
		for yy: int in range(y + 4, y + h - 2, 3):
			b.hline(yy, x + 2, x + w - 3, Palette.SUMI)


static func _bench(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var wood: int = TileBrush.param(p, "wood", Palette.RUST)
	b.rect(1, 6, 14, 3, wood)
	b.hline(6, 1, 14, Palette.OCHRE)
	b.rect(1, 3, 14, 2, wood)
	b.rect(2, 9, 2, 5, Palette.RUST_DARK)
	b.rect(12, 9, 2, 5, Palette.RUST_DARK)


## 塔（時計塔・給水塔・火の見櫓・照明塔）：格子状の縦構造
static func _tower(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.NIGHT_SKY))
	var frame_color: int = TileBrush.param(p, "frame", Palette.FOG_INDIGO)
	b.vline(4, 0, S - 1, frame_color)
	b.vline(11, 0, S - 1, frame_color)
	for y: int in range(2, S, 4):
		b.hline(y, 4, 11, frame_color)
		b.px(5 + (y % 3), y + 1, Palette.DUSK_INDIGO)
	if p.has("top"):
		b.rect(3, 0, 10, 4, TileBrush.param(p, "top", Palette.CONCRETE))
	if p.has("glow"):
		b.rect(6, 1, 4, 2, TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW))


## 駐車車両：暗い車体・窓・車輪
static func _car(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	b.rect(1, 4, 14, 8, TileBrush.param(p, "body", Palette.DEEP_INDIGO))
	b.rect(3, 2, 10, 3, TileBrush.param(p, "body", Palette.DEEP_INDIGO))
	b.rect(4, 3, 8, 2, Palette.NIGHT_SKY)
	b.rect(2, 12, 3, 2, Palette.SUMI)
	b.rect(11, 12, 3, 2, Palette.SUMI)
	b.hline(4, 1, 14, Palette.FOG_INDIGO)


## 石造物（墓石・石碑・道標・石柱・石像・水位標）：縦長の石
static func _slab(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var stone: int = TileBrush.param(p, "stone", Palette.CONCRETE)
	var w: int = TileBrush.param(p, "w", 6)
	@warning_ignore("integer_division")
	var x: int = (S - w) / 2
	b.rect(x, 2, w, 12, stone)
	b.rect(x - 1, 13, w + 2, 3, TileBrush.param(p, "base", Palette.FOG_INDIGO))
	b.vline(x, 2, 13, Palette.BONE_WHITE)
	b.vline(x + w - 1, 2, 13, Palette.DUSK_INDIGO)
	if TileBrush.paramb(p, "marks", true):
		for y: int in range(4, 12, 3):
			b.hline(y, x + 2, x + w - 3, Palette.SUMI)
	if TileBrush.paramb(p, "cow", false):
		b.rect(2, 7, 12, 6, stone)
		b.rect(1, 5, 4, 4, stone)
		b.px(2, 6, Palette.SUMI)
	b.noise(TileBrush.param(p, "moss", Palette.MOSS_DARK), TileBrush.paramf(p, "moss_density", 0.0))


## 鳥居：2 本の柱と 2 段の貫
static func _torii(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var wood: int = TileBrush.param(p, "wood", Palette.RUST)
	b.rect(3, 3, 2, 13, wood)
	b.rect(11, 3, 2, 13, wood)
	b.rect(1, 1, 14, 2, wood)
	b.hline(0, 2, 13, Palette.RUST_DARK)
	b.rect(2, 5, 12, 1, wood)


## 門（山門・校門・門扉）：柱と屋根または横棒
static func _gate(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var post: int = TileBrush.param(p, "post", Palette.RUST_DARK)
	b.rect(1, 2, 3, 14, post)
	b.rect(12, 2, 3, 14, post)
	if TileBrush.paramb(p, "roof", true):
		b.rect(0, 0, S, 3, TileBrush.param(p, "roof_color", Palette.NIGHT_SKY))
		b.hline(3, 0, S - 1, Palette.FOG_INDIGO)
	else:
		for y: int in range(5, 14, 3):
			b.hline(y, 4, 11, TileBrush.param(p, "bar", Palette.FOG_INDIGO))


## 積まれた面：黄土色の楕円と暗い目。生活感の残留として静かに置く
static func _masks(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.NIGHT_SKY))
	for i: int in 3:
		var y: int = 1 + i * 5
		var x: int = 2 + (i % 2) * 3
		b.rect(x, y, 8, 5, Palette.OCHRE)
		b.px(x + 2, y + 2, Palette.SUMI)
		b.px(x + 5, y + 2, Palette.SUMI)
		b.hline(y + 4, x + 1, x + 6, Palette.RUST)


## 象の滑り台・遊具
static func _slide(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.OCHRE))
	b.noise(Palette.RUST, 0.05)
	b.rect(1, 6, 8, 8, Palette.CONCRETE)
	b.rect(9, 8, 6, 2, Palette.CONCRETE)
	b.rect(13, 10, 2, 5, Palette.CONCRETE)
	b.rect(2, 3, 5, 4, Palette.CONCRETE)
	b.px(3, 4, Palette.SUMI)
	b.hline(14, 9, 14, Palette.FOG_INDIGO)


## フォールバック：枠と、種別名の頭文字から作った 4×4 のビットパターン
static func _fallback(b: TileBrush, p: Dictionary) -> void:
	b.fill(Palette.DEEP_INDIGO)
	b.frame(0, 0, S, S, Palette.VENDING_RED)
	b.diag(Palette.DUSK_INDIGO, 6)
	var name: String = str(p.get("name", "?"))
	var code: int = name.unicode_at(0) if name.length() > 0 else 63
	b.rect(5, 5, 6, 6, Palette.SUMI)
	b.glyph_bits(code, Palette.BONE_WHITE)

