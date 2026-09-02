extends Node
## 16色固定パレット。ゲーム内の全描画はこの配列からのみ色を参照する。
##
## 順序と HEX 値は data/fields.json の meta.palette と同一に保つこと。
## このファイル以外で Color("#xxxxxx") を書くことは禁止（docs/CONVENTIONS.md §6）。
## 深い藍・墨・褪せた緑・錆色を基調とし、光源に当たる 4 色（12〜15）だけが彩度を持つ。

## パレットの色数。配列長のチェックに使う。
const SIZE: int = 16

## 唯一の色定義。インデックスは下の名前付き定数で参照する。
const COLORS: PackedColorArray = [
	Color("#0b0d14"),  # 0  墨：最暗部・影・輪郭
	Color("#141a2b"),  # 1  深藍・暗：夜の地面・高標高の基調
	Color("#1f2a44"),  # 2  深藍：中標高の基調・水面
	Color("#2f3f5f"),  # 3  宵藍：低標高の基調・アスファルト影
	Color("#4a5a78"),  # 4  霧藍：最低地の基調・コンクリート影
	Color("#8590a3"),  # 5  灰藍：コンクリート面・道路・月に照らされた面
	Color("#1b2a24"),  # 6  苔・暗：夜の樹木・田の影
	Color("#37533f"),  # 7  褪せた緑：草地・梅林・水田
	Color("#6b8a5e"),  # 8  褪せた緑・明：照らされた草・苔
	Color("#3a2a22"),  # 9  錆・暗：古木材・土の影・錆びた鉄
	Color("#7a4a2e"),  # 10 錆色：土・トタン・木造校舎の壁
	Color("#b08a5c"),  # 11 枯れ黄土：畳・紙・乾いた土・稲藁
	Color("#d9d2c0"),  # 12 骨白：月光・白線・障子・文字
	Color("#f2e9a8"),  # 13 街灯の黄：街灯・自販機・窓明かり（彩度あり）
	Color("#d84a3a"),  # 14 自販機の赤：自販機・非常灯（彩度あり）
	Color("#5fd0c8"),  # 15 蛍光灯の青白：蛍光灯・コンビニ・公衆電話（彩度あり）
]

# ── 名前付きインデックス（用途で選ぶ。番号を直接書かない） ──
const SUMI: int = 0                ## 墨。最暗部・影・輪郭・文字の縁
const NIGHT_SKY: int = 1           ## 深藍・暗。夜の地面、山頂・禁域の基調
const DEEP_INDIGO: int = 2         ## 深藍。中標高の地面、静かな水面
const DUSK_INDIGO: int = 3         ## 宵藍。低地の地面、アスファルトの影
const FOG_INDIGO: int = 4          ## 霧藍。最低地の地面、コンクリートの影、霧
const CONCRETE: int = 5            ## 灰藍。コンクリート面、道路、月に照らされた面
const MOSS_DARK: int = 6           ## 苔・暗。夜の樹木、田の影
const FADED_GREEN: int = 7         ## 褪せた緑。草地、梅林、水田
const FADED_GREEN_LIGHT: int = 8   ## 褪せた緑・明。照らされた草、苔
const RUST_DARK: int = 9           ## 錆・暗。古木材、土の影、錆びた鉄
const RUST: int = 10               ## 錆色。土、トタン、木造校舎の壁
const OCHRE: int = 11              ## 枯れ黄土。畳、紙、乾いた土、稲藁
const BONE_WHITE: int = 12         ## 骨白。月光、白線、障子、UI 文字
const STREETLAMP_GLOW: int = 13    ## 街灯の黄。街灯、自販機の白光、窓明かり
const VENDING_RED: int = 14        ## 自販機の赤。自販機、非常灯、交番の赤色灯
const FLUORESCENT: int = 15        ## 蛍光灯の青白。蛍光灯、コンビニ、公衆電話

## UI で使う既定色の別名
const UI_TEXT: int = BONE_WHITE
const UI_TEXT_DIM: int = CONCRETE
const UI_PANEL: int = NIGHT_SKY
const UI_BORDER: int = DUSK_INDIGO
const UI_ACCENT: int = STREETLAMP_GLOW
const UI_ALERT: int = VENDING_RED
const FADE_BLACK: int = SUMI

## 彩度を持つ「光源」のインデックス。発光表現はこの 4 色に限る。
const LIGHT_SOURCES: PackedInt32Array = [BONE_WHITE, STREETLAMP_GLOW, VENDING_RED, FLUORESCENT]

## デバッグ表示・ドキュメント用の短い名前（COLORS と同じ順序）
const NAMES: PackedStringArray = [
	"墨", "深藍・暗", "深藍", "宵藍", "霧藍", "灰藍",
	"苔・暗", "褪せた緑", "褪せた緑・明", "錆・暗", "錆色", "枯れ黄土",
	"骨白", "街灯の黄", "自販機の赤", "蛍光灯の青白",
]


func _ready() -> void:
	# 定義の整合性を起動時に一度だけ検証する。ずれていれば即座に分かるようにする。
	if COLORS.size() != SIZE or NAMES.size() != SIZE:
		push_error("Palette: COLORS/NAMES の要素数が %d ではありません（COLORS=%d, NAMES=%d）"
			% [SIZE, COLORS.size(), NAMES.size()])


## インデックスから色を返す。範囲外は push_error の上で墨（SUMI）を返す。
static func get_color(index: int) -> Color:
	if index < 0 or index >= COLORS.size():
		push_error("Palette: インデックス %d は範囲外です（0〜%d）" % [index, COLORS.size() - 1])
		return COLORS[SUMI]
	return COLORS[index]


## 透明度だけを変えた色を返す。フェードや霧のオーバーレイに使う。
static func with_alpha(index: int, alpha: float) -> Color:
	var color: Color = get_color(index)
	color.a = clampf(alpha, 0.0, 1.0)
	return color


## 光源色かどうか。発光・加算合成の対象を絞るときに使う。
static func is_light_source(index: int) -> bool:
	return LIGHT_SOURCES.has(index)


## 任意の色に最も近いパレットインデックスを返す。
## 将来、手描き PNG を取り込む際にパレット逸脱を検出する用途を想定。
static func closest_index(color: Color) -> int:
	var best_index: int = SUMI
	var best_distance: float = INF
	for i: int in COLORS.size():
		var c: Color = COLORS[i]
		var d: float = (c.r - color.r) ** 2 + (c.g - color.g) ** 2 + (c.b - color.b) ** 2
		if d < best_distance:
			best_distance = d
			best_index = i
	return best_index


## 色が 16 色のいずれかと厳密に一致するか（許容誤差 1/255）。
static func is_in_palette(color: Color) -> bool:
	var nearest: Color = COLORS[closest_index(color)]
	return absf(nearest.r - color.r) < 0.004 and absf(nearest.g - color.g) < 0.004 \
		and absf(nearest.b - color.b) < 0.004
