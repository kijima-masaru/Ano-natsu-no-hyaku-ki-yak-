# フォント

このディレクトリに **PixelMplus12** のフォントファイルを置く。

| ファイル名（固定） | 用途 |
|---|---|
| `PixelMplus12-Regular.ttf` | メッセージウィンドウ・UI 全般 |
| `PixelMplus12-Bold.ttf` | 見出し（任意） |

- 配布元から入手し、ライセンス条項（M+ FONT LICENSE 系）を `LICENSE-PixelMplus.txt` としてここに同梱する。
- Godot にインポートされたら、インポート設定で **Antialiasing = None**、**Hinting = None**、**Subpixel Positioning = Disabled** にする
  （`message_window.gd` は読み込み時にも同じ設定をコードで強制する）。
- ファイルが無い場合、`MessageWindow` は警告を出して代替フォントで動作し、画面右上に `[代替フォント]` と表示する。
