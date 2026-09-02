class_name LightCatalog
extends RefCounted
## タイル種別名（TileCatalog と同じ日本語）→ そのタイルが放つ光。
## FieldBase.set_tile() が Objects / Overhead 層に置くたびに参照し、光源なら PointLight2D を同じタイルへ置く。
## 色は Palette.LIGHT_SOURCES の 4 色に限る（docs/CONVENTIONS.md §6）。radius はタイル数。

static var _entries: Dictionary = {}


static func entries() -> Dictionary:
	if _entries.is_empty():
		_entries = _build()
	return _entries


## 種別名が光源なら {color, radius, energy}、違えば空
static func get_light(type_name: String) -> Dictionary:
	var e: Dictionary = entries()
	if e.has(type_name):
		return e[type_name]
	var base: String = TileCatalog.normalize(type_name)
	return e.get(base, {})


static func _l(color: int, radius: float, energy: float = 0.8) -> Dictionary:
	if not Palette.is_light_source(color):
		push_error("LightCatalog: 光源色は Palette.LIGHT_SOURCES に限る（%d）" % color)
	return {"color": color, "radius": radius, "energy": energy}


static func _build() -> Dictionary:
	var e: Dictionary = {}
	e["街灯（柱・光源）"] = _l(Palette.STREETLAMP_GLOW, 3.5, 0.9)
	e["街灯（均等）"] = _l(Palette.STREETLAMP_GLOW, 3.5, 0.9)
	e["常夜灯"] = _l(Palette.STREETLAMP_GLOW, 2.0, 0.6)
	e["照明塔"] = _l(Palette.STREETLAMP_GLOW, 4.5, 1.0)
	e["時計塔"] = _l(Palette.STREETLAMP_GLOW, 1.5, 0.4)
	e["橋（桁・欄干・橋灯）"] = _l(Palette.STREETLAMP_GLOW, 1.5, 0.4)
	e["駄菓子屋の店先（点灯）"] = _l(Palette.STREETLAMP_GLOW, 2.0, 0.7)
	e["自販機正面"] = _l(Palette.STREETLAMP_GLOW, 2.5, 0.9)
	e["蛍光灯"] = _l(Palette.FLUORESCENT, 2.5, 0.8)
	e["蛍光灯（バス停）"] = _l(Palette.FLUORESCENT, 2.5, 0.8)
	e["店舗ガラス面（点灯）"] = _l(Palette.FLUORESCENT, 2.0, 0.7)
	e["ガラス扉（点灯）"] = _l(Palette.FLUORESCENT, 2.0, 0.7)
	e["階段室（点灯・消灯）"] = _l(Palette.FLUORESCENT, 1.5, 0.7)
	e["公衆電話ボックス"] = _l(Palette.FLUORESCENT, 1.5, 0.6)
	e["非常灯"] = _l(Palette.VENDING_RED, 1.5, 0.5)
	e["交番の赤色灯"] = _l(Palette.VENDING_RED, 2.0, 0.6)
	return e
