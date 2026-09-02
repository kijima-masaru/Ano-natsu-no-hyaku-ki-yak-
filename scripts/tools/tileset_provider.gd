class_name TileSetProvider
extends RefCounted
## ゲームロジックが TileSet を取得する唯一の窓口。
## ProjectSettings の iwato/tileset/source で「生成（generated）」と「リソース読み込み（resource）」を切り替える。
## 手描き PNG への差し替え手順は docs/TILESET_PIPELINE.md を参照。

const SETTING_SOURCE: String = "iwato/tileset/source"
const SETTING_RESOURCE_PATH: String = "iwato/tileset/resource_path"
const SOURCE_GENERATED: String = "generated"
const SOURCE_RESOURCE: String = "resource"
const DEFAULT_RESOURCE_PATH: String = "res://resources/tilesets/common.tres"

static var _cached: TileSet = null


## 設定に従って TileSet を返す（初回のみ生成／読み込み、以降はキャッシュ）
static func get_tileset() -> TileSet:
	if _cached != null:
		return _cached
	var mode: String = str(ProjectSettings.get_setting(SETTING_SOURCE, SOURCE_GENERATED))
	if mode == SOURCE_RESOURCE:
		_cached = _load_resource()
	elif mode == SOURCE_GENERATED:
		_cached = _generate()
	else:
		push_error("TileSetProvider: %s の値 '%s' は不正です（generated / resource）。生成に切り替えます" % [SETTING_SOURCE, mode])
		_cached = _generate()
	return _cached


static func _generate() -> TileSet:
	return TileGenerator.build_tileset(TileCatalog.all_names())


static func _load_resource() -> TileSet:
	var path: String = str(ProjectSettings.get_setting(SETTING_RESOURCE_PATH, DEFAULT_RESOURCE_PATH))
	if not ResourceLoader.exists(path):
		push_error("TileSetProvider: TileSet リソース '%s' が見つかりません。生成に切り替えます" % path)
		return _generate()
	var loaded: Resource = ResourceLoader.load(path)
	var tile_set: TileSet = loaded as TileSet
	if tile_set == null:
		push_error("TileSetProvider: '%s' は TileSet ではありません。生成に切り替えます" % path)
		return _generate()
	if not tile_set.has_meta(TileGenerator.META_COORDS):
		push_error("TileSetProvider: '%s' に %s メタがありません。種別名からタイルを引けないため生成に切り替えます"
			% [path, TileGenerator.META_COORDS])
		return _generate()
	return tile_set


## 生成した TileSet をリソースとして保存する（PNG 差し替えの起点になるファイルを作る）
static func save_generated(path: String = DEFAULT_RESOURCE_PATH) -> Error:
	var tile_set: TileSet = _generate()
	var err: Error = ResourceSaver.save(tile_set, path)
	if err != OK:
		push_error("TileSetProvider: '%s' への保存に失敗しました（%s）" % [path, error_string(err)])
	else:
		print("TileSetProvider: TileSet を保存しました → %s" % path)
	return err


## 種別名からアトラス座標を取る（TileMapLayer.set_cell 用）
static func get_atlas_coords(type_name: String) -> Vector2i:
	return TileGenerator.get_atlas_coords(get_tileset(), type_name)


## キャッシュを破棄する（設定変更後やテスト用）
static func reset() -> void:
	_cached = null
	TileGenerator.clear_cache()
