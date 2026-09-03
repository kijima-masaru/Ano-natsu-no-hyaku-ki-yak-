# フォント

このディレクトリに **PixelMplus12** のフォントファイルを置く（**配置済み**。配布元 https://github.com/itouhiro/PixelMplus の PixelMplus-20130602.zip、ライセンスは `LICENSE-PixelMplus.txt`）。

| ファイル名（固定） | 用途 |
|---|---|
| `PixelMplus12-Regular.ttf` | メッセージウィンドウ・UI 全般 |
| `PixelMplus12-Bold.ttf` | 見出し（任意） |

- 配布元から入手し、ライセンス条項（M+ FONT LICENSE 系）を `LICENSE-PixelMplus.txt` としてここに同梱する。
- 取り込み設定（`.import`）はコミットしないので、`UiFont` autoload（`scripts/autoload/ui_font.gd`）が読み込み時に **Antialiasing = None**、**Hinting = None**、**Subpixel Positioning = Disabled** を強制し、`ThemeDB.fallback_font` と既定テーマの `default_font` に設定する。`gui/theme/custom_font` も同じファイルを指す。
- ファイルが無い場合、`UiFont` は何もせず、`DialogueWindow` は警告を出して代替フォントで動作する。
