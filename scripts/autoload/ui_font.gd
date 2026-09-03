extends Node
## UI フォント（PixelMplus12）を全 Control の既定フォントにする autoload。最初に読み込む。
## .import はコミットしないので、取り込み設定に頼らず読み込み時にアンチエイリアス無し・ヒンティング無し・
## サブピクセル無しを強制する（DialogueWindow が行っていたのと同じ処理。同じリソースを共有するので全体に効く）。
## ファイルが無ければ何もしない（各 UI は代替フォントで動く）。

const FONT_PATH: String = "res://resources/fonts/PixelMplus12-Regular.ttf"
const FONT_BOLD_PATH: String = "res://resources/fonts/PixelMplus12-Bold.ttf"

var font: FontFile = null
var font_bold: FontFile = null


func _ready() -> void:
	font = _load_pixel_font(FONT_PATH)
	font_bold = _load_pixel_font(FONT_BOLD_PATH)
	if font != null:
		ThemeDB.fallback_font = font
		var theme: Theme = ThemeDB.get_project_theme()
		if theme != null:
			theme.default_font = font


## ビットマップ風フォントとして読み込む。無ければ null
static func _load_pixel_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		return null
	var f: FontFile = load(path) as FontFile
	if f == null:
		push_error("UiFont: %s を FontFile として読み込めません" % path)
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f
