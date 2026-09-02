class_name TilePaintersGround
extends RefCounted
## 地面・自然・水・地形系のペインタ群。名前で dispatch する（paint() を参照）。
## 各ペインタは TileBrush とパラメータ Dictionary（パレットインデックス等）を受け取る。


## 名前に対応するペインタを実行する。未知の名前なら false
static func paint(painter: String, b: TileBrush, p: Dictionary) -> bool:
	match painter:
		"ground": _ground(b, p)
		"gravel": _gravel(b, p)
		"grass": _grass(b, p)
		"soil_rows": _soil_rows(b, p)
		"path": _path(b, p)
		"water": _water(b, p)
		"paddy": _paddy(b, p)
		"paving": _paving(b, p)
		"interlock": _interlock(b, p)
		"tree": _tree(b, p)
		"conifer": _conifer(b, p)
		"bare_tree": _bare_tree(b, p)
		"rock": _rock(b, p)
		"cliff": _cliff(b, p)
		"slope": _slope(b, p)
		"moat": _moat(b, p)
		"stairs": _stairs(b, p)
		"mound": _mound(b, p)
		"fog": _fog(b, p)
		"crack": _crack(b, p)
		"spring": _spring(b, p)
		_:
			return false
	return true


## 平らな地面＋まばらな粒（アスファルト・土・砂）
static func _ground(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.DUSK_INDIGO))
	b.noise(TileBrush.param(p, "speck", Palette.FOG_INDIGO), TileBrush.paramf(p, "density", 0.08))
	if p.has("speck2"):
		b.noise(TileBrush.param(p, "speck2", Palette.SUMI), TileBrush.paramf(p, "density2", 0.04))


## 砂利：2 色の粒を密に
static func _gravel(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.FOG_INDIGO))
	b.noise(TileBrush.param(p, "light", Palette.CONCRETE), 0.25)
	b.noise(TileBrush.param(p, "dark", Palette.DUSK_INDIGO), 0.2)


## 草地：縦の短い筋。tall=true で丈高
static func _grass(b: TileBrush, p: Dictionary) -> void:
	var base: int = TileBrush.param(p, "base", Palette.FADED_GREEN)
	var blade: int = TileBrush.param(p, "blade", Palette.FADED_GREEN_LIGHT)
	var tall: bool = TileBrush.paramb(p, "tall", false)
	b.fill(base)
	for y: int in TileBrush.SIZE:
		for x: int in TileBrush.SIZE:
			if b.rand(x, y) < (0.22 if tall else 0.12):
				b.vline(x, y - (2 if tall else 1), y, blade)
	if tall:
		b.noise(TileBrush.param(p, "shadow", Palette.MOSS_DARK), 0.1)


## 畝：4px ごとの横筋
static func _soil_rows(b: TileBrush, p: Dictionary) -> void:
	var base: int = TileBrush.param(p, "base", Palette.RUST_DARK)
	b.fill(base)
	for y: int in range(1, TileBrush.SIZE, 4):
		b.hline(y, 0, TileBrush.SIZE - 1, TileBrush.param(p, "ridge", Palette.RUST))
		b.hline(y + 1, 0, TileBrush.SIZE - 1, Palette.SUMI)
	b.noise(Palette.OCHRE, 0.05)


## 踏み分け道・畦：草の中央に土の帯
static func _path(b: TileBrush, p: Dictionary) -> void:
	_grass(b, {"base": TileBrush.param(p, "grass", Palette.FADED_GREEN)})
	var dirt: int = TileBrush.param(p, "dirt", Palette.RUST_DARK)
	var vertical: bool = TileBrush.paramb(p, "vertical", true)
	if vertical:
		b.rect(5, 0, 6, TileBrush.SIZE, dirt)
	else:
		b.rect(0, 5, TileBrush.SIZE, 6, dirt)
	b.noise(Palette.OCHRE, 0.06)


## 水面：横方向の波線。flow=true で流れの斜め筋を足す
static func _water(b: TileBrush, p: Dictionary) -> void:
	var base: int = TileBrush.param(p, "base", Palette.DEEP_INDIGO)
	var ripple: int = TileBrush.param(p, "ripple", Palette.DUSK_INDIGO)
	b.fill(base)
	for y: int in range(1, TileBrush.SIZE, 3):
		var offset: int = int(b.rand(0, y) * 6.0)
		for x: int in range(offset, TileBrush.SIZE, 7):
			b.hline(y, x, x + 3, ripple)
	if TileBrush.paramb(p, "flow", false):
		b.diag(Palette.FOG_INDIGO, 8, 3)
	b.noise(TileBrush.param(p, "glint", Palette.CONCRETE), 0.015)


