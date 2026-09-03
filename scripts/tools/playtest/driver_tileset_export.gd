extends Node
## 使い方：godot --headless --path . res://scenes/debug/playtest_driver.tscn -- --runner=res://scripts/tools/playtest/driver_tileset_export.gd [--png] [--catalog]
## TileSet リソース（resources/tilesets/common.tres）を書き出す（docs/TILESET_PIPELINE.md）。
## - 既定：アトラス PNG（resources/tilesets/common_atlas.png。tools/tiles/paint_atlas.py が描く）を texture として参照する .tres を書く。
##   PNG が未取り込み（--import 前）なら生成画像を埋め込む
## - --png：生成ペインタのアトラスを PNG に書き出す（手描き差し替えの起点。既存の PNG を上書きするので注意）
## - --catalog：tools/tiles/catalog.json（種別名 → ペインタ・引数・通行可否。paint_atlas.py の入力）を書き出す

const ATLAS_PNG: String = "res://resources/tilesets/common_atlas.png"
const TRES: String = "res://resources/tilesets/common.tres"
const CATALOG_JSON: String = "res://tools/tiles/catalog.json"


func _ready() -> void:
	await get_tree().process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = TileCatalog.all_names()
	var tile_set: TileSet = TileGenerator.build_tileset(names)
	var source: TileSetAtlasSource = tile_set.get_source(TileGenerator.SOURCE_ID) as TileSetAtlasSource
	if args.has("--catalog"):
		var out: Dictionary = {}
		for n: String in names:
			out[n] = TileCatalog.entries()[n]
		var f: FileAccess = FileAccess.open(CATALOG_JSON, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  ") + "\n")
		f.close()
		print("catalog: %s (%d)" % [CATALOG_JSON, out.size()])
	if args.has("--png") or not FileAccess.file_exists(ATLAS_PNG):
		var image: Image = source.texture.get_image()
		print("atlas png: %s %dx%d -> %s" % [ATLAS_PNG, image.get_width(), image.get_height(), error_string(image.save_png(ATLAS_PNG))])
	if ResourceLoader.exists(ATLAS_PNG):
		var tex: Texture2D = load(ATLAS_PNG) as Texture2D
		if tex != null:
			var expected: Vector2i = Vector2i(TileGenerator.ATLAS_COLUMNS, ceili(float(names.size()) / TileGenerator.ATLAS_COLUMNS)) * GameConstants.TILE_SIZE
			if Vector2i(tex.get_width(), tex.get_height()) != expected:
				push_error("atlas png の大きさ %dx%d が期待 %dx%d と違う（tools/tiles/paint_atlas.py を実行し直す）" % [tex.get_width(), tex.get_height(), expected.x, expected.y])
			source.texture = tex
			print("atlas texture: 取り込み済み PNG を参照")
	else:
		print("atlas texture: PNG が未取り込みのため画像を埋め込む（--import 後に再実行すると参照になる）")
	var err: Error = ResourceSaver.save(tile_set, TRES)
	print("tileset: %s -> %s (tiles=%d, names=%d, columns=%d)" % [TRES, error_string(err), source.get_tiles_count(), names.size(), TileGenerator.ATLAS_COLUMNS])
	get_tree().quit(0)
