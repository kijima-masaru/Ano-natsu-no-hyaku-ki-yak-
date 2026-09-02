extends FieldBase
## F14 朝和の里。水田、千年以上の由緒を持つ式内社、古墳群（円墳 3 基）、用水路、火の見櫓、朝和シゲの家。
## 町で最も古い信仰の層。昼は牧歌的、夜は完全な闇。本作の怪異の由来に関わる文献証拠（式内社の由緒）を置く。
## 8/14 老婆シゲの激昂（baba_rage）。8/28 夕に林道の落石が崩れ、F16 薬師谷が開く（flag_yakushi_open）。
## 出口：W→F11 (0,18)、S→F10 (19,35)、N→F16 (44,0 施錠 flag_yakushi_open・落石)。環境音 amb_paddy（夜は _night）

const GROUND_LEGEND: Dictionary = {
	"a": "畦道",
	"g": "境内の砂利",
	"d": "下草",
	"r": "林道の砂利",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "杉林",
	"p": "水田（水面・稲）",
	"c": "用水路（水面・コンクリート）",
	"G": "用水路（水面・コンクリート）",
	"H": "式内社の社殿・鳥居",
	"T": "鳥居",
	"L": "常夜灯",
	"n": "案内板",
	"N": "案内板",
	"K": "古墳（盛土・石室口）",
	"s": "古墳（盛土・石室口）",
	"F": "農家の壁・瓦",
	"D": "店舗の木製戸",
	"W": "窓（消灯・点灯）",
	"Y": "火の見櫓",
	"q": "石柱",
	"R": "落石（岩）",
}
## 林道を塞ぐ落石（flag_yakushi_open で崩れて通れる）
const ROCK_TILES: Array = [Vector2i(44, 5), Vector2i(44, 6), Vector2i(43, 6), Vector2i(45, 5)]
const ROCK_OPEN_FLAG: String = "flag_yakushi_open"
## シゲの家の窓（夜は灯る）とシゲの立ち位置（庭）
const HOUSE_WINDOWS: Array = [Vector2i(5, 24), Vector2i(9, 24)]
const WINDOW_LIT: String = "階段室（点灯・消灯）"
const SHIGE_TILE: Vector2i = Vector2i(8, 26)
const SHIGE_FIRST_DAY: int = 14
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "shrine_board", "name": "式内社の由緒書き", "tile": Vector2i(21, 3), "kind": "sign"},
	{"id": "visitor_book", "name": "奉納帳", "tile": Vector2i(26, 6), "kind": "object"},
	{"id": "kofun", "name": "古墳の石室入口", "tile": Vector2i(43, 13), "kind": "object"},
	{"id": "sluice", "name": "水路の水門", "tile": Vector2i(30, 8), "kind": "object"},
	{"id": "tower_bell", "name": "火の見櫓", "tile": Vector2i(13, 28), "kind": "object"},
	{"id": "rock_sign", "name": "落石の看板", "tile": Vector2i(42, 8), "kind": "sign"},
	{"id": "offering", "name": "畦の供え物", "tile": Vector2i(30, 26), "kind": "object"},
	{"id": "shige_door", "name": "朝和家", "tile": Vector2i(7, 25), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "畦道"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwrwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwwwwwgwwwwwwwwwwwwwwwwwrwwwwwwwwwww",
	"wpppppppppppapppppppggggHHHHHggggpppapppppprrrpppppppwww",
	"wpppppppppppapppppppgnggHHHHHggggpppapppppprrrpppppppwww",
	"wpppppppppppapppppppggggHHHHHggggpppapppppprrrpppppppwww",
	"wpppppppppppapppppppggLgggggggLggpppapppppprRRpppppppwww",
	"wpppppppppppapppppppggggggTggggggpppappppppRRrpppppppwww",
	"wpppppppppppapppppppgggggggggggggpppapppppprrrpppppppwww",
	"wcccccccccccacccccccccccacccccGcccccacccccNrrrcccccccwww",
	"waaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaawww",
	"wpppppppppppapppppppppppapppppppppppapdddddddddddddddwww",
	"wpppppppppppapppppppppppapppppppppppapddddKKKddddddddwww",
	"wpppppppppppapppppppppppapppppppppppapddddKKKddddddddwww",
	"wpppppppppppapppppppppppapppppppppppapdddddsdddddddddwww",
	"wpppppppppppapppppppppppapppppppppppapddddddddddKKKddwww",
	"wpppppppppppapppppppppppapppppppppppapddddddddddKKKddwww",
	"wpppppppppppapppppppppppapppppppppppapdddddddddddddddwww",
	"waaaaaaaaaaaapppppppppppapppppppppppapdddddddddddddddwww",
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaadddddddddddddddwww",
	"waaaaaaaaaaaapppppppppppapppppppppppapdddddddddddddddwww",
	"wpppppppppppapppppppppppapppppppppppapdddddddddddddddwww",
	"wpppFFFFFFFpapppppppppppapppppppppppapddddddKKKddddddwww",
	"wpppFFFFFFFpapppppppppppapppppppppppapddddddKKKddddddwww",
	"wpppFFFFFFFpapppppppppppapppppppppppapdddddddddddddddwww",
	"wpppFWFFFWFpapppppppppppapppppppppppapdddddddddddddddwww",
	"wppddddDddddapppppppppppapppppppppppappppppppppppppppwww",
	"wppdddddddddapppppppppppapppppqpppppappppppppppppppppwww",
	"waaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaawww",
	"wpppppppppppaYpppppappppapppppppppppappppppppppppppppwww",
	"wpppppppppppappppppappppapppppppppppappppppppppppppppwww",
	"wpppppppppppappppppappppapppppppppppappppppppppppppppwww",
	"wpppppppppppappppppappppapppppppppppappppppppppppppppwww",
	"wpppppppppppappppppappppapppppppppppappppppppppppppppwww",
	"wpppppppppppappppppappppapppppppppppappppppppppppppppwww",
	"wwwwwwwwwwwwwwwwwwwawwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwawwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


func _ready() -> void:
	super()
	if not GameState.flag_raised.is_connected(_on_flag_raised):
		GameState.flag_raised.connect(_on_flag_raised)


## 社殿・鳥居・常夜灯の下地は砂利、農家と窓と戸は下草、落石は林道、他は畦道
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	if ch in ["H", "T", "L", "n"]:
		return GROUND_LEGEND["g"]
	if ch in ["F", "D", "W", "Y"]:
		return GROUND_LEGEND["d"]
	if ch == "R" or ch == "N":
		return GROUND_LEGEND["r"]
	return ""


## 夜はシゲの家の窓が灯る。シゲは 8/14 以降の昼に庭にいる
func _apply_time_of_day(time_of_day: String) -> void:
	var night: bool = time_of_day == Calendar.TIME_NIGHT or time_of_day == Calendar.TIME_EVENING
	for tile: Vector2i in HOUSE_WINDOWS:
		set_tile(objects, tile, WINDOW_LIT if night else OBJECT_LEGEND["W"])
	_update_shige(not night)


func _apply_day(_day: int) -> void:
	_update_rocks()
	_apply_time_of_day(Calendar.time_of_day)


func _on_flag_raised(flag: String) -> void:
	if flag == ROCK_OPEN_FLAG:
		_update_rocks()


func _update_shige(daytime: bool) -> void:
	set_npc_present("shige_npc", daytime and Calendar.day >= SHIGE_FIRST_DAY, SHIGE_TILE, "toki", Vector2i.DOWN)


## 落石が崩れたら林道が通れる
func _update_rocks() -> void:
	if not GameState.has_flag(ROCK_OPEN_FLAG):
		return
	for tile: Vector2i in ROCK_TILES:
		objects.erase_cell(tile)
		set_tile(ground, tile, GROUND_LEGEND["r"])
