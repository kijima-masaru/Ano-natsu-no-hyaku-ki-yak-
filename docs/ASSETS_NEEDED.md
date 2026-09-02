# 必要素材一覧（発注書の下書き）

現時点で画像・音声の素材は存在せず、すべてプロシージャル生成（タイル：`TileGenerator`、アクター：`ActorSpriteGenerator`、音：`SoundSynth`）で動いている。
本書は差し替え時の発注書として育てる。ステップ3〜4で追記し続ける。

## 差し替えの境界

| 種別 | 生成側（暫定） | 本番の置き場所 | 切替方法 |
|---|---|---|---|
| タイル 16×16 | `scripts/tools/tile_*.gd` | `resources/tilesets/common.tres` のアトラス PNG | `iwato/tileset/source="resource"`（docs/TILESET_PIPELINE.md） |
| アクター 16×24 | `scripts/tools/actor_sprite_generator.gd` | `SpriteFrames` リソース | `get_texture` の返却先を差し替え（タスク8で共通化） |
| 音 | `scripts/tools/sound_synth.gd` | `resources/audio/<id>.ogg` | 同名 OGG があれば `AudioManager` が自動で優先 |
| フォント | 代替フォント | `resources/fonts/PixelMplus12-Regular.ttf` | 配置するだけ（`resources/fonts/README.md`） |

## 音（data/audio.json の id と 1 対 1）

想定フォーマット：OGG Vorbis、44.1kHz、モノラル可。ループ素材はシームレス。音量はゲーム側でバス調整するため、ピーク -3dBFS 程度で統一。

### BGM
| id | 用途 | 想定尺 | 備考 |
|---|---|---|---|
| bgm_title | タイトル | 60〜90 秒ループ | 低いドローン。旋律は最小限。蝉の残響 |
| bgm_tension | 追跡者に追われている間 | 30〜45 秒ループ | 低音のうねり。心拍 se_heartbeat と重なる前提で帯域を避ける |

### 環境音（フィールド × 時間帯）
| id | フィールド | 想定尺 | 内容 |
|---|---|---|---|
| amb_road / amb_road_night | F01 | 60 秒ループ | 国道の走行音、自販機のコンプレッサ、夜は車が疎らに |
| amb_town / amb_town_night | F06 | 60 秒ループ | 蝉（昼）、掲示板の紙が鳴る、夜は虫の声 |
| amb_residential / _night | F02 | 60 秒ループ | 蝉、遠い国道、夜はほぼ無音に近い風 |
| amb_shopping_street | F05 | 60 秒ループ | 風、シャッターの軋み。**足音が響く**前提で薄く |
| amb_estate | F12 | 60 秒ループ | 給水塔のモーター、階段室の反響、蝉 |
| amb_newtown | F13 | 60 秒ループ | 均質な無音。街灯の微かなハム |
| amb_underpass | F03 | 60 秒ループ | 高架の走行音が上から。防音壁の反響。隧道内は別バリエーションを検討 |
| amb_orchard | F04 | 60 秒ループ | 蝉が最も多い。トタンが鳴る |
| amb_temple / amb_shrine | F07 / F08 | 60 秒ループ | 風、木の軋み。梅林の枝が触れ合う音 |
| amb_castle | F09 | 60 秒ループ | 高速の走行音が防音壁越しに低く。土塁の上は風 |
| amb_ground | F10 | 60 秒ループ | 川の音、草が寝る音、金網が鳴る |
| amb_school | F11 | 60 秒ループ | 無音と蛍光灯のハム。旧校舎は床板が鳴る別バリエーション |
| amb_paddy / amb_paddy_night | F14 | 60 秒ループ | 蛙（夜）、水路。**8/30 以降は蛙が止む**変化を用意 |
| amb_river | F15 | 60 秒ループ | 川の音が全てを覆う |
| amb_valley | F16 | ― | **無音**。素材不要 |

蝉の減衰：`seasonal: "cicada"` の環境音は Calendar.day に応じてゲーム側で音量を落とす。素材側で日ごとの差分は不要。

### 効果音
| id | 用途 | 想定尺 |
|---|---|---|
| se_footstep / se_footstep_sneak | 歩行／忍び足。地面種別ごとの差分（アスファルト・砂利・草・板）は後で追加 | 0.1〜0.2 秒 × 各 3〜4 バリエーション |
| se_interact | 調べる | 0.15 秒 |
| se_menu_move / se_menu_ok / se_menu_cancel | メニュー | 0.1 秒 |
| se_door | 戸・門 | 0.3 秒 |
| se_heartbeat | 追跡中に重ねる心拍 | 4 秒ループ |

### 未定義（後続タスクで追加予定）
- 追跡者の足音・気配（タスク10）
- ヒロインの足音（タスク8）
- 憑いた怪異の「声」に伴う環境の微細な変化（タスク9。自販機の光が強まる音、足音が一組増える音）
- フィールド固有の物音（掲示板の紙、階段室の灯、田に映る月）

## 画像

タイル種別 163 件は `data/fields.json` の `required_tiles` と `scripts/tools/tile_catalog.gd` を正とする。アクターは主人公・ヒロイン・追跡者の 3 体（4 方向 × 2 フレーム）。詳細はステップ4のフィールド量産で確定させる。
