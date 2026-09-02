extends FieldBase
## F06 磐戸市民センター・交番前広場。最初の実フィールド。セーブ／情報ハブ。
## レイアウトは ASCII の地図（MAP_ROWS、40×32）と凡例から _build() で組み立てる。
## エディタで .tscn に焼き込むより差分レビューがしやすいため、ステップ2ではこの方式を採る。
## 出口タイルは data/fields.json の F06.exits と一致させている（W:0,13 N:10,0 N:27,0 S:5,31 S:30,31）。

const FIELD_ID: String = "F06"
const KEY_TUNNEL_FENCE: String = "key_tunnel_fence"
const FLAG_MAP_UNLOCKED: String = "flag_minimap_unlocked"

## 地面（通行可）の凡例
const GROUND_LEGEND: Dictionary = {
	".": "広場の敷石（インターロッキング）",
	",": "アスファルト",
	"-": "旧街道アスファルト（狭）",
	"S": "法面階段",
	"g": "側溝",
}
## Objects 層（通行不可）の凡例。地面は既定で広場の敷石
const OBJECT_LEGEND: Dictionary = {
	"w": "ブロック塀",
	"h": "生垣",
	"~": "法面コンクリート（格子）",
	"#": "公共建築の壁（タイル）",
	"G": "ガラス扉（点灯）",
	"=": "瓦屋根（連続）",
	"C": "時計塔",
	"B": "掲示板",
	"M": "看板（地図）",
	"T": "公衆電話ボックス",
	"b": "ベンチ",
	"p": "植栽（低木）",
	"c": "自転車置き場",
	"L": "街灯（柱・光源）",
	"e": "電柱・電線",
}
## Overhead 層（プレイヤーより手前）：[タイル座標, 種別]
const OVERHEAD_TILES: Array = [
	[Vector2i(20, 15), "時計塔"],
	[Vector2i(30, 5), "交番の赤色灯"],
]
## 調べ物：id, 表示名, タイル, 種類, 仮テキスト
const INTERACTABLES: Array = [
	{"id": "library", "name": "図書室", "tile": Vector2i(18, 10), "kind": "object",
		"text": "図書室の明かりだけが点いている。\n郷土資料の棚に『磐戸町史 下巻』が抜けた跡がある。"},
	{"id": "lost_and_found", "name": "遺失物箱", "tile": Vector2i(22, 10), "kind": "object",
		"text": "受付脇の遺失物箱。\n中には傘が三本と、番号札の付いた鍵が一つ。"},
	{"id": "police_log", "name": "交番", "tile": Vector2i(30, 10), "kind": "object",
		"text": "赤色灯は回っているが、中に人はいない。\n日誌は昨日の日付で止まっている。"},
	{"id": "bulletin", "name": "掲示板", "tile": Vector2i(14, 12), "kind": "sign",
		"text": "町内行事のお知らせと、尋ね人の紙が一枚。\n顔写真の部分だけが日に焼けて白い。"},
	{"id": "map_sign", "name": "町の地図", "tile": Vector2i(8, 15), "kind": "sign",
		"text": "磐戸町の全体図。西の国道から東の山まで。\n薬師谷のあたりだけ、誰かが塗り潰している。"},
	{"id": "phone", "name": "公衆電話", "tile": Vector2i(34, 12), "kind": "save_point",
		"text": "緑色の公衆電話。受話器を上げると発信音がする。\n（セーブ機能は未実装です）"},
	{"id": "clock", "name": "時計塔", "tile": Vector2i(20, 16), "kind": "object",
		"text": "広場の時計。針は 2 時 41 分で止まっている。\n秒針だけが、同じ場所で震え続けている。"},
]
## 40 列 × 32 行。行が y、列が x
const MAP_ROWS: PackedStringArray = [
	"wwwwwwwwww-wwwwwwwww~~~~~~~S~~~~~~~~~~~~",
	"whhhhhhhg--g========~~~~~~~S~~~~~~~~~~~~",
	"w=======g--ghhhhhhhhhhhhh~~S~~~~~~~~~~~~",
	"w=======g--g#############hhShhhhhhhhhhhh",
	"w=======e--g#############...===========w",
	"w=======g--g#############...===========w",
	"w=======g--g#############...#####======w",
	"w=======g--g#############...#####======w",
	"w=======e--g#############...#####======w",
	"w=======g--g#############...#####======w",
	"w=======g--g######G###G##...##G##======w",
	"wgggggg.............................===w",
	"w,L,,,,....L.pB...........p...L...T.===w",
	",,,,,,,.............................===w",
	"wgggggg.............................===w",
	"whhhhhh.M...........................===w",
	"w======.............C...............===w",
	"w======..........................p..===w",
	"w======.............................===w",
	"w======.....p...b.......b...p.......===w",
	"w======.............b............ccc===w",
	"w======....Lp...............p.L.....===w",
	"whhh=--.......................,,....===w",
	"whheg--ghhhhhhhhhhhhhhhhhhhhhw,,whhhehhw",
	"whhhg--g=====================w,,w======w",
	"whhhg-Lg=====================w,,w======w",
	"whhhg--g=====================w,Lw======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"whhhg--g=====================w,,w======w",
	"wwwww-wwwwwwwwwwwwwwwwwwwwwwww,wwwwwwwww",
]


