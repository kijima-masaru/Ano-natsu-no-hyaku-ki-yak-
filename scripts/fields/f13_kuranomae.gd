extends FieldBase
## F13 倉ノ前ニュータウン。1980 年代の区画整理地。同じ形の家が整然と並ぶ反復の不安。
## 「同じ家」の中で一軒だけ違う家（瓦の建売）を見つける。袋小路を戻ると家が一軒増えている（表札は空欄）。
## タイルは F12（団地）と共有し、住宅は「同型住宅の壁・屋根（3色差分）」の反復で作る。
## 出口：N→F12 (12,0)、N→F11 (36,0)、E→F10 (47,14)、S→F15 (6,31)。環境音 amb_newtown

const GROUND_LEGEND: Dictionary = {
	"-": "区画道路アスファルト",
	"|": "白線（停止線）",
	"v": "売地の草",
	"g": "側溝",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "生垣",
	"=": "同型住宅の壁・屋根（3色差分）",
	"Q": "建売住宅の壁・屋根（瓦）",
	"C": "カーポート",
	"M": "門扉",
	"L": "街灯（均等）",
	"m": "記念碑",
	"N": "ゴミ集積所ネット",
	"K": "店舗看板（無地）",
	"p": "調整池（水面・柵）",
	"f": "フェンス（施錠）",
}
## 袋小路を戻ると増えている一軒（フラグ f13_extra_house で現れる）。表札は空欄
const EXTRA_HOUSE_FLAG: String = "f13_extra_house"
const EXTRA_HOUSE_TILES: Array = [
	[Vector2i(29, 29), "="], [Vector2i(30, 29), "="], [Vector2i(31, 29), "="],
	[Vector2i(29, 30), "="], [Vector2i(30, 30), "="], [Vector2i(31, 30), "="],
	[Vector2i(30, 28), "M"],
]
const EXTRA_NAMEPLATE_ID: String = "extra_nameplate"
const EXTRA_NAMEPLATE_TILE: Vector2i = Vector2i(30, 28)
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "monument", "name": "区画整理記念碑", "tile": Vector2i(9, 10), "kind": "sign"},
	{"id": "nameplate_a", "name": "表札", "tile": Vector2i(3, 6), "kind": "sign"},
	{"id": "nameplate_b", "name": "表札", "tile": Vector2i(16, 6), "kind": "sign"},
	{"id": "nameplate_c", "name": "表札", "tile": Vector2i(21, 6), "kind": "sign"},
	{"id": "odd_house", "name": "瓦屋根の家", "tile": Vector2i(26, 11), "kind": "object"},
	{"id": "sale_sign", "name": "売地の看板", "tile": Vector2i(41, 17), "kind": "sign"},
	{"id": "pond_fence", "name": "調整池の柵", "tile": Vector2i(38, 25), "kind": "object"},
	{"id": "deadend_window", "name": "袋小路の奥の家", "tile": Vector2i(31, 26), "kind": "object"},
	{"id": "trash_station", "name": "ゴミステーション", "tile": Vector2i(14, 10), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "売地の草"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwww-wwwwwwwwwwwwwwwwwwwwwww-wwwwwwwwwww",
	"wvvvvvvvvvv---vvvvvvvvvvvvvvvvvvvvv---vvvvvvvvvw",
	"wvvvvvvvvvv---vvvvvvvvvvvvvvvvvvvvv---vvvvvvvvvw",
	"wvvvvvvvvvv---vvvvvvvvvvvvvvvvvvvvv---vvvvvvvvvw",
	"wv===Cvvvvv---v===Cv===Cv===Cv===Cv---v===Cvvvvw",
	"wv===Cvvvvv---v===Cv===Cv===Cv===Cv---v===Cvvvvw",
	"wvvMvvvvvvv---vvMvvvvMvvvvMvvvvMvvv---vvMvvvvvvw",
	"wgggggggggg-|-LvvvvvvvvvvvvvvvvvvvL-|-Lvvvvvvvvw",
	"w----------------------------------------------w",
	"w----------------------------------------------w",
	"wvvvvvvvvmv-|-Ngggggggggggggggggggv-|-vvvvvvvvvw",
	"wvvMvvvvvvv---NvMvvvvMvvvvMvvvvMvvv---vvMvvvvvvw",
	"wv===Cvvvvv---v===Cv===CvQQQCv===Cv---L===Cvvvvw",
	"wv===Cvvvvv---v===Cv===CvQQQCv===Cv----===C----w",
	"wvvvvvvvvvv---vvvvvvvvvvvvvvvvvvvvv-------------",
	"wvvvvvvvvvv---vvvvvvvvvvvvvvvvvvvvv------------w",
	"wvvvvvvvvvv---v===Cv===Cv===Cv===Cv---vvvvvvvvvw",
	"wvvvvvvvvvv---v===Cv===Cv===Cv===Cv---vvvKvvvvvw",
	"wvvvvvvvvvv---vvMvvvvMvvvvMvvvvMvvv---vvvvvvvvvw",
	"wvvvvvvvvvv-|-vvvvvvvvvvvvvvvvvvvvv-|-vvvvvvvvvw",
	"wvvv-------------------------------------------w",
	"wvvv-------------------------------------------w",
	"wvvvv-|-vvL-|-vvMvvvvMvvvvMvvvvvvvvvvvLvvvvvvvvw",
	"wvvvv---vvv---v===Cv===Cv===Cvvvvvvvvvvppppppppw",
	"wvvvv---vvv---v===Cv===Cv===Cvvvvvvvvvvppppppppw",
	"wvvvv---vvv---vvvvvvvvvvvvvvvLv===vvvvfppppppppw",
	"wvvvL---vvv--------------------M==vvvvfppppppppw",
	"wvvvv---vvv--------------------===vvvvvppppppppw",
	"wvvvv---vvv---vvMvvvvMvvvvMvvvv===vvvvvppppppppw",
	"wvvvv---vvv---v===Cv===Cv===Cvvvvvvvvvvppppppppw",
	"wvvvv---vvvvvvv===Cv===Cv===Cvvvvvvvvvvppppppppw",
	"wwwwww-wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
]


func _ready() -> void:
	super()
	if not GameState.flag_raised.is_connected(_on_flag_raised):
		GameState.flag_raised.connect(_on_flag_raised)


## 街灯の下地だけ道路
func _ground_under(x: int, y: int) -> String:
	var ch: String = MAP_ROWS[y][x]
	return GROUND_LEGEND["-"] if ch == "L" or ch == "|" else ""


func _apply_day(_day: int) -> void:
	_update_extra_house()


func _on_flag_raised(flag: String) -> void:
	if flag == EXTRA_HOUSE_FLAG:
		_update_extra_house()


## 増えた一軒は一度現れたら消えない
func _update_extra_house() -> void:
	if not GameState.has_flag(EXTRA_HOUSE_FLAG):
		return
	for entry: Array in EXTRA_HOUSE_TILES:
		set_tile(objects, entry[0], OBJECT_LEGEND[entry[1]])
	if get_interactable(EXTRA_NAMEPLATE_ID) == null:
		add_point_of_interest(EXTRA_NAMEPLATE_ID, MessageResolver.text("ui_f13_extra_nameplate"), EXTRA_NAMEPLATE_TILE, "sign")
