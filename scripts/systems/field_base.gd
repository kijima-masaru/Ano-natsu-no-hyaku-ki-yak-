class_name FieldBase
extends Node2D
## すべてのフィールドシーンのルートが継承する基底クラス。
## 子ノードの構成（描画順＝この順）：Ground / Objects（TileMapLayer）→ Actors（Node2D）→ Overhead（TileMapLayer）→ Lights → Triggers
## SceneRouter は setup(def) を呼んでから add_child する。
## サブクラスは MAP_ROWS 等の定数を定義するだけでよく（FieldMapBuilder 参照）、
## 時間帯・日付の差し替えは _apply_time_of_day / _apply_day を上書きする。
## 基底シーンは scenes/fields/field_base.tscn。各フィールドの .tscn はこれを継承してスクリプトだけ差し替える。

signal exit_reached(exit: ExitData)
signal interaction_started(interactable: Interactable)

const LAYER_GROUND: String = "Ground"
const LAYER_OBJECTS: String = "Objects"
const LAYER_OVERHEAD: String = "Overhead"
const ACTOR_ROOT: String = "Actors"
const TRIGGER_ROOT: String = "Triggers"
const LIGHT_ROOT: String = "Lights"
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
## タイル光源（PointLight2D）の置き場。Lighting が set_tile に合わせて出し入れする
var lights: Node2D


## SceneRouter から add_child の前に呼ばれる
func setup(def: FieldData) -> void:
	field_def = def
	field_id = def.id if def != null else ""
	_ensure_layers()
	_build(def)
	_build_exit_triggers()


## タイル・調べ物の配置。既定では MAP_ROWS / GROUND_LEGEND / OBJECT_LEGEND などの定数から
## FieldMapBuilder が組み立てる。定数を持たないフィールド（プレースホルダ等）は上書きする
func _build(def: FieldData) -> void:
	if not FieldMapBuilder.build(self, def):
		push_warning("FieldBase(%s): MAP_ROWS が無く _build も上書きされていません" % field_id)


## 物体タイルの下地となる地面の種別名。空文字なら DEFAULT_GROUND（無ければ GROUND_LEGEND の先頭）。
## 場所によって下地を変えるフィールドが上書きする
func _ground_under(_x: int, _y: int) -> String:
	return ""


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

## 種別名でタイルを置く。Objects / Overhead 層なら LightCatalog に従って光源も同期する
func set_tile(layer: TileMapLayer, tile: Vector2i, type_name: String) -> void:
	var coords: Vector2i = TileSetProvider.get_atlas_coords(type_name)
	if coords.x < 0:
		return
	layer.set_cell(tile, TileGenerator.SOURCE_ID, coords)
	if layer != ground and lights != null:
		Lighting.sync_tile_light(lights, tile, type_name)


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


## 追跡者を Actors 配下に出す（start_stalker アクション）。既にいれば位置だけ移す
func spawn_stalker(tile: Vector2i, retreat_field_id: String) -> Node2D:
	var existing: Node2D = get_stalker()
	if existing != null:
		existing.global_position = GameConstants.tile_to_world(tile)
		existing.set("home_position", existing.global_position)
		return existing
	var packed: PackedScene = load("res://scenes/actors/stalker.tscn") as PackedScene
	var stalker: Node2D = packed.instantiate() as Node2D
	stalker.position = GameConstants.tile_to_world(tile)
	stalker.set("retreat_field_id", retreat_field_id)
	actors.add_child(stalker)
	return stalker


func remove_stalker() -> void:
	var existing: Node2D = get_stalker()
	if existing != null:
		existing.queue_free()


func get_stalker() -> Node2D:
	for node: Node in actors.get_children():
		if node.is_in_group("stalker"):
			return node as Node2D
	return null


## 調べ物を Triggers 配下に置き、interaction_started に中継する
func add_interactable(node: Interactable) -> void:
	triggers.add_child(node)
	node.interacted.connect(func(_by: Node, target: Interactable) -> void: interaction_started.emit(target))


## interaction_id で調べ物を探す。無ければ null
func get_interactable(id: String) -> Interactable:
	for node: Node in triggers.get_children():
		var it: Interactable = node as Interactable
		if it != null and it.interaction_id == id:
			return it
	return null


## 時間帯・日付で出し入れする NPC（見た目付きの調べ物）。present に合わせて生成／削除し、現在のノードを返す
func set_npc_present(id: String, present: bool, tile: Vector2i, sprite_kind: String, facing: Vector2i = Vector2i.DOWN) -> Interactable:
	var existing: Interactable = get_interactable(id)
	if present and existing == null:
		var npc: Interactable = Interactable.create(id, "", "", tile, Vector2i.ONE, "npc")
		npc.set_actor_sprite(sprite_kind, facing)
		add_interactable(npc)
		return npc
	if not present and existing != null:
		triggers.remove_child(existing)
		existing.queue_free()
		return null
	return existing


# ── 内部 ──

func _ensure_layers() -> void:
	ground = _ensure_tile_layer(LAYER_GROUND)
	objects = _ensure_tile_layer(LAYER_OBJECTS)
	actors = _ensure_node2d(ACTOR_ROOT)
	overhead = _ensure_tile_layer(LAYER_OVERHEAD)
	lights = _ensure_node2d(LIGHT_ROOT)
	triggers = _ensure_node2d(TRIGGER_ROOT)
	# 描画順を保証する（光源は描画順に関係しない）
	move_child(ground, 0)
	move_child(objects, 1)
	move_child(actors, 2)
	move_child(overhead, 3)
	move_child(lights, 4)
	move_child(triggers, 5)


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


## fields.json の exits ごとに境界タイルへ Area2D を置く（FieldExitTriggers）
func _build_exit_triggers() -> void:
	FieldExitTriggers.build(self, field_def, _on_exit_body_entered)


func _on_exit_body_entered(body: Node2D, exit: ExitData) -> void:
	if body.is_in_group("player"):
		exit_reached.emit(exit)
