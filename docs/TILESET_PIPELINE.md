# タイルセットの供給経路と PNG 差し替え手順

ゲームロジックは **`TileSetProvider.get_tileset()`** からだけ TileSet を受け取る。
その内側で「実行時にプロシージャル生成する」か「保存済みリソースを読み込む」かを切り替える。
ゲーム側のコードはどちらでも変わらない。

```
                 ┌───────────────────────────────┐
 フィールド .tscn ─▶│ TileSetProvider.get_tileset() │─▶ TileSet（物理レイヤー＋tile_type/is_interactable）
                 └──────────────┬────────────────┘
                 iwato/tileset/source
              ┌─────────────────┴──────────────────┐
        "generated"                            "resource"
   TileGenerator.build_tileset()        ResourceLoader.load(resource_path)
   ├ TileCatalog（種別 → ペインタ）      └ resources/tilesets/common.tres
   ├ TilePaintersGround / Built / Objects   （将来: 手描き PNG を貼った TileSet）
   └ TileBrush（Image への描画）
```

## 関係するファイル

| ファイル | 役割 | ゲームロジックからの参照 |
|---|---|---|
| `scripts/tools/tileset_provider.gd` | 供給の窓口。設定を読んで生成／読み込みを選ぶ | **ここだけ** |
| `scripts/tools/tile_generator.gd` | 生成の入口。Image/Texture のキャッシュ、TileSet 組み立て、種別名→座標の解決 | 禁止（`get_atlas_coords` は Provider 経由） |
| `scripts/tools/tile_catalog.gd` | 種別名（`fields.json` の `required_tiles` と同じ日本語）→ ペインタ・引数・通行可否・調べ可否 | 禁止 |
| `scripts/tools/tile_painters_*.gd` | 実際に 16×16 を描くペインタ群（地面／面／物） | 禁止 |
| `scripts/tools/tile_brush.gd` | Image への描画プリミティブ | 禁止 |

## 設定（project.godot）

```
[iwato]
tileset/source="generated"                                   ; "generated" または "resource"
tileset/resource_path="res://resources/tilesets/common.tres"
```

エディタでは「プロジェクト設定 → 一般 → Iwato → Tileset」に表示される（高度な設定をオン）。

## 種別名から TileMapLayer にタイルを置く

```gdscript
var layer: TileMapLayer = $Ground
layer.tile_set = TileSetProvider.get_tileset()
var coords: Vector2i = TileSetProvider.get_atlas_coords("アスファルト")
layer.set_cell(Vector2i(3, 4), TileGenerator.SOURCE_ID, coords)
```

種別名は `TileSet` の meta `tile_coords`（種別名 → アトラス座標）で解決する。
生成でも読み込みでも **この meta が無い TileSet は受け付けない**（Provider がエラーを出して生成へフォールバックする）。

各タイルは次のデータを持つ。

| 層 | 名前 | 型 | 内容 |
|---|---|---|---|
| 物理レイヤー 0 | ― | ― | `walkable=false` の種別に全面の衝突矩形 |
| カスタムデータ 0 | `tile_type` | String | 種別名 |
| カスタムデータ 1 | `is_interactable` | bool | 調べられる対象か |

## 現在の構成（`source="resource"`）

`resources/tilesets/common_atlas.png` は **`tools/tiles/paint_atlas.py`（Python、Pillow）が描く**。種別名 → ペインタ名・引数・通行可否は `tools/tiles/catalog.json` に書き出してあり（`driver_tileset_export --catalog`）、Python 側はそれを読んで同じ引数（色インデックス・密度）で描く。`common.tres` は `driver_tileset_export` が生成し、アトラスの texture としてこの PNG を参照する。

```
python3 tools/tiles/paint_atlas.py --preview build/atlas_x4.png     # PNG を描く（決定的。16 px の元絵を --tile-scale 2 で 32 px に拡大。32 px 直描きへ移行中）
$G --headless --path . --import                                       # PNG を取り込む
$G --headless --path . $D -- --runner=$R/driver_tileset_export.gd     # common.tres を更新（PNG を参照）
xvfb-run ... --runner=$R/driver_shots.gd --out=DIR                    # 画面で確認
```

`paint_atlas.py` は汎用ペインタ（地面・壁・木など。`PAINTERS`）と、種別名ごとの専用描画（`tools/tiles/special.py` の `SPECIAL`。自販機・街灯・時計塔・墓石など 90 種）の 2 段で、専用描画があればそちらを使う。物は 1 種ずつ描くのが基本で、汎用ペインタは引数だけ違う地面・壁の類に限る。

`TileCatalog` に種別を足したら `--catalog` で catalog.json を更新し、`special.py` に専用描画を書く（地面・壁なら `PAINTERS` の該当ペインタで足りる）。生成ペインタ（`tile_painters_*.gd`）はフォールバックとして残す。

## 手描き PNG への差し替え手順

1. **起点ファイルを作る**：`scenes/debug/tile_preview.tscn` を実行し Enter を押す（または `TileSetProvider.save_generated()`）。
   `resources/tilesets/common.tres` に、生成アトラスと全タイルの物理・カスタムデータ・`tile_coords` meta を含む TileSet が保存される。
2. **アトラス画像を差し替える**：手描き PNG を `resources/tilesets/common_atlas.png` として置く。
   並び順は `tile_coords` meta と同じ（16 列、`TileCatalog.all_names()` のソート順）。
   エディタで `common.tres` を開き、アトラスソースの `texture` をその PNG に変える。
   タイルの座標・物理・カスタムデータは TileSet 側に残るので描き直す必要はない。
3. **設定を切り替える**：`iwato/tileset/source` を `"resource"` にする。
4. **確認する**：`tile_preview.tscn` を実行し、同じ並びで手描きタイルが出ること、
   出力に `TileSetProvider:` のエラーが無いことを確認する。
5. **一部だけ差し替える場合**：手順 2 で、生成アトラスを一度 PNG に書き出し（`Image.save_png`）、
   差し替えたいタイルだけ上書きする。未着手のタイルは生成結果のまま残る。

## 新しい種別を追加する

1. `data/fields.json` の `required_tiles` に日本語名を足す
2. `tile_catalog.gd` の `_build()` に 1 行追加する（既存ペインタで表せなければ `tile_painters_*.gd` にペインタを追加）
3. `tile_preview.tscn` を実行し、起動ログの「required_tiles … はすべて対応表にあります」を確認する

対応表に無い種別は **フォールバックタイル**（赤枠＋頭文字由来のビットパターン）で描かれ、初回に警告が出る。
フォールバックは通行不可・調べ不可として扱う。

## 制約

- 色は全てパレットインデックスで指定する。ペインタ内で `Color(...)` を書かない
- 生成は決定的（座標ハッシュ乱数）。同じ種別は常に同じ絵になる
- `scripts/tools/` はゲームロジックに依存しない（`Palette` と `GameConstants` のみ参照可）
