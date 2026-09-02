class_name FieldBase
extends Node2D
## すべてのフィールドシーンのルートが継承する基底クラス。
## 子ノードの構成（描画順＝この順）：Ground / Objects（TileMapLayer）→ Actors（Node2D）→ Overhead（TileMapLayer）→ Triggers
## SceneRouter は setup(def) を呼んでから add_child する。サブクラスは _build(def) でタイルと調べ物を配置する。

signal exit_reached(exit: ExitData)
signal interaction_started(interactable: Interactable)

const LAYER_GROUND: String = "Ground"
const LAYER_OBJECTS: String = "Objects"
const LAYER_OVERHEAD: String = "Overhead"
const ACTOR_ROOT: String = "Actors"
const TRIGGER_ROOT: String = "Triggers"
## 出口トリガーの当たり（タイルより少し小さくして隣接タイルから誤発火しない）
const EXIT_TRIGGER_SIZE: Vector2 = Vector2(14, 14)
## 定義が無いときの寸法（24×14 タイル＝1 画面）
const FALLBACK_SIZE_TILES: Vector2i = Vector2i(24, 14)

var field_def: FieldData = null
var field_id: String = ""
## 出口以外から入ったときの出現位置。負なら中央
@export var default_spawn_tile: Vector2i = Vector2i(-1, -1)

var ground: TileMapLayer
var objects: TileMapLayer
var overhead: TileMapLayer
var actors: Node2D
var triggers: Node2D


## SceneRouter から add_child の前に呼ばれる
func setup(def: FieldData) -> void:
	field_def = def
	field_id = def.id if def != null else ""
	_ensure_layers()
	_build(def)
	_build_exit_triggers()


## サブクラスが上書きしてタイル・調べ物を配置する
func _build(_def: FieldData) -> void:
	pass


## 時間帯（morning / noon / evening / night）に応じた見た目の差し替え。サブクラスが上書きする。
## ツリーに入った直後に現在の時間帯で一度呼ばれ、以後 Calendar.time_of_day_changed で呼ばれる
func _apply_time_of_day(_time_of_day: String) -> void:
	pass


## 日付に応じた配置の差し替え。サブクラスが上書きする。ツリーに入った直後と Calendar.day_advanced で呼ばれる
func _apply_day(_day: int) -> void:
	pass


func _enter_tree() -> void:
	if not Calendar.time_of_day_changed.is_connected(_on_calendar_time_changed):
		Calendar.time_of_day_changed.connect(_on_calendar_time_changed)
	if not Calendar.day_advanced.is_connected(_on_calendar_day_advanced):
		Calendar.day_advanced.connect(_on_calendar_day_advanced)


func _ready() -> void:
	_apply_day(Calendar.day)
	_apply_time_of_day(Calendar.time_of_day)


func _exit_tree() -> void:
	if Calendar.time_of_day_changed.is_connected(_on_calendar_time_changed):
		Calendar.time_of_day_changed.disconnect(_on_calendar_time_changed)
	if Calendar.day_advanced.is_connected(_on_calendar_day_advanced):
		Calendar.day_advanced.disconnect(_on_calendar_day_advanced)


func _on_calendar_time_changed(time_of_day: String, _previous: String) -> void:
	_apply_time_of_day(time_of_day)


func _on_calendar_day_advanced(day: int, _previous: int) -> void:
	_apply_day(day)


func get_size_tiles() -> Vector2i:
	return field_def.size_tiles if field_def != null else FALLBACK_SIZE_TILES


func get_bounds_px() -> Rect2i:
	return Rect2i(Vector2i.ZERO, get_size_tiles() * GameConstants.TILE_SIZE)


func get_actor_root() -> Node2D:
	return actors


