extends FieldBase
## F12 木平団地・支所前。主人公の自宅（C 棟 3 階）。就寝はここでのみ可能。
## 市営住宅 4 棟（A〜D）の階段室は各棟一箇所だけ点灯し、日を追うごとに点灯階が 3 階（自宅の階）へ揃っていく。
## 出口：N→F01 (8,0)、N→F05 (25,0)、E→F11 (39,14)、S→F13 (30,31)。環境音 amb_estate。

const GROUND_LEGEND: Dictionary = {
	",": "アスファルト",
	"-": "旧街道アスファルト（狭）",
	"a": "生活道路アスファルト（細）",
	"S": "公園の砂地",
	"g": "下草",
	"P": "駐車場ライン",
	"t": "歩道タイル",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "ブロック塀",
	"#": "団地 外壁（コンクリート・雨染み）",
	"V": "ベランダ",
	"x": "階段室（消灯）",
	"T": "支所の壁（タイル）",
	"G": "ガラス扉（点灯）",
	"B": "掲示板",
	"n": "案内板",
	"p": "植栽（低木）",
	"h": "生垣",
	"o": "集合ポスト",
	"E": "象の滑り台",
	"b": "ブランコ・砂場",
	"k": "ベンチ",
	"Q": "給水塔",
	"f": "フェンス（施錠）",
	"r": "駐輪場の屋根",
	"c": "自転車置き場",
	"N": "ゴミ集積所ネット",
	"L": "街灯（柱・光源）",
	"e": "電柱・電線",
	"C": "駐車車両（暗）",
}
## 物体タイルの下地を変える区画：[Rect2i, GROUND_LEGEND のキー]
const GROUND_ZONES: Array = [
	[Rect2i(27, 0, 13, 13), "t"],  # 支所周り
	[Rect2i(0, 0, 7, 9), "g"],     # 給水塔
	[Rect2i(0, 9, 7, 11), "S"],    # 公園
	[Rect2i(33, 23, 7, 9), "P"],   # 駐車場
]
const STAIRWELL_LIT: String = "階段室（点灯・消灯）"
const STAIRWELL_DARK: String = "階段室（消灯）"
const OFFICE_DOOR_TILE: Vector2i = Vector2i(32, 7)
const OFFICE_DOOR_CLOSED: String = "窓（消灯・点灯）"
## 各棟の階段室：列 x と 3 階→1 階の行 y（上から順）
const STAIRWELLS: Array = [
	{"x": 16, "rows": [3, 4, 5]},     # A 棟
	{"x": 16, "rows": [10, 11, 12]},  # B 棟
	{"x": 8, "rows": [25, 26, 27]},   # C 棟（自宅）
	{"x": 21, "rows": [25, 26, 27]},  # D 棟
]
## 日ごとの点灯階 [A, B, C, D]（1〜3）。表に無い日は最後の行（全棟 3 階＝自宅の階）
const LIT_FLOORS_BY_DAY: Array = [
	[1, 2, 3, 1],  # 8/1
	[1, 3, 3, 1],  # 8/2
	[3, 3, 3, 1],  # 8/3
	[3, 3, 3, 3],  # 8/4 以降
]
const TOP_FLOOR: int = 3
const WEEKDAY_SUNDAY: int = 0
const WEEKDAY_SATURDAY: int = 6
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "home_door", "name": "自宅（C 棟 3 階）", "tile": Vector2i(8, 27), "kind": "object"},
	{"id": "stairwell_c_notice", "name": "C 棟 階段室の掲示", "tile": Vector2i(9, 27), "kind": "sign"},
	{"id": "stairwell_a", "name": "A 棟 階段室", "tile": Vector2i(16, 5), "kind": "object"},
	{"id": "stairwell_b", "name": "B 棟 階段室", "tile": Vector2i(16, 12), "kind": "object"},
	{"id": "stairwell_d", "name": "D 棟 階段室", "tile": Vector2i(21, 27), "kind": "object"},
	{"id": "mailbox", "name": "集合ポスト", "tile": Vector2i(4, 28), "kind": "object"},
	{"id": "office_desk", "name": "支所の受付", "tile": Vector2i(32, 7), "kind": "object"},
	{"id": "office_board", "name": "支所の掲示板", "tile": Vector2i(36, 9), "kind": "sign"},
	{"id": "slide_inside", "name": "象の滑り台", "tile": Vector2i(3, 13), "kind": "object"},
	{"id": "tower_hatch", "name": "給水塔の点検扉", "tile": Vector2i(3, 5), "kind": "object"},
	{"id": "estate_board", "name": "団地の案内板", "tile": Vector2i(12, 17), "kind": "sign"},
	{"id": "bike_shed", "name": "駐輪場", "tile": Vector2i(19, 29), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "アスファルト"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwawwwwwwwwwwwwwwww-wwwwwwwwwwwwww",
	"wggggggaaa,,,,,,,,,,,,,,---ttttttttttttw",
	"wggggggaaa,VVVVVVVVVVVV,---pTTTTTTTTTTtw",
	"wgfffggaaa,#####x######,---tTTTTTTTTTTtw",
	"wgfQfggaaa,#####x######e---tTTTTTTTTTTtw",
	"wgfffggaaa,#####x######,---tTTTTTTTTTTtw",
	"wggggggaaa,,,,,,,,,,,,,,---pTTTTTTTTTTtw",
	"wggggggaaa,p,,,,,,,,,,p,---tTTTTGTTTTTtw",
	"wggggggaaa,,,,,,,,,,,,,,---ttttttttttttw",
	"whhhhhSaaa,VVVVVVVVVVVV,---tttttttttBttw",
	"wSSSSSSaaa,#####x######,---tLttttttttttw",
	"wkSSSSSaaa,#####x######L---ttttttttttttw",
	"wSSSSSSaaa,#####x######,---ttttttttttttw",
	"wSSESSSaaa,,,,,,,,,,,,,,---aaaaaaaaaaaaw",
	"wSSSSSSaaaL,,,,,,,,,,,,,---aaaaaaaaaaaaa",
	"wSSSSSSaaa,,,,,,,,NNN,,,---aaaaaaaaaaaaw",
	"wSSbSSSaaa,,,,,,,,,,,,,,---,,,,,,,,,,,,w",
	"wSSSSSSaaa,,n,,,,,,,,,,,---,e,,,,,,,,,,w",
	"wSSSSSSaaa,,,,,,,,,,,,,,---,,,p,,,,p,,,w",
	"whhhhhSaaap,,p,,,,,,p,,p---,,,,,,,,,,,,w",
	"w,,,,,,,,,,,,,,,,,,,,,,,,,,,,---,,,,,,,w",
	"w,,,,,,,,,,,,,,,,,,,,,,,,,,,,---,,,,,,,w",
	"w,,,,,,,,,,,,,,,,,,,,,,,,,,,,---,,,,,,,w",
	"w,,,,,,,,,,,,,,,,,,,,,,,,,,L,---,PPPPPew",
	"w,,VVVVVVVVVVVV,VVVVVVVVVVVV,---,PPPPPPw",
	"w,,#####x######,#####x######,---,PCPPPPw",
	"we,#####x######,#####x######,---,PPPPPPw",
	"w,,#####x######,#####x######,---,PPPPPPw",
	"w,,,o,,,,,,,,,,,,,,,,,,,,,,,,---,PPPPCPw",
	"w,,,,,,,,,,,,,,L,rrrrr,,,,,,,---,PPPPPPw",
	"w,,,,,,,,,,,,,,,,ccccc,,,,,,,---,PPPPPPw",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww-wwwwwwwww",
]


