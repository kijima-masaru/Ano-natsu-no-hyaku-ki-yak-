class_name TextLayout
extends RefCounted
## 日本語の禁則処理付き行分割。等幅ビットマップフォント（PixelMplus12）前提で文字数ベースに折り返す。
## - 行頭禁則：句読点・閉じ括弧・長音・小書き文字などを行頭に置かない（前行末にぶら下げる）
## - 行末禁則：開き括弧を行末に置かない（次行へ送る）
## - 分離禁止：「……」「――」「!?」などの連続を分けない

## 行頭に置けない文字
const NO_LINE_START: String = "、。，．・：；？！‼⁇⁈⁉ゝゞヽヾーァィゥェォッャュョヮヵヶぁぃぅぇぉっゃゅょゎ々）］｝〕〉》」』】〙〗〟’”»〜～…‥"
## 行末に置けない文字
const NO_LINE_END: String = "（［｛〔〈《「『【〘〖〝‘“«"
## 前後で分けない文字対
const INSEPARABLE: PackedStringArray = ["……", "――", "!?", "！？", "‥‥"]
## ぶら下げで許す最大文字数
const MAX_HANG: int = 2


## 1 段落を max_chars 文字で折り返す（禁則適用）。改行は含めない
static func wrap_line(text: String, max_chars: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var rest: String = text
	while rest.length() > max_chars:
		var cut: int = max_chars
		# 分離禁止：切断位置が対の途中なら手前で切る
		for pair: String in INSEPARABLE:
			if cut >= 1 and rest.substr(cut - 1, pair.length()) == pair:
				cut -= 1
		# 行頭禁則：次行の先頭が禁則文字なら前行末へぶら下げる（最大 MAX_HANG）
		var hang: int = 0
		while cut < rest.length() and hang < MAX_HANG and NO_LINE_START.contains(rest[cut]):
			cut += 1
			hang += 1
		# 行末禁則：行末が開き括弧なら次行へ送る（行が空にならない範囲で）
		while cut > 1 and NO_LINE_END.contains(rest[cut - 1]):
			cut -= 1
		if cut <= 0:
			cut = max_chars
		lines.append(rest.substr(0, cut))
		rest = rest.substr(cut)
	lines.append(rest)
	return lines


## 段落（\n 区切り）ごとに折り返し、lines_per_page 行ずつのページにまとめる
static func paginate(text: String, max_chars: int, lines_per_page: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for paragraph: String in text.split("\n"):
		lines.append_array(wrap_line(paragraph, max_chars))
	var pages: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < lines.size():
		pages.append("\n".join(lines.slice(i, mini(i + lines_per_page, lines.size()))))
		i += lines_per_page
	if pages.is_empty():
		pages.append("")
	return pages
