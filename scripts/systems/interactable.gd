class_name Interactable
extends Area2D
## プレイヤーが「調べる」対象の基底ノード。
## 衝突レイヤー 2 に置き、プレイヤーの前方判定（InteractProbe）から検出される。
## 調べられたら interacted を発火する。表示テキストは仮で、正式な文言は後のステップで差し替える。

signal interacted(by: Node, interactable: Interactable)

## 衝突レイヤー番号（1 始まり）。プレイヤーの InteractProbe の mask と合わせる
const COLLISION_LAYER_BIT: int = 2

## 識別子（フィールド内で一意）
@export var interaction_id: String = ""
## 表示名（メッセージウィンドウの見出し）
@export var display_name: String = ""
## 調べたときの仮テキスト
@export_multiline var message: String = ""
## 種類："object" / "save_point" / "sign" / "npc"
@export var kind: String = "object"
## 調べた回数
var times_interacted: int = 0


func _ready() -> void:
	collision_layer = 1 << (COLLISION_LAYER_BIT - 1)
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")


## NPC など、見た目を持つ調べ物にアクタースプライトを付ける（ActorSpriteGenerator の種別）
func set_actor_sprite(kind: String, facing: Vector2i = Vector2i.DOWN) -> void:
	var sprite: Sprite2D = get_node_or_null("ActorSprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "ActorSprite"
		sprite.centered = false
		sprite.offset = Vector2(-8, -14)
		add_child(sprite)
	sprite.texture = ActorSpriteGenerator.get_texture(kind, facing, 0)


## プレイヤーから呼ばれる
func interact(by: Node) -> void:
	times_interacted += 1
	interacted.emit(by, self)


## タイル座標と大きさ（タイル数）から Interactable を組み立てる
static func create(id: String, label: String, text: String, tile: Vector2i, size_tiles: Vector2i = Vector2i.ONE, node_kind: String = "object") -> Interactable:
	var node: Interactable = Interactable.new()
	node.name = "Interactable_" + id
	node.interaction_id = id
	node.display_name = label
	node.message = text
	node.kind = node_kind
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(size_tiles * GameConstants.TILE_SIZE) - Vector2(2, 2)
	shape.shape = rect
	node.add_child(shape)
	node.position = Vector2(tile * GameConstants.TILE_SIZE) + Vector2(size_tiles * GameConstants.TILE_SIZE) * 0.5
	return node
