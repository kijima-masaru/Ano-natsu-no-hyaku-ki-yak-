# 現状と申し送り（ステップ5 完了 → ステップ6）

ステップ5「終幕（8/30〜31）の実装と、実機での品質確定」を終えた時点（v0.4.0、PR #43〜#56）の引き継ぎ。**最初にこの文書を読み、次に `docs/PLAYTEST_LOG.md` の「閾値の確定」「通しプレイ」を読む。**

## 1. 今できること（v0.4.0）

- タイトル → 8/1 → 8/31 → エンディング 3 種 → 相談窓口案内 → スタッフロール → タイトル（「裏面から」で周回）まで、Godot 4.7.stable の実機（検証ドライバ）で通る。進行不能・データ破損は 0 件
- 16 フィールド、8/1〜8/31 の日程（固定 12 日・自由 16 日・圧縮 5 日）、イベント 356 件、テキスト 796 件（二層 118 対）、隠蔽 17 件・証拠 8 件、怪異 27 件、音 31 件（合成音）
- 8/30：F16 奥の封印（面 4 枚の配置と封石）→ 帰路 → F12 自宅前の対決 → 提示画面（隠蔽の全件）→ `truth_revealed` → 真相版の町
- 8/31：澪を操作して橋へ。ED-A/B/C（`docs/FLAGS.md`）。事後 → 案内 → スタッフロール → クリア記録（`user://system.json`）
- 推定プレイ時間 最短 約 2 時間 25 分／全消費 約 3 時間 35 分（目標 2〜3.5 時間で合意済み）。接近度は最短 52（B）／全消費 75（A）／目撃を重ねると 100
- 検証：`docs/tools/validate_data.py`（CI）、`scripts/tools/playtest/` のドライバ 10 本（下記 5）

## 2. ステップ6 の作業一覧（想定。指示で上書きする）

| # | 作業 | 参照 | 備考 |
|---|---|---|---|
| 1 | **素材の差し替え**：残りは **アクター 5 種** だけ（フォント・タイル 164 種・光源・タイトル背景・音 215 件は配置済み） | `docs/ASSETS_NEEDED.md` §3、音は `docs/AUDIO_SPEC.md` | 差し替え境界は §1。納品ごとに `driver_shots` で描画確認 |
| 2 | **GodotSteam** の組み込み（`SteamBridge` は空実装） | `scripts/autoload/steam_bridge.gd` | 起動時の初期化、オーバーレイ、クラウドセーブ（`user://saves/` と `system.json`）。Steam 未接続でも今どおり動くこと |
| 3 | **実績**（候補：8 月 1 日、各 ED、裏面クリア、隠蔽 17 件全提示、目撃 0、全フィールド訪問、面 4 枚を一度も間違えない） | `docs/FLAGS.md`「記録用」、`system.json` の `clears_by_ending` | フラグは全部残してある。`SteamBridge.unlock(id)` の口を足す |
| 4 | **Steam Deck**（1280×800、整数 3 倍で 1152×648 ＋ 余白、ゲームパッド専用、Proton）| `docs/PLAYTEST_LOG.md`「操作系」 | 操作案内は `InputDevice` で A/B 表記に切り替わる。文字サイズ 12px の読みやすさを実機で見る |
| 5 | **ストアページ**（成人向けコンテンツの説明、短い説明、スクリーンショット、トレーラー） | `docs/STORE_PAGE.md` | 文案あり。スクリーンショットは素材差し替え後 |
| 6 | **相談窓口の掲載**（候補一覧は提示済み。確認後に記入） | `docs/CONTENT_NOTICE.md` §5、`data/locale/ja/support.json` | 名称・連絡先・受付時間は公式の一次情報で照合し `verified_at` を書く。記入後 `driver_shots` の 01_title_notice.png で表示確認 |
| 7 | **人手による通しプレイ**（時間の実測、ED の分布、追跡者の難度） | `docs/PLAYTEST_LOG.md` | 目標 2〜3.5 時間。ずれたら `Suspicion` の加算と `schedule.json` の必要 P で再調整 |
| 8 | **エクスポート**（Windows / Linux のプリセット、ビルド、サイズ計測、`v0.4.0` タグ） | タスク13（本ステップ最終） | エクスポートテンプレートは GitHub Releases の `Godot_v4.7-stable_export_templates.tpz` |
| 9 | ローカライズ（英語）は任意。`messages.json` の英語版と `support.json` の英語版を用意すれば `MessageResolver` の読み込み先を切り替えるだけ | `docs/CONVENTIONS.md` §10 | 二層テキストの対も英語で揃える必要がある（118 対） |

