class_name TilePaintersBuilt
extends RefCounted
## 人工物の「面」系（道路標示・壁・床・屋根・窓・戸・柵・橋）のペインタ群。
## 使い方は TilePaintersGround と同じ。paint() で名前 dispatch する。

const S: int = TileBrush.SIZE


static func paint(painter: String, b: TileBrush, p: Dictionary) -> bool:
	match painter:
		"line_h": _line(b, p, true)
		"line_v": _line(b, p, false)
		"grating": _grating(b, p)
		"curb": _curb(b, p)
		"block_wall": _block_wall(b, p)
		"tile_wall": _tile_wall(b, p)
		"concrete_wall": _concrete_wall(b, p)
		"plank_v": _planks(b, p, true)
		"plank_h": _planks(b, p, false)
		"roof": _roof(b, p)
		"window": _window(b, p)
		"glass": _glass(b, p)
		"door": _door(b, p)
		"shutter": _shutter(b, p)
		"fence": _fence(b, p)
		"rail": _rail(b, p)
		"mesh": _mesh(b, p)
		"barricade": _barricade(b, p)
		"bridge": _bridge(b, p)
		_:
			return false
	return true


## 地面の上に線。thick 太さ、dashed で破線、pos で位置
static func _line(b: TileBrush, p: Dictionary, horizontal: bool) -> void:
	TilePaintersGround.paint("ground", b, p)
	var line: int = TileBrush.param(p, "line", Palette.BONE_WHITE)
	var thick: int = TileBrush.param(p, "thick", 2)
	var pos: int = TileBrush.param(p, "pos", 7)
	var dashed: bool = TileBrush.paramb(p, "dashed", false)
	for i: int in S:
		if dashed and (i % 8) >= 5:
			continue
		for t: int in thick:
			if horizontal:
				b.px(i, pos + t, line)
			else:
				b.px(pos + t, i, line)


## 側溝・グレーチング：縦のスロット列
static func _grating(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.FOG_INDIGO))
	b.rect(0, 5, S, 6, Palette.CONCRETE)
	for x: int in range(1, S, 3):
		b.rect(x, 6, 1, 4, Palette.SUMI)


## 縁石：上半分が歩道、下半分が車道
static func _curb(b: TileBrush, p: Dictionary) -> void:
	b.rect(0, 0, S, 8, TileBrush.param(p, "walk", Palette.CONCRETE))
	b.rect(0, 8, S, 8, TileBrush.param(p, "road", Palette.DUSK_INDIGO))
	b.hline(8, 0, S - 1, Palette.BONE_WHITE)
	b.hline(9, 0, S - 1, Palette.SUMI)
	b.noise(Palette.FOG_INDIGO, 0.06)


static func _block_wall(b: TileBrush, p: Dictionary) -> void:
	b.bricks(TileBrush.param(p, "base", Palette.CONCRETE), TileBrush.param(p, "mortar", Palette.FOG_INDIGO),
		TileBrush.param(p, "bw", 8), TileBrush.param(p, "bh", 4))
	b.noise(TileBrush.param(p, "stain", Palette.DUSK_INDIGO), TileBrush.paramf(p, "stain_density", 0.05))


## タイル壁：正方形の目地
static func _tile_wall(b: TileBrush, p: Dictionary) -> void:
	b.bricks(TileBrush.param(p, "base", Palette.CONCRETE), TileBrush.param(p, "grout", Palette.FOG_INDIGO), 4, 4)


## コンクリート壁：雨染みの縦筋
static func _concrete_wall(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.CONCRETE))
	for x: int in S:
		if b.rand(x, 0) < TileBrush.paramf(p, "stain", 0.3):
			b.vline(x, 0, int(b.rand(x, 1) * S), Palette.FOG_INDIGO)
	b.hline(S - 1, 0, S - 1, Palette.DUSK_INDIGO)


## 板壁・床：vertical で縦張り、横なら下見板／廊下床
static func _planks(b: TileBrush, p: Dictionary, vertical: bool) -> void:
	var base: int = TileBrush.param(p, "base", Palette.RUST)
	var gap: int = TileBrush.param(p, "gap", Palette.RUST_DARK)
	b.fill(base)
	for i: int in range(0, S, TileBrush.param(p, "width", 4)):
		if vertical:
			b.vline(i, 0, S - 1, gap)
		else:
			b.hline(i, 0, S - 1, gap)
	b.noise(TileBrush.param(p, "grain", Palette.RUST_DARK), 0.08)
	if TileBrush.paramb(p, "worn", false):
		b.noise(Palette.OCHRE, 0.06)


## 瓦屋根：2px ごとに山と谷。bark=true で檜皮（細い横縞）
static func _roof(b: TileBrush, p: Dictionary) -> void:
	var base: int = TileBrush.param(p, "base", Palette.DUSK_INDIGO)
	var dark: int = TileBrush.param(p, "dark", Palette.NIGHT_SKY)
	b.fill(base)
	if TileBrush.paramb(p, "bark", false):
		for y: int in range(0, S, 2):
			b.hline(y, 0, S - 1, dark)
		return
	for y: int in range(0, S, 4):
		b.hline(y, 0, S - 1, dark)
		@warning_ignore("integer_division")
		var offset: int = 0 if (y / 4) % 2 == 0 else 2
		for x: int in range(offset, S, 4):
			b.px(x, y + 1, dark)
			b.px(x, y + 2, TileBrush.param(p, "hi", Palette.FOG_INDIGO))