## 水田：水面に稲株の格子
static func _paddy(b: TileBrush, p: Dictionary) -> void:
	_water(b, {"base": Palette.DEEP_INDIGO, "ripple": Palette.DUSK_INDIGO})
	var rice: int = TileBrush.param(p, "rice", Palette.FADED_GREEN)
	for y: int in range(2, TileBrush.SIZE, 4):
		for x: int in range(2, TileBrush.SIZE, 4):
			b.rect(x, y - 1, 1, 2, rice)
			b.px(x, y - 2, Palette.FADED_GREEN_LIGHT)


## 石畳：7px の石を 1px の目地で
static func _paving(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "gap", Palette.DUSK_INDIGO))
	var stone: int = TileBrush.param(p, "stone", Palette.CONCRETE)
	for y: int in range(0, TileBrush.SIZE, 8):
		for x: int in range(0, TileBrush.SIZE, 8):
			b.rect(x, y, 7, 7, stone)
	b.noise(Palette.FOG_INDIGO, 0.12)
	b.noise(Palette.MOSS_DARK, TileBrush.paramf(p, "moss", 0.0))


## インターロッキング：2 色のレンガ
static func _interlock(b: TileBrush, p: Dictionary) -> void:
	b.bricks(TileBrush.param(p, "a", Palette.CONCRETE), TileBrush.param(p, "gap", Palette.FOG_INDIGO), 8, 4)
	for y: int in range(0, TileBrush.SIZE, 8):
		b.rect(1, y + 1, 7, 3, TileBrush.param(p, "b", Palette.FOG_INDIGO))


## 広葉樹：丸い樹冠と幹。fruit で実、blossom で花
static func _tree(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.MOSS_DARK))
	var canopy: int = TileBrush.param(p, "canopy", Palette.FADED_GREEN)
	b.rect(2, 1, 12, 10, canopy)
	b.rect(1, 3, 14, 6, canopy)
	b.rect(4, 0, 8, 1, canopy)
	b.noise(TileBrush.param(p, "shade", Palette.MOSS_DARK), 0.18, 1, 0, 14, 11)
	b.rect(7, 10, 2, 5, TileBrush.param(p, "trunk", Palette.RUST_DARK))
	if p.has("fruit"):
		for i: int in 5:
			b.px(2 + i * 3, 2 + int(b.rand(i, 7) * 7.0), TileBrush.param(p, "fruit", Palette.RUST))
	if p.has("blossom"):
		b.noise(TileBrush.param(p, "blossom", Palette.BONE_WHITE), 0.3, 1, 0, 14, 11)


## 針葉樹：段になった三角形
static func _conifer(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.NIGHT_SKY))
	var leaf: int = TileBrush.param(p, "leaf", Palette.MOSS_DARK)
	for row: int in 4:
		var w: int = 4 + row * 3
		@warning_ignore("integer_division")
		b.rect(8 - w / 2, 1 + row * 3, w, 3, leaf)
	b.noise(TileBrush.param(p, "hi", Palette.FADED_GREEN), 0.1, 1, 1, 14, 12)
	b.rect(7, 13, 2, 3, Palette.RUST_DARK)


## 裸木：幹と枝だけ（冬の桜・梅）
static func _bare_tree(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.NIGHT_SKY))
	var wood: int = TileBrush.param(p, "wood", Palette.RUST_DARK)
	b.rect(7, 6, 2, 10, wood)
	b.vline(4, 2, 7, wood)
	b.vline(11, 1, 7, wood)
	b.hline(7, 4, 11, wood)
	b.px(3, 1, wood)
	b.px(12, 0, wood)
	if p.has("blossom"):
		b.noise(TileBrush.param(p, "blossom", Palette.BONE_WHITE), 0.25, 2, 0, 12, 8)


## 岩・落石：左上が明るく右下が暗い塊
static func _rock(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "ground", Palette.DUSK_INDIGO))
	var base: int = TileBrush.param(p, "base", Palette.FOG_INDIGO)
	b.rect(2, 4, 12, 9, base)
	b.rect(4, 2, 8, 2, base)
	b.rect(3, 3, 6, 3, TileBrush.param(p, "hi", Palette.CONCRETE))
	b.rect(6, 9, 8, 4, TileBrush.param(p, "shade", Palette.DEEP_INDIGO))
	b.hline(13, 2, 13, Palette.SUMI)


