extends FieldBase
## F03 磐戸バスストップ・高架下。中盤ハブ。町の「裏側」（F04・F09）への唯一の出入口＝高架下の隧道。
## 高速は西側で高架（下を歩ける）、東側で盛土になり、法面コンクリートを隧道が貫く。北側へは隧道からしか行けない。
## 8/12 にここで追跡者と初遭遇し、悠だけが避けられる（不自然な幸運 1）。以後は夜に追跡者が出る。
## 出口：W→F02 (0,18)、S→F06 (8,27)、E→F04 (47,8)、E→F09 (47,26 施錠 key_tunnel_fence)。環境音 amb_underpass

const GROUND_LEGEND: Dictionary = {
	"g": "下草",
	"r": "農道の砂利",
	"d": "高架床版（影）",
	",": "アスファルト",
	"a": "生活道路アスファルト（細）",
	"s": "側溝",
	"/": "法面階段",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "樹林（暗）",
	"k": "樹林（暗）",
	"S": "防音壁",
	"P": "高架橋脚",
	"~": "法面コンクリート（格子）",
	"T": "隧道内壁（湿）",
	"G": "隧道内壁（湿）",
	"A": "隧道アーチ",
	"K": "時刻表看板",
	"F": "蛍光灯（バス停）",
	"b": "待合ベンチ",
	"V": "自販機正面",
	"f": "フェンス（施錠）",
	"n": "案内板",
	"e": "電柱・電線",
	"L": "街灯（柱・光源）",
}
## 物体タイルの下地を変える区画：[Rect2i, GROUND_LEGEND のキー]
const GROUND_ZONES: Array = [
	[Rect2i(0, 11, 48, 7), "d"],   # 高架・盛土・隧道
	[Rect2i(0, 18, 48, 4), ","],   # 生活道路と車寄せ
	[Rect2i(29, 22, 19, 6), "r"],  # 法面下の砂利道
]
## 8/12 に追跡者が現れる位置（隧道の北口の内側）と、捕まったときに戻される先
const STALKER_SPAWN_TILE: Vector2i = Vector2i(37, 12)
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "timetable", "name": "時刻表", "tile": Vector2i(10, 20), "kind": "sign"},
	{"id": "bench_item", "name": "待合ベンチ", "tile": Vector2i(13, 21), "kind": "object"},
	{"id": "vending_broken", "name": "自販機（故障）", "tile": Vector2i(15, 20), "kind": "object"},
	{"id": "graffiti", "name": "隧道の落書き", "tile": Vector2i(35, 14), "kind": "object"},
	{"id": "fence_notice", "name": "施錠フェンスの掲示", "tile": Vector2i(46, 25), "kind": "sign"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "下草"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkkw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkgggggggggggggggggw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkgggggggggggggggggw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkggggggggggeggggggw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkrrrrrrrrrrrrrrrrrw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkrrrrrrrrrrrrrrrrrr",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkrrrrrrrrrrrrrrrrrw",
	"wkkkkkkkkkkkkkkkkkkkkkkkkkkkkkgggggrrrrggggggggw",
	"wSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSAddASSSSSSSSw",
	"wddddddddddddddddddddddddddddd~~~~~TddT~~~~~~~~w",
	"wdddPdddddPdddddPdddddPdddddPd~~~~~TddT~~~~~~~~w",
	"wddddddddddddddddddddddddddddd~~~~~GddT~~~~~~~~w",
	"wdddPdddddPdddddPdddddPdddddPd~~~~~TddT~~~~~~~~w",
	"wddddddddddddddddddddddddddddd~~~~~TddT~~~~~~~~w",
	"wggeggggggggggggggggLggggggegg~~~~~AddA~~~~~~~~w",
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaw",
	"waaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaw",
	"w,,,,,,,,,K,F,,V,,,,,,,,,,,,,,~~~~~~~~~~~~~~~~~w",
	"w,,,,,,,,,,b,b,,,,,,,,,,,,,,,,~~~~~~~~~~~~~~~~~w",
	"wsssssss/sssssssssssssssssssss~~~~~~~~~~~~~~~~~w",
	"w~~~~~~~/~~~~~~~~~~~~~~~~~~~~rrrrrrrrrrrrrrrrrfw",
	"w~~~~~~~/~~~~~~~~~~~~~~~~~~~~rrrrrrrrrrrrrrrrrfw",
	"w~~~~~~~/~~~~~~~~~~~~~~~~~~~~rrrrrrrrrrrrrrrrrnw",
	"w~~~~~~~/~~~~~~~~~~~~~~~~~~~~rrrrrrrrrrrrrrrrrrr",
	"wwwwwwww/wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


func _ground_under(x: int, y: int) -> String:
	for zone: Array in GROUND_ZONES:
		var rect: Rect2i = zone[0]
		if rect.has_point(Vector2i(x, y)):
			return GROUND_LEGEND[zone[1]]
	return ""
