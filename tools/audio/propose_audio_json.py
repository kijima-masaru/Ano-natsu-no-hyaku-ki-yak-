"""manifest.json から data/audio.json に登録するトラック定義の案を書き出す（data/ は変更しない）。

出力：build/audio_json_proposal.json
  - 既存 ID はそのまま（synth を残す。OGG があれば AudioManager が優先する）
  - 新 ID は {"id", "kind", "loop", "base_volume_db": 0.0} に、manifest の note を "note" として付ける
  - 蝉レイヤー（layer=cicada）は "seasonal": "cicada"
  - 統合時は data/audio.json の tracks をこの配列で置き換える（機械的）
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def main() -> int:
    manifest = json.load(open(os.path.join(ROOT, "assets", "audio", "manifest.json"), encoding="utf-8"))["files"]
    current = json.load(open(os.path.join(ROOT, "data", "audio.json"), encoding="utf-8"))
    existing = {t["id"]: t for t in current["tracks"]}
    tracks = []
    seen = set()
    for t in current["tracks"]:
        tracks.append(t)
        seen.add(t["id"])
    added = []
    for e in sorted(manifest, key=lambda e: (e["kind"], e["id"])):
        if e["id"] in seen:
            continue
        t = {"id": e["id"], "kind": e["kind"], "loop": bool(e["loop"]), "base_volume_db": 0.0, "note": e.get("note", "")}
        if e.get("layer") == "cicada":
            t["seasonal"] = "cicada"
        tracks.append(t)
        added.append(e["id"])
    missing = [i for i in existing if not any(e["id"] == i for e in manifest)]
    out = {"meta": dict(current["meta"], note=current["meta"].get("note", "") + "／OGG は assets/audio/<kind>/<id>.ogg（tools/audio/README.md）"), "tracks": tracks}
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    path = os.path.join(ROOT, "build", "audio_json_proposal.json")
    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{path}: 既存 {len(existing)} + 追加 {len(added)} = {len(tracks)} 件")
    if missing:
        print("manifest に無い既存 ID:", ", ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