## 崖・岩壁：縦の暗い帯と割れ目
static func _cliff(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.DEEP_INDIGO))
	for x: int in range(0, TileBrush.SIZE, 5):
		b.rect(x, 0, 2, TileBrush.SIZE, TileBrush.param(p, "dark", Palette.NIGHT_SKY))
	for y: int in range(3, TileBrush.SIZE, 6):
		b.hline(y, int(b.rand(0, y) * 8.0), int(b.rand(1, y) * 8.0) + 8, Palette.SUMI)
	b.noise(TileBrush.param(p, "hi", Palette.FOG_INDIGO), 0.06)


## 斜面（土塁・法面・堤防）：斜線のハッチ
static func _slope(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "base", Palette.FADED_GREEN))
	b.diag(TileBrush.param(p, "line", Palette.MOSS_DARK), 4)
	if TileBrush.paramb(p, "concrete", false):
		b.fill(Palette.FOG_INDIGO)
		b.dots(Palette.CONCRETE, 4, 1, 1)
		b.diag(Palette.DUSK_INDIGO, 4)


## 空堀：中央が最も暗い
static func _moat(b: TileBrush, p: Dictionary) -> void:
	b.fill(TileBrush.param(p, "wall", Palette.RUST_DARK))
	b.rect(3, 3, 10, 10, TileBrush.param(p, "bottom", Palette.SUMI))
	b.noise(Palette.MOSS_DARK, 0.1)


## 石段：4px ごとの段。ハイライトと影
static func _stairs(b: TileBrush, p: Dictionary) -> void:
	var base: int = TileBrush.param(p, "base", Palette.CONCRETE)
	b.fill(base)
	for y: int in range(0, TileBrush.SIZE, 4):
		b.hline(y, 0, TileBrush.SIZE - 1, TileBrush.param(p, "hi", Palette.BONE_WHITE))
		b.hline(y + 3, 0, TileBrush.SIZE - 1, TileBrush.param(p, "shade", Palette.DUSK_INDIGO))
	if TileBrush.paramb(p, "broken", false):
		b.noise(Palette.SUMI, 0.15)
	if TileBrush.paramb(p, "rail", false):
		b.vline(0, 0, TileBrush.SIZE - 1, Palette.RUST_DARK)
		b.vline(TileBrush.SIZE - 1, 0, TileBrush.SIZE - 1, Palette.RUST_DARK)


## 古墳：草の盛土と石室の口
static func _mound(b: TileBrush, p: Dictionary) -> void:
	_grass(b, {"base": Palette.FADED_GREEN})
	b.rect(1, 6, 14, 10, Palette.FADED_GREEN_LIGHT)
	b.rect(3, 3, 10, 3, Palette.FADED_GREEN_LIGHT)
	b.hline(2, 5, 10, Palette.FADED_GREEN_LIGHT)
	if TileBrush.paramb(p, "opening", true):
		b.rect(6, 9, 4, 6, Palette.SUMI)
		b.frame(5, 8, 6, 8, Palette.FOG_INDIGO)


## 霧：半透明のオーバーレイ（唯一の非不透明タイル）
static func _fog(b: TileBrush, p: Dictionary) -> void:
	b.fill_alpha(TileBrush.param(p, "base", Palette.FOG_INDIGO), TileBrush.paramf(p, "alpha", 0.45))
	for y: int in TileBrush.SIZE:
		for x: int in TileBrush.SIZE:
			if b.rand(x, y) < 0.2:
				b.image.set_pixel(x, y, Palette.with_alpha(Palette.CONCRETE, 0.35))


## 裂け目：岩壁に縦の黒い亀裂
static func _crack(b: TileBrush, p: Dictionary) -> void:
	_cliff(b, p)
	var x: int = 6
	for y: int in TileBrush.SIZE:
		x = clampi(x + (1 if b.rand(x, y) > 0.66 else (-1 if b.rand(y, x) > 0.66 else 0)), 3, 11)
		b.rect(x, y, 2 + (1 if y > 5 and y < 11 else 0), 1, Palette.SUMI)


## 湧水：岩の中の小さな水たまり
static func _spring(b: TileBrush, p: Dictionary) -> void:
	_rock(b, {"ground": Palette.MOSS_DARK, "base": Palette.DUSK_INDIGO})
	b.rect(4, 6, 8, 6, Palette.DEEP_INDIGO)
	b.hline(8, 5, 9, Palette.FOG_INDIGO)
	b.px(7, 7, TileBrush.param(p, "glint", Palette.BONE_WHITE))
