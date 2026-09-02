#!/usr/bin/env python3
"""data/fields.json を docs/tools/world_minimap.template.html に埋め込み、
単一ファイルの docs/tools/world_minimap.html を生成する。"""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
data = json.loads((root / "data/fields.json").read_text(encoding="utf-8"))
tpl = (root / "docs/tools/world_minimap.template.html").read_text(encoding="utf-8")
out = tpl.replace("__FIELDS_JSON__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
(root / "docs/tools/world_minimap.html").write_text(out, encoding="utf-8")
print("wrote", root / "docs/tools/world_minimap.html", len(out), "bytes")