## from_id から入ってきたときの出現タイル（対応する出口の 1 タイル内側）。無ければ既定位置
func get_spawn_tile(from_id: String) -> Vector2i:
	if field_def != null and not from_id.is_empty():
		var exit: ExitData = field_def.find_exit_to(from_id)
		if exit != null:
			return exit.inward_tile()
	if default_spawn_tile.x >= 0 and default_spawn_tile.y >= 0:
		return default_spawn_tile
	var size: Vector2i = get_size_tiles()
	@warning_ignore("integer_division")
	return Vector2i(size.x / 2, size.y / 2)


## 出現時の向き（出口から内側へ歩いてくる向き）。無ければ下向き
func get_spawn_facing(from_id: String) -> Vector2i:
	if field_def != null and not from_id.is_empty():
		var exit: ExitData = field_def.find_exit_to(from_id)
		if exit != null:
			return -exit.side_vector()
	return Vector2i.DOWN


# ── タイル配置ヘルパー ──

func set_tile(layer: TileMapLayer, tile: Vector2i, type_name: String) -> void:
	var coords: Vector2i = TileSetProvider.get_atlas_coords(type_name)
	if coords.x < 0:
		return
	layer.set_cell(tile, TileGenerator.SOURCE_ID, coords)


func fill_rect(layer: TileMapLayer, rect: Rect2i, type_name: String) -> void:
	var coords: Vector2i = TileSetProvider.get_atlas_coords(type_name)
	if coords.x < 0:
		return
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			layer.set_cell(Vector2i(x, y), TileGenerator.SOURCE_ID, coords)


## 指定レイヤーのタイル種別名。空なら ""
func get_tile_type_at(layer: TileMapLayer, tile: Vector2i) -> String:
	return TileGenerator.get_tile_type(layer.get_cell_tile_data(tile))


## 調べ物を Triggers 配下に置き、interaction_started に中継する
func add_interactable(node: Interactable) -> void:
	triggers.add_child(node)
	node.interacted.connect(func(_by: Node, target: Interactable) -> void: interaction_started.emit(target))


# ── 内部 ──

func _ensure_layers() -> void:
	ground = _ensure_tile_layer(LAYER_GROUND)
	objects = _ensure_tile_layer(LAYER_OBJECTS)
	actors = _ensure_node2d(ACTOR_ROOT)
	overhead = _ensure_tile_layer(LAYER_OVERHEAD)
	triggers = _ensure_node2d(TRIGGER_ROOT)
	# 描画順を保証する
	move_child(ground, 0)
	move_child(objects, 1)
	move_child(actors, 2)
	move_child(overhead, 3)
	move_child(triggers, 4)


func _ensure_tile_layer(node_name: String) -> TileMapLayer:
	var existing: Node = get_node_or_null(node_name)
	var layer: TileMapLayer = existing as TileMapLayer
	if existing != null and layer == null:
		push_error("FieldBase(%s): 子ノード '%s' は TileMapLayer である必要があります" % [field_id, node_name])
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = node_name
		add_child(layer)
	if layer.tile_set == null:
		layer.tile_set = TileSetProvider.get_tileset()
	return layer


func _ensure_node2d(node_name: String) -> Node2D:
	var existing: Node2D = get_node_or_null(node_name) as Node2D
	if existing != null:
		return existing
	var node: Node2D = Node2D.new()
	node.name = node_name
	add_child(node)
	return node


## fields.json の exits ごとに境界タイルへ Area2D を置く
func _build_exit_triggers() -> void:
	if field_def == null:
		return
	for exit: ExitData in field_def.exits:
		if not field_def.contains_tile(exit.tile):
			push_error("FieldBase(%s): 出口 %s のタイルがフィールド外です" % [field_id, exit.describe()])
			continue
		var area: Area2D = Area2D.new()
		area.name = "ExitTrigger_%s" % exit.to_id
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		area.position = GameConstants.tile_to_world(exit.tile)
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = EXIT_TRIGGER_SIZE
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_on_exit_body_entered.bind(exit))
		triggers.add_child(area)


func _on_exit_body_entered(body: Node2D, exit: ExitData) -> void:
	if body.is_in_group("player"):
		exit_reached.emit(exit)