## 2b. 高精細化（進行中）

画面 640×360（1080p で整数 3 倍）、タイル 32×32、アクター 32×48 に引き上げた（`GameConstants`。距離・速度はタイル単位で定義）。段階：(1) 解像度と UI の再配置 → (2) 32 px・自由な色数のタイル描き直し、壁・屋根・柵のオートタイル、木・柱の背の高い部品 → (3) ブルーム・被写界深度風ぼかし・粒子・影 → (4) アクターとタイトル背景の描き直し。

## 3. 決定事項（変えるなら理由を PR に）

- **描写制約**：`docs/CONTENT_NOTICE.md` §1。終幕の主人公が討たれる場面も事後のみ、カタルシスある死として描かない。全文でこの制約を守っている
- **接近度**（タスク10）：日付経過 0、初訪問 +1、怪異は初回だけ加算、目撃 15〜25、閾値 25/50/75。ED-C は「探索を絞り、目撃なし」の周回で届く設計
- **目標プレイ時間**：2〜3.5 時間（歩行 64 px/s、8/16〜28 の必要 P 4）
- **明るさ**：設定の既定 0.5（照明側の既定と一致）。屋内は暗さ 0.85 で夜の屋外より暗い
- **2 周目**：タイトルに「面」の印と「裏面から」（8/1 から `truth_revealed`）。裏面専用のイベント・台詞は作らない
- **セーブ**：クリア後のセーブは作らない。オートセーブは 8/31 朝のまま。手動スロット 3。位置は保存しない（ロードは屋外の既定位置）
- **相談窓口**：ゲーム内のみ（起動時とエンディング後）。ストアには載せない。未確認の連絡先は書かない
- **未参照フラグ 10 件**：削除しない（`docs/FLAGS.md`「記録用」。実績の材料）
- **200 行超のファイル**：状態機械・遷移・待ち行列・開発ツールは一体で保つ。意味のある単位が見つかったときだけ切り出す（タスク11）
- **検証ドライバと `.gd.uid`** はリポジトリに残す

## 4. Godot の用意（この環境）

`godot` コマンドは無いが、GitHub Releases から公式バイナリを取得して実行できる（プロキシ経由で 75 MB）。エクスポートテンプレートは同様に `Godot_v4.7-stable_export_templates.tpz` を取得する。
```
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip godot.zip && ./Godot_v4.7-stable_linux.x86_64 --headless --path . --import
```
描画確認は `xvfb-run -a -s "-screen 0 1152x648x24" ./Godot_v4.7-stable_linux.x86_64 --path . ...`（Mesa llvmpipe）。音声デバイスは無く dummy driver になる。新しい `.gd` を足したら `--import` で `.gd.uid` を生成してコミットする。

## 5. 検証ドライバ（`scripts/tools/playtest/`、`scenes/debug/playtest_driver.tscn`）

```
G=./Godot_v4.7-stable_linux.x86_64; D=res://scenes/debug/playtest_driver.tscn; R=res://scripts/tools/playtest
$G --headless --path . -s scripts/tools/validate_data.gd                   # データ検証（Python 版と同じ）
$G --headless --path . $D -- --runner=$R/driver_smoke.gd                    # autoload・16 フィールドの組み立て・起動時間
$G --headless --path . $D -- --runner=$R/driver_play.gd --stop-day=30 [--thorough|--witness]   # 8/1→8/30、二層、セーブ、推定時間、接近度
$G --headless --path . $D -- --runner=$R/driver_seal.gd [--untold]          # 8/30 封印
$G --headless --path . $D -- --runner=$R/driver_truth.gd [--low|--all]      # 8/30 夜 対決・提示（--all で隠蔽 17 件）
$G --headless --path . $D -- --runner=$R/driver_ending.gd --ed=a|b|c [--shot=DIR]   # 8/31 → ED → 案内 → スタッフロール → 裏面
$G --headless --path . $D -- --runner=$R/driver_stalker.gd                  # 追跡者の捕獲と庇護
$G --headless --path . $D -- --runner=$R/driver_choice.gd                   # 8/1 の選択肢
xvfb-run -a -s "-screen 0 1152x648x24" $G --path . $D -- --runner=$R/driver_shots.gd --out=DIR   # 画面 18 枚と装置切替
```
数値の期待値は `docs/PLAYTEST_LOG.md`「閾値の確定」（接近度 52／75／100、推定 124／194 分、二層 118 件、セーブ 5 セクション一致、action_failed 0）。

