class_name GameConstants
extends RefCounted
## プロジェクト全体で共有するサイズ定数。数値の直書き（16, 384 …）を禁じるための唯一の定義場所。

## タイル 1 辺のピクセル数
const TILE_SIZE: int = 16
const TILE_VECTOR: Vector2i = Vector2i(TILE_SIZE, TILE_SIZE)

## 基準解像度（16:9）。project.godot の viewport と一致させる
const VIEWPORT_WIDTH: int = 384
const VIEWPORT_HEIGHT: int = 216
const VIEWPORT_SIZE: Vector2i = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
const VIEWPORT_TILES: Vector2i = Vector2i(VIEWPORT_WIDTH / TILE_SIZE, VIEWPORT_HEIGHT / TILE_SIZE)

## 整数倍スケールの上限（1536×864）
const MAX_SCALE: int = 4

## アクター（プレイヤー等）のスプライト寸法。幅 1 タイル、高さ 1.5 タイル
const ACTOR_SPRITE_SIZE: Vector2i = Vector2i(16, 24)


## タイル座標 → ワールド座標（タイルの中心）
static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE_SIZE) + Vector2(TILE_VECTOR) * 0.5


## ワールド座標 → タイル座標
static func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / TILE_SIZE), floori(world.y / TILE_SIZE))

## フィールドの初訪問で得る調査ポイント（Main が field_visited で加算する）
const FIRST_VISIT_POINTS: int = 1

## 視点切替：このフラグが立っている間、プレイヤーの絵はヒロイン（8/31 は澪を操作する）
const POV_HEROINE_FLAG: String = "pov_mio"