## 窓：壁に窓枠とガラス。lit=true で点灯
static func _window(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "wall", Palette.CONCRETE))
	var lit: bool = TileBrush.paramb(p, "lit", false)
	b.rect(3, 3, 10, 10, TileBrush.param(p, "frame", Palette.SUMI))
	b.rect(4, 4, 8, 8, TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW) if lit else Palette.DEEP_INDIGO)
	b.vline(7, 4, 11, TileBrush.param(p, "frame", Palette.SUMI))
	b.hline(7, 4, 11, TileBrush.param(p, "frame", Palette.SUMI))


## ガラス面・ガラス扉：面全体が光る
static func _glass(b: TileBrush, p: Dictionary) -> void:
	var lit: bool = TileBrush.paramb(p, "lit", true)
	b.fill(TileBrush.param(p, "glow", Palette.FLUORESCENT) if lit else Palette.DEEP_INDIGO)
	b.frame(0, 0, S, S, Palette.SUMI)
	b.vline(7, 0, S - 1, Palette.SUMI)
	b.diag(Palette.BONE_WHITE if lit else Palette.DUSK_INDIGO, 9, 2)


static func _door(b: TileBrush, p: Dictionary) -> void:
	_planks(b, {"base": TileBrush.param(p, "base", Palette.RUST_DARK), "gap": Palette.SUMI, "width": 5}, true)
	b.frame(0, 0, S, S, Palette.SUMI)
	b.rect(11, 8, 2, 2, TileBrush.param(p, "knob", Palette.OCHRE))


## シャッター：横スラット。half=true で下が開いて暗い
static func _shutter(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.FOG_INDIGO))
	var bottom: int = 10 if TileBrush.paramb(p, "half", false) else S
	for y: int in range(0, bottom, 2):
		b.hline(y, 0, S - 1, Palette.DUSK_INDIGO)
	if bottom < S:
		b.rect(0, bottom, S, S - bottom, Palette.SUMI)
	b.noise(Palette.RUST, 0.05)


## フェンス：金網の斜め格子と支柱。locked で赤い錠
static func _fence(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var wire: int = TileBrush.param(p, "wire", Palette.CONCRETE)
	b.diag(wire, 4, 0)
	b.diag(wire, 4, 2)
	b.rect(0, 0, 2, S, Palette.FOG_INDIGO)
	b.hline(1, 0, S - 1, Palette.FOG_INDIGO)
	if TileBrush.paramb(p, "locked", false):
		b.rect(6, 6, 4, 4, Palette.VENDING_RED)
		b.px(7, 5, Palette.SUMI)
		b.px(8, 5, Palette.SUMI)


## 手すり・ガードレール・欄干・玉垣：横桟と支柱
static func _rail(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var bar: int = TileBrush.param(p, "bar", Palette.CONCRETE)
	b.rect(0, 5, S, 2, bar)
	if TileBrush.paramb(p, "double", true):
		b.rect(0, 10, S, 2, bar)
	for x: int in range(2, S, 6):
		b.vline(x, 3, 14, TileBrush.param(p, "post", Palette.FOG_INDIGO))


## 金網・ネット：地面の上に格子
static func _mesh(b: TileBrush, p: Dictionary) -> void:
	TilePaintersGround.paint("ground", b, {"base": TileBrush.param(p, "ground", Palette.DUSK_INDIGO)})
	var wire: int = TileBrush.param(p, "wire", Palette.CONCRETE)
	for i: int in range(0, S, 4):
		b.hline(i, 0, S - 1, wire)
		b.vline(i, 0, S - 1, wire)


## バリケード：骨白と赤の斜め縞
static func _barricade(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	b.rect(0, 4, S, 7, Palette.BONE_WHITE)
	for y: int in range(4, 11):
		for x: int in S:
			@warning_ignore("integer_division")
			if ((x + y) / 3) % 2 == 0:
				b.px(x, y, Palette.VENDING_RED)
	b.rect(2, 11, 2, 4, Palette.FOG_INDIGO)
	b.rect(12, 11, 2, 4, Palette.FOG_INDIGO)


## 橋：床板と欄干、橋灯
static func _bridge(b: TileBrush, p: Dictionary) -> void:
	_planks(b, {"base": Palette.CONCRETE, "gap": Palette.FOG_INDIGO, "width": 4}, false)
	b.rect(0, 0, S, 2, Palette.FOG_INDIGO)
	b.hline(0, 0, S - 1, Palette.BONE_WHITE)
	if p.has("glow"):
		b.rect(7, 0, 2, 2, TileBrush.param(p, "glow", Palette.STREETLAMP_GLOW))
