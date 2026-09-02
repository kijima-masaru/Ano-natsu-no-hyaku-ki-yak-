extends FieldBase
## F16 薬師谷。禁域。山中の廃寺（薬師堂）と、その奥（岩壁の裂け目）。全ての伏線の収束点。
## 音が完全に無くなる。恐怖は「何も起こらない」ことの持続で作る。
## 今回は入口（廃寺の前）までは到達でき、奥（裂け目）へは落石で進めない。奥の領域（8/30 の舞台）は
## 器と接続だけを用意し、中身は空にしておく（Step 5）。入口に到達するたび、ナツが「まだ早い」と引き止める。
## 出口：S→F14 (18,47 施錠 flag_yakushi_open)。環境音 amb_valley

const GROUND_LEGEND: Dictionary = {
	"r": "林道の砂利",
	"S": "崩れた石段",
	"m": "苔",
}
const OBJECT_LEGEND: Dictionary = {
	"w": "谷の岩壁",
	"C": "谷の岩壁",
	"k": "杉林（暗）",
	"T": "廃寺の壁・屋根（崩落）",
	"Z": "厨子",
	"M": "積まれた面",
	"Q": "湧水（水面・小）",
	"R": "落石（岩）",
	"u": "苔むした石",
	"X": "裂け目（暗）",
}
const FOG_TYPE: String = "霧（半透明オーバーレイ）"
## 奥（裂け目側）は常に霧。夜は堂の裏まで降りてくる
const FOG_INNER_MAX_Y: int = 12
const FOG_NIGHT_MAX_Y: int = 17
## 奥への道を塞ぐ落石（Step 5 で開く）
const INNER_ROCK_TILES: Array = [Vector2i(15, 15), Vector2i(16, 15), Vector2i(17, 15)]
## 調べ物。テキストとフラグ操作は data/events.json（on_interact, target=id）
const INTERACTABLES: Array = [
	{"id": "zushi", "name": "薬師堂の厨子", "tile": Vector2i(16, 25), "kind": "object"},
	{"id": "masks", "name": "積まれた面", "tile": Vector2i(23, 24), "kind": "object"},
	{"id": "spring", "name": "湧水", "tile": Vector2i(8, 27), "kind": "object"},
	{"id": "rockfall", "name": "落石の跡", "tile": Vector2i(24, 30), "kind": "object"},
	{"id": "salt_spot", "name": "堂の前の石", "tile": Vector2i(19, 27), "kind": "object"},
	{"id": "inner_gate", "name": "堂の裏の落石", "tile": Vector2i(16, 15), "kind": "object"},
]
## 物体タイルの下地
const DEFAULT_GROUND: String = "苔"
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCCXCCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCmmmmmCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCmmmmmCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCmmmmmCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCmmmmmCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCmmmCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCmmmCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCRRRCCCCCCCCCCCCCw",
	"wCCCCCCCCCCCCCCmmmCCCCCCCCCCCCCw",
	"wCCCkkkkkkkkkkkmmmkkkkkkkkkkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmmmmmkCCCw",
	"wCCCkkmmmmmmTTTTTTTTTmmMmmmkCCCw",
	"wCCCkkmmmmmmmmmmZmmmmmmmmmmkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmmmmkCCCw",
	"wCCCkkmmQmmmmmmmmmmummmmmmmkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmmmmkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmmmmkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmRmmkCCCw",
	"wCCCkkmmmmmmmmmmmmmmmmmmmmmkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkSSSkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wCCCkkkkkkkkkkkkkrrrkkkkkkkkCCCw",
	"wwwwwwwwwwwwwwwwwwrwwwwwwwwwwwww",
]


## 岩壁と杉林の下地も苔（谷全体が苔むしている）
func _ground_under(_x: int, _y: int) -> String:
	return ""


## 霧：奥は常に。夜は堂の裏まで
func _apply_time_of_day(time_of_day: String) -> void:
	var max_y: int = FOG_NIGHT_MAX_Y if time_of_day == Calendar.TIME_NIGHT else FOG_INNER_MAX_Y
	for y: int in MAP_ROWS.size():
		for x: int in MAP_ROWS[y].length():
			var ch: String = MAP_ROWS[y][x]
			if ch != "m" and ch != "X" and ch != "R":
				continue
			if y <= max_y:
				set_tile(overhead, Vector2i(x, y), FOG_TYPE)
			else:
				overhead.erase_cell(Vector2i(x, y))
