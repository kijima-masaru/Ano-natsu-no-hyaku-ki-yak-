"""定義（tools/audio/defs/*.py）から全音声を生成する。
使い方：python3 tools/audio/build.py [--only id] [--kind bgm|ambience|se] [--check] [--list]
出力：assets/audio/<kind>/<id>.ogg と assets/audio/manifest.json。--check でループ確認用に 3 周連結した WAV を build/audio_check/ に出す。
各定義は {"id", "kind", "loop", "stereo", "seconds", "seed", "render": fn(rng) -> ndarray, "note", ...}。乱数は id ごとに固定シード。
"""
from __future__ import annotations

import argparse
import importlib
import json
import os
import pkgutil
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import master  # noqa: E402
import synth  # noqa: E402

OUT = os.path.join(ROOT, "assets", "audio")
CHECK = os.path.join(ROOT, "build", "audio_check")


def load_defs() -> list[dict]:
    import defs
    out = []
    for m in pkgutil.iter_modules(defs.__path__):
        mod = importlib.import_module(f"defs.{m.name}")
        for d in getattr(mod, "DEFS", []):
            d = dict(d)
            d.setdefault("module", m.name)
            out.append(d)
    ids = [d["id"] for d in out]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        raise SystemExit(f"ID が重複: {sorted(dup)}")
    return sorted(out, key=lambda d: (d["kind"], d["id"]))


def seed_of(d: dict) -> int:
    if "seed" in d:
        return int(d["seed"])
    return int.from_bytes(d["id"].encode("utf-8"), "little") % (2 ** 31)


def build_one(d: dict, check: bool) -> dict:
    rng = np.random.default_rng(seed_of(d))
    t0 = time.time()
    x = d["render"](rng)
    y, info = master.finalize(x, d["kind"], bool(d.get("loop", d["kind"] != "se")), bool(d.get("stereo", d["kind"] != "se")),
                              d.get("fade_in", 0.0), d.get("fade_out", 0.0), d.get("crossfade", 0.5), float(d.get("lufs_offset", 0.0)))
    path = os.path.join(OUT, d["kind"], d["id"] + ".ogg")
    master.write_ogg(path, y, d["kind"])
    if check and d.get("loop", d["kind"] != "se"):
        master.write_wav(os.path.join(CHECK, d["id"] + "_x3.wav"), np.concatenate([y, y, y]))
    entry = {"id": d["id"], "kind": d["kind"], "path": os.path.relpath(path, ROOT), "loop": bool(d.get("loop", d["kind"] != "se")),
             "stereo": y.ndim == 2, "seconds": round(info["seconds"], 3), "lufs": round(info["lufs"], 2), "target_lufs": round(info["target_lufs"], 2), "peak_dbfs": round(info["peak_dbfs"], 2),
             "bytes": os.path.getsize(path), "seed": seed_of(d), "module": d["module"], "note": d.get("note", ""), "use": d.get("use", ""),
             "render_sec": round(time.time() - t0, 2)}
    for k in ("allow_silence", "field", "time_of_day", "layer", "material", "status"):
        if k in d:
            entry[k] = d[k]
    return entry


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", action="append", default=None)
    ap.add_argument("--kind", default=None)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args(argv)
    defs = load_defs()
    if a.kind:
        defs = [d for d in defs if d["kind"] == a.kind]
    if a.only:
        defs = [d for d in defs if d["id"] in a.only]
    if a.list:
        for d in defs:
            print(f"{d['kind']:8s} {d['id']:32s} {d.get('seconds', '?')}s  {d.get('note', '')}")
        return 0
    mpath = os.path.join(OUT, "manifest.json")
    manifest = {"files": []}
    if os.path.exists(mpath):
        manifest = json.load(open(mpath, encoding="utf-8"))
    by_id = {e["id"]: e for e in manifest["files"]}
    for d in defs:
        e = build_one(d, a.check)
        by_id[e["id"]] = e
        print(f"{e['kind']:8s} {e['id']:32s} {e['seconds']:7.2f}s lufs {e['lufs']:6.1f} peak {e['peak_dbfs']:5.1f} {e['bytes'] // 1000:5d}KB ({e['render_sec']}s)")
    manifest["files"] = sorted(by_id.values(), key=lambda e: (e["kind"], e["id"]))
    manifest["sample_rate"] = synth.SR
    manifest["targets"] = master.TARGET_LUFS
    json.dump(manifest, open(mpath, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{len(defs)} 件を生成、manifest {len(manifest['files'])} 件")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
