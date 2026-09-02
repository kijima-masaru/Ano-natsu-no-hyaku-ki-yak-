extends FieldBase
## F04 八柱の谷戸。柿と栗の畑、放棄された農機具小屋、獣道、切れた電気柵、八本の古い石柱の跡。
## 最も人里から遠く、追跡者の主要な狩場。獣道を辿ると、必ず同じ小屋の裏に出る（怪異）。小屋の電球は誰も点けていない。
## 農機具小屋の日誌が隠蔽 C-07（六月の頁）と証拠 seal_lore（『石が動いた』）の両方を持つ。
## 出口：W→F03 (0,7) のみ。F09 へは崖で行けない。環境音 amb_orchard

const GROUND_LEGEND: Dictionary = {
	"g": "下草",
	"r": "農道の砂利",
	"f": "畑の土（畝）",
	"u": "獣道（踏み分け）",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "谷の斜面（暗い樹林）",
	"V": "谷の斜面（暗い樹林）",
	"K": "柿の木（実あり）",
	"N": "栗の木",
	"S": "農機具小屋（トタン・板）",
	"D": "店舗の木製戸",
	"W": "窓（消灯・点灯）",
	"E": "電気柵ポール",
	"b": "百葉箱",
	"q": "石柱",
	"R": "落石（岩）",
	"n": "案内板",
}
## 小屋の電球：8/13 以降の夜、誰も点けていないのに点く
const SHED_WINDOW: Vector2i = Vector2i(30, 13)
const WINDOW_LIT: String = "階段室（点灯・消灯）"
const BULB_FIRST_DAY: int = 13
## 追跡者が現れる位置（栗林の奥）と押し戻し先
const STALKER_SPAWN_TILE: Vector2i = Vector2i(34, 3)
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "shed_door", "name": "農機具小屋", "tile": Vector2i(28, 15), "kind": "object"},
	{"id": "battery", "name": "電気柵のバッテリー", "tile": Vector2i(24, 10), "kind": "object"},
	{"id": "cloth_tree", "name": "柿の木", "tile": Vector2i(14, 15), "kind": "object"},
	{"id": "footprints", "name": "獣の足跡", "tile": Vector2i(36, 12), "kind": "object"},
	{"id": "pillar", "name": "石柱の刻字", "tile": Vector2i(39, 20), "kind": "sign"},
	{"id": "trail_sign", "name": "獣道の行き止まり", "tile": Vector2i(41, 26), "kind": "sign"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "下草"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wgggggggggggggggggggggggggggggggggggggggggggVVVw",
	"wgggggggggggggggggggggggggNggNggNggNggNggNggVVVw",
	"wgggggggggggggggggggggggggggggggggggggggggggVVVw",
	"wgggggggggggggggggggggggggNggNggNggNggNggNggVVVw",
	"wgggggggggggggggggggggggggggggggggggggggggggVVVw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrgggggggggggggggggggVVVw",
	"rrrrrrrrrrrrrrrrrrrrrrrrrgggggggggggggggggggVVVw",
	"wrrrrrrrrrrrrrrrrrrrrrrrrgggggggggggggggggggVVVw",
	"wggggggggggggggggggggggggggguuuuuuuuuuuuugggVVVw",
	"wgggggggggggggggggggggggbgggugggggggggggugggVVVw",
	"wgggfffffffffffffffffffgEgSSSSSgggggggggugggVVVw",
	"wgggffKfffKfffKfffKffffgggSSSSSgggggRgggugggVVVw",
	"wgggfffffffffffffffffffgggSSSSWgggggggggugggVVVw",
	"wgggfffffffffffffffffffgEgSSSSSggqggggggugggVVVw",
	"wgggffKfffKfffKfffKffffgggggDgggggggggggugggVVVw",
	"wgggfffffffffffffffffffggggggggggggqggggugggVVVw",
	"wgggfffffffffffffffffffgEgggggggggggggggugggVVVw",
	"wgggffKfffKfffKfffKffffggggggggggggggqggugggVVVw",
	"wgggfffffffffffffffffffgggggggggggggggggugggVVVw",
	"wgggfffffffffffffffffffgEggggggggggggggqugggVVVw",
	"wgggffKfffKfffKfffKffffgggggggggggggggggugggVVVw",
	"wgggfffffffffffffffffffggggggggggggggqggugggVVVw",
	"wgggggggggggggggggggggggggggggggggggggggugggVVVw",
	"wggggggggggggggggggggggggggggggggguuuuuuugggVVVw",
	"wgggggggggggggggggggggggggggggggggggggggugggVVVw",
	"wggggggggggggggggggggggggggggggqgggqggggunggVVVw",
	"wggggggggggggggggggggggggggggggggqggggggggggVVVw",
	"wgggggggggggggggggggggggggggggggggggggggggggVVVw",
	"wVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVw",
	"wVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVw",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


## 柿の木の下地は畝、看板は獣道
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch == "K":
		return GROUND_LEGEND["f"]
	if ch == "n":
		return GROUND_LEGEND["u"]
	return ""


## 8/13 以降の夜、小屋の電球が点く
func _apply_time_of_day(time_of_day: String) -> void:
	var night: bool = time_of_day == Calendar.TIME_NIGHT
	var lit: bool = night and Calendar.day >= BULB_FIRST_DAY
	set_tile(objects, SHED_WINDOW, WINDOW_LIT if lit else OBJECT_LEGEND["W"])


func _apply_day(_day: int) -> void:
	_apply_time_of_day(Calendar.time_of_day)