## 物体タイルの下地：支所周りは歩道タイル、給水塔と公園は下草・砂地、駐車場はライン、他はアスファルト
func _ground_under(x: int, y: int) -> String:
	for zone: Array in GROUND_ZONES:
		var rect: Rect2i = zone[0]
		if rect.has_point(Vector2i(x, y)):
			return GROUND_LEGEND[zone[1]]
	return ""


## 支所は平日の朝・昼だけ開いている（8/1 は土曜、8/2 は日曜）
func _apply_time_of_day(time_of_day: String) -> void:
	var weekday: int = Calendar.weekday_index()
	var weekend: bool = weekday == WEEKDAY_SUNDAY or weekday == WEEKDAY_SATURDAY
	var daytime: bool = time_of_day == Calendar.TIME_MORNING or time_of_day == Calendar.TIME_NOON
	set_tile(objects, OFFICE_DOOR_TILE, OBJECT_LEGEND["G"] if daytime and not weekend else OFFICE_DOOR_CLOSED)


## 階段室の点灯階を日付で差し替える。日を追うごとに全棟が 3 階（自宅の階）へ揃う
func _apply_day(day: int) -> void:
	var index: int = clampi(day - 1, 0, LIT_FLOORS_BY_DAY.size() - 1)
	var floors: Array = LIT_FLOORS_BY_DAY[index]
	for i: int in STAIRWELLS.size():
		var sw: Dictionary = STAIRWELLS[i]
		var rows: Array = sw["rows"]
		for f: int in rows.size():
			var floor_number: int = TOP_FLOOR - f
			set_tile(objects, Vector2i(int(sw["x"]), int(rows[f])), STAIRWELL_LIT if floor_number == int(floors[i]) else STAIRWELL_DARK)
	_apply_time_of_day(Calendar.time_of_day)
