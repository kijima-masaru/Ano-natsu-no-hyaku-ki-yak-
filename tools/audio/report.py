"""verify の JSON から docs/AUDIO_VERIFY.md（全生成物の検証記録）を書く。

使い方: python3 tools/audio/verify.py --json build/audio_verify.json && python3 tools/audio/report.py
"""
import json
import os
import sys
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def main() -> int:
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "audio_verify.json")
    rows = json.load(open(src, encoding="utf-8"))
    manifest = {e["id"]: e for e in json.load(open(os.path.join(ROOT, "assets", "audio", "manifest.json"), encoding="utf-8"))["files"]}
    rows = rows["results"] if isinstance(rows, dict) and "results" in rows else rows
    by_kind = {}
    for r in rows:
        by_kind.setdefault(r["kind"], []).append(r)
    ng = [r for r in rows if r.get("problems")]
    warn = [r for r in rows if r.get("warnings") and not r.get("problems")]
    total_bytes = sum(int(manifest.get(r["id"], {}).get("bytes", 0)) for r in rows)
    lines = [f"# 音声素材の検証記録", "", f"`tools/audio/verify.py` の結果（{date.today().isoformat()}）。再生成・再検証の手順は `tools/audio/README.md`。", "",
             f"- 件数 {len(rows)}（" + "、".join(f"{k} {len(v)}" for k, v in sorted(by_kind.items())) + f"）、合計 {total_bytes / 1024 / 1024:.1f} MB",
             f"- 問題 {len(ng)} 件、注意 {len(warn)} 件", "",
             "検査項目：44.1 kHz／チャンネル数（BGM・環境音ステレオ、SE モノ）／ピーク -3 dBFS 以下／ラウドネスが manifest の目標 ±1.5 LU／DC・端の非ゼロ／無音率／ループの継ぎ目（3 周連結、他所の 95% 点比で 2.0 未満、1.2 超は注意）／サイズ上限／ffmpeg で復号できること／長さが manifest と一致。", ""]
    for kind, rs in sorted(by_kind.items()):
        lines += [f"## {kind}（{len(rs)}）", "", "| ID | 秒 | ch | ピーク dBFS | LUFS | 目標 | 継ぎ目 | KB | 結果 |", "|---|---|---|---|---|---|---|---|---|"]
        for r in sorted(rs, key=lambda r: r["id"]):
            m = manifest.get(r["id"], {})
            seam = r.get("seam")
            status = "NG " + " / ".join(r["problems"]) if r.get("problems") else ("注意 " + " / ".join(r["warnings"]) if r.get("warnings") else "ok")
            lines.append(f"| `{r['id']}` | {r.get('seconds', 0):.2f} | {r.get('channels', '')} | {r.get('peak_dbfs', 0):.1f} | {r.get('lufs') if r.get('lufs') is not None else '—'} | {m.get('target_lufs', '')} | {seam if seam is not None else '—'} | {int(m.get('bytes', 0)) // 1024} | {status} |")
        lines.append("")
    path = os.path.join(ROOT, "docs", "AUDIO_VERIFY.md")
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print(path, len(rows), "件、問題", len(ng), "件、注意", len(warn), "件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