func _build(def: FieldData) -> void:
	if def != null and def.size_tiles != Vector2i(MAP_ROWS[0].length(), MAP_ROWS.size()):
		push_error("F06: MAP_ROWS の寸法 %d×%d が fields.json の size_tiles %s と一致しません"
			% [MAP_ROWS[0].length(), MAP_ROWS.size(), def.size_tiles])
	_build_tiles()
	_build_interactables()


func _build_tiles() -> void:
	var default_ground: String = GROUND_LEGEND["."]
	for y: int in MAP_ROWS.size():
		var row: String = MAP_ROWS[y]
		for x: int in row.length():
			var ch: String = row[x]
			var tile: Vector2i = Vector2i(x, y)
			if GROUND_LEGEND.has(ch):
				set_tile(ground, tile, GROUND_LEGEND[ch])
			elif OBJECT_LEGEND.has(ch):
				set_tile(ground, tile, default_ground)
				set_tile(objects, tile, OBJECT_LEGEND[ch])
			else:
				push_error("F06: 凡例に無い文字 '%s'（%s）" % [ch, tile])
				set_tile(ground, tile, default_ground)
	for entry: Array in OVERHEAD_TILES:
		set_tile(overhead, entry[0], entry[1])


func _build_interactables() -> void:
	for data: Dictionary in INTERACTABLES:
		var node: Interactable = Interactable.create(
			str(data["id"]), str(data["name"]), str(data["text"]), data["tile"], Vector2i.ONE, str(data["kind"]))
		match node.interaction_id:
			"lost_and_found":
				node.interacted.connect(_on_lost_and_found)
			"map_sign":
				node.interacted.connect(_on_map_sign)
		add_interactable(node)


## 遺失物箱：初回に隧道フェンスの鍵を得る（中盤の F03→F09 解放）
func _on_lost_and_found(_by: Node, target: Interactable) -> void:
	if GameState.has_item(KEY_TUNNEL_FENCE):
		target.message = "遺失物箱。傘が三本残っている。\n鍵はもう、ここには無い。"
		return
	GameState.add_item(KEY_TUNNEL_FENCE)
	GameState.raise_flag(KEY_TUNNEL_FENCE)
	target.message = "遺失物箱の中に、番号札の付いた鍵があった。\n札には『高架下 3』とだけ書いてある。鍵を持ち帰った。"


## 町の地図看板：ミニマップ解放フラグ
func _on_map_sign(_by: Node, _target: Interactable) -> void:
	GameState.raise_flag(FLAG_MAP_UNLOCKED)
