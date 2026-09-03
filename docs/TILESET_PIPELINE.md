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

`resources/tilesets/common_atlas.png` は **`tools/tiles/paint32.py`（Python、Pillow）が 32 px・自由な色数で描く**。種別名 → ペインタ名・引数・通行可否は `tools/tiles/catalog.json` に書き出してあり（`driver_tileset_export --catalog`）、Python 側はそれを読んで種別ごとに描く。並び（種別名 → アトラス座標、オートタイルの変種、背の高い部品の上半分）は `resources/tilesets/atlas_layout.json` に書き、`common.tres` は `driver_tileset_export` がこの layout と PNG から組む（物理・カスタムデータは `TileCatalog` から）。

```
python3 tools/tiles/paint32.py --preview build/atlas_x3.png          # PNG と layout を描く（決定的）
$G --headless --path . --import                                       # PNG を取り込む
$G --headless --path . $D -- --runner=$R/driver_tileset_export.gd     # layout から common.tres を組む
xvfb-run ... --runner=$R/driver_shots.gd --out=DIR                    # 画面で確認
```

ペインタの置き場：

| ファイル | 内容 |
|---|---|
| `tools/tiles/px32.py` | 32 px キャンバス、色（`C`）、ノイズ・勾配・ディザ・輪郭・影のプリミティブ。光は左上、物は暗い輪郭で地面から切り離す |
| `tools/tiles/paint32.py` | 地面・水・斜面・階段（`FLAT`）、壁・屋根・柵・生け垣のオートタイル（`AUTOTILE`）、木・街灯・電柱（`TALL`）。`load_extra()` で下の 2 つを遅延で取り込む |
| `tools/tiles/props32a.py` | 道路の線・側溝・ガードレール・看板・灯り・自販機・電話ボックス・校庭の設備など（`FLAT2`） |
| `tools/tiles/props32b.py` | 石碑・墓石・鳥居・門・窓・階段室・店先・塔（`FLAT3` / `TALL3`） |

- **オートタイル**：`AUTOTILE` の種別は 4 近傍（N=1 E=2 S=4 W=8）の 15 通りを `<種別>#m<mask>` としてアトラスに並べる。地図を組んだ後に `TileVariants.apply()` が隣接を見て差し替える（`FieldMapBuilder.build_from` の最後）。地図の外は「同じ」とみなし端で切れ目を出さない。
- **背の高い部品**：`TALL` の種別は幅 w × 高さ h マスで描く（`(描画関数, w, h)`）。底辺の中央のマスが本体（種別名・通行判定）、それ以外のマスは `<種別>#part`（相対位置 dx/dy 付き）として `overhead` 層に載る（アクターより前に描かれ、梢が人物を隠す）。底辺の行は中央のマス以外に描かない（隣の地面にはみ出さない）。大きさは縮尺 1 マス ≈ 1.7 m に合わせる（`docs/ASSETS_NEEDED.md` §0）。`TileSet` の meta `tile_variants` / `tile_tall` に座標表がある。
- **林（杉林など 5 種）**：オートタイルと背の高い部品を併用する。上に同じ林が続く内側のマスは梢を上から見た繁み（変種 `m` で N ビットあり）、林の上端のマスだけ幹のある木として梢が 2 マス立ち上がる（`TileVariants` は上が同じ種別なら部品を置かない）。下端は幹の影で落とす
- **光の遮蔽**：通行不可の種別のうち壁・建物・崖・木の幹などは遮蔽ポリゴン（TileSet の occlusion 層）を持ち、`Lighting` の光源（街灯・懐中電灯）が影を落とす。どのペインタが遮るかは `driver_tileset_export` の `OCCLUDE_FULL` / `OCCLUDE_TRUNK`。光源になる種別（`LightCatalog`）と柵・金網・水・看板は遮らない。判定（`Lighting.light_level_at`）は影を見ない
- 旧 16 px・16 色のペインタ（`paint_atlas.py` / `special.py`）は残してあるが、現在は使っていない（すべての種別が 32 px 直描き）。

`TileCatalog` に種別を足したら `--catalog` で catalog.json を更新し、`paint32.py`（地面・壁）か `props32*.py`（物）に描画を書いて `paint32.py` を実行する。生成ペインタ（`tile_painters_*.gd`）は layout が無いときのフォールバックとして残す。

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