## 5b. ビルド（タスク13、v0.4.0 リリース候補）

`export_presets.cfg` をリポジトリに含める（Godot 4 は署名などの秘密を `export_credentials.cfg` に分けるので、そちらだけ `.gitignore`）。プリセットは Linux（x86_64）と Windows（x86_64）、PCK 埋め込み、`docs/` `*.md` `*.py` `.github/` と検証ドライバを除外。

```
G=./Godot_v4.7-stable_linux.x86_64
$G --headless --path . --export-release "Linux" build/linux/iwato.x86_64
$G --headless --path . --export-release "Windows" build/windows/iwato.exe
./build/linux/iwato.x86_64 --headless --quit-after 180     # 起動確認（EventSystem の検証ログが出て終了コード 0）
```

| 出力 | サイズ | 備考 |
|---|---|---|
| `build/linux/iwato.x86_64` | 76 MB | ELF x86_64、PCK 埋め込み。headless で起動確認済み |
| `build/windows/iwato.exe` | 110 MB | PE32+ x86_64、PCK 埋め込み。アイコン・署名なし（rcedit 未設定）。Windows 実機での起動は未確認 |

エクスポートテンプレートは `Godot_v4.7-stable_export_templates.tpz`（1.3 GB）を `~/.local/share/godot/export_templates/4.7.stable/` に展開する。Steam 向けの最終ビルド（アイコン、バージョン情報、GodotSteam の GDExtension 同梱）はステップ6。

### v0.4.0 で できていること／いないこと

**できている**
- タイトルから全 ED・周回まで実機で通る。進行不能・データ破損 0 件（`docs/PLAYTEST_LOG.md`）
- 16 フィールド、全日程、イベント 356、テキスト 796（二層 118 対）、隠蔽 17、怪異 27、ED 3 種、裏面
- 接近度・プレイ時間の閾値確定（最短 約 2h25／全消費 約 3h35、ED-A/B/C が選べる）
- コンテンツ警告（起動時・エンディング後）、相談窓口の枠、ストア文案
- セーブ／ロード、クリア記録、設定、装置別の操作案内、ゲームパッド対応
- データ検証（CI）、実機検証ドライバ 10 本、Linux／Windows のビルド

**できていない**
- 画像・音声の本番素材（すべて生成素材。`docs/ASSETS_NEEDED.md`）、PixelMplus12 の配置
- 相談窓口の連絡先の記入（確認待ち）
- GodotSteam（`SteamBridge` は空実装）、実績、Steam Deck の実機確認、ストアの画像
- 人手による通しプレイの実測（時間・ED の分布・追跡者の難度）
- Windows 実機での起動確認、アイコン・署名

## 6. 手作業が必要な項目（環境の制約で未実施）

- タグ：`v0.1.0`（6b10e7c）`v0.2.0`（dbf8df4）`v0.3.0`（b9312ea）`v0.4.0`（858d09b）はすべてリモートに反映済み。以後のタグは、この環境からはプロキシに落とされるので、手元のクローンから HTTPS で `git push origin <tag>` する
- GitHub の既定ブランチを `main` に切り替える（現在は `claude/iwato-field-design-vfrev4`）
- マージ済みリモートブランチの削除（`git push origin --delete <branch>` は 403）
- PixelMplus12 の配置（`resources/fonts/README.md`）
- 人手による通しプレイと Steam Deck での確認

## 7. 既知の課題

- 代替フォントでは行高が大きく、案内画面で窓口 3 件のときに操作案内が下に押し出される（PixelMplus12 配置で解消見込み）
- 終了時のリーク警告（AudioStreamWAV 2 件）。原因未特定、実害なし
- シゲ（F14）はトキの絵を流用。素材が来たら `f14_asawa.gd` の種別を `shige` に
- 支所の「閉庁」文は 8/1・8/2 のみ。曜日条件（`weekday`）は未実装
- 英語版なし

## 8. 運用

- main 直接コミット禁止、`feat/` `fix/` `chore/` `docs/` ブランチ → PR → squash マージ。PR 本文は 概要／変更点／動作確認方法／未対応・既知の課題
- コミットは Conventional Commits（本文は日本語）。`.godot/` は絶対にコミットしない
- 日本語テキストは `data/messages.json`、ゲーム内容は `data/events.json`、GDScript はシステムだけ。二層の分岐は `MessageResolver.resolve` の中だけ
- 200 行超は分割を検討し、理由を PR に書く
- 素材（PNG／音声）は生成しない。必要なら `docs/ASSETS_NEEDED.md` に追記する
