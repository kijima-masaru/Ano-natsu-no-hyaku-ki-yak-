extends FieldBase
## F16 薬師谷。禁域。山中の廃寺（薬師堂）と、その奥（岩壁の裂け目）。全ての伏線の収束点。
## 音が完全に無くなる。恐怖は「何も起こらない」ことの持続で作る。
## 8/29 は入口（廃寺の前）までで、奥（裂け目）へは落石で進めない。入口に到達するたび、ナツが「まだ早い」と引き止める。
## 8/30 に落石が崩れ、堂の裏の「裂け目の口」が開く：人ひとり分ずれた封石と、面を戻す四つの台座（配置パズル。
## テキストと判定は data/events.json）。封石を戻す（seal_restored）と霧が引き、封石が元の位置へ戻る。
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
## 奥への道を塞ぐ落石。INNER_OPEN_DAY に崩れて通れるようになる
const INNER_ROCK_TILES: Array = [Vector2i(15, 15), Vector2i(16, 15), Vector2i(17, 15)]
const INNER_OPEN_DAY: int = 30
## 裂け目の口：ずれた封石と、戻した後の位置。四つの台座（東・南・西・北）
const SEAL_STONE_TILE: Vector2i = Vector2i(17, 9)
const SEAL_STONE_RESTORED_TILE: Vector2i = Vector2i(16, 9)
const PEDESTAL_E_TILE: Vector2i = Vector2i(18, 11)
const PEDESTAL_S_TILE: Vector2i = Vector2i(16, 13)
const PEDESTAL_W_TILE: Vector2i = Vector2i(14, 11)
const PEDESTAL_N_TILE: Vector2i = Vector2i(16, 10)
const SEAL_STONE_TYPE: String = "落石（岩）"
const PEDESTAL_TYPE: String = "苔むした石"
const SEAL_FLAG: String = "seal_restored"
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


func _enter_tree() -> void:
	super()
	if not GameState.flag_raised.is_connected(_on_flag_raised):
		GameState.flag_raised.connect(_on_flag_raised)


func _exit_tree() -> void:
	super()
	if GameState.flag_raised.is_connected(_on_flag_raised):
		GameState.flag_raised.disconnect(_on_flag_raised)


## 8/30 以降：落石が崩れて奥が開き、封石と台座が現れる
func _apply_day(day: int) -> void:
	if day < INNER_OPEN_DAY:
		return
	for tile: Vector2i in INNER_ROCK_TILES:
		objects.erase_cell(tile)
	for tile: Vector2i in [PEDESTAL_E_TILE, PEDESTAL_S_TILE, PEDESTAL_W_TILE, PEDESTAL_N_TILE]:
		set_tile(objects, tile, PEDESTAL_TYPE)
	_apply_seal_stone()
	add_point_of_interest("seal_stone", MessageResolver.text("ui_f16_seal_stone"), _seal_stone_tile())
	add_point_of_interest("pedestal_e", MessageResolver.text("ui_f16_pedestal_e"), PEDESTAL_E_TILE)
	add_point_of_interest("pedestal_s", MessageResolver.text("ui_f16_pedestal_s"), PEDESTAL_S_TILE)
	add_point_of_interest("pedestal_w", MessageResolver.text("ui_f16_pedestal_w"), PEDESTAL_W_TILE)
	add_point_of_interest("pedestal_n", MessageResolver.text("ui_f16_pedestal_n"), PEDESTAL_N_TILE)


func _seal_stone_tile() -> Vector2i:
	return SEAL_STONE_RESTORED_TILE if GameState.has_flag(SEAL_FLAG) else SEAL_STONE_TILE


## 封石はずれた位置か、戻した位置か
func _apply_seal_stone() -> void:
	objects.erase_cell(SEAL_STONE_TILE)
	objects.erase_cell(SEAL_STONE_RESTORED_TILE)
	set_tile(objects, _seal_stone_tile(), SEAL_STONE_TYPE)


## 封石を戻した：石が元の位置へ、霧が引く。調べ物の位置も追従させる
func _on_flag_raised(flag: String) -> void:
	if flag != SEAL_FLAG or Calendar.day < INNER_OPEN_DAY:
		return
	_apply_seal_stone()
	var stone: Interactable = get_interactable("seal_stone")
	if stone != null:
		stone.position = Vector2(_seal_stone_tile() * GameConstants.TILE_SIZE) + Vector2(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE) * 0.5
	_apply_time_of_day(Calendar.time_of_day)


## 霧：奥は常に。夜は堂の裏まで。封石を戻した後は晴れる
func _apply_time_of_day(time_of_day: String) -> void:
	var max_y: int = FOG_NIGHT_MAX_Y if time_of_day == Calendar.TIME_NIGHT else FOG_INNER_MAX_Y
	if GameState.has_flag(SEAL_FLAG):
		max_y = -1
	for y: int in MAP_ROWS.size():
		for x: int in MAP_ROWS[y].length():
			var ch: String = MAP_ROWS[y][x]
			if ch != "m" and ch != "X" and ch != "R":
				continue
			if y <= max_y:
				set_tile(overhead, Vector2i(x, y), FOG_TYPE)
			else:
				overhead.erase_cell(Vector2i(x, y))
