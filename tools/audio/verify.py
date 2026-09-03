"""生成物の検証。ピーク、ラウドネス、長さ、DC オフセット、無音、ループの継ぎ目、チャンネル数・レート、ffmpeg での復号。
使い方：python3 tools/audio/verify.py [assets/audio] [--json out.json] [--strict]
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from master import PEAK_DBFS, TARGET_LUFS, loudness_lufs, peak_dbfs, probe_with_ffmpeg  # noqa: E402
from synth import SR, n_samples  # noqa: E402

LUFS_TOLERANCE = 1.5
SIZE_LIMIT = {"bgm": 2_000_000, "ambience": 1_000_000, "se": 100_000}


def kind_of(path: str) -> str:
    return os.path.basename(os.path.dirname(path))


def load_manifest(root: str) -> dict:
    p = os.path.join(root, "manifest.json")
    if os.path.exists(p):
        return {e["id"]: e for e in json.load(open(p, encoding="utf-8"))["files"]}
    return {}


def loop_seam_score(x: np.ndarray) -> float:
    """3 周連結し、継ぎ目前後 20 ms の RMS 差（dB）と、継ぎ目のサンプル段差から「継ぎ目の目立ちやすさ」を出す。小さいほど良い"""
    m = x if x.ndim == 1 else x.mean(axis=1)
    x3 = np.concatenate([m, m, m])
    n = len(m)
    w = n_samples(0.02)
    scores = []
    for seam in (n, 2 * n):
        before = x3[seam - w:seam]
        after = x3[seam:seam + w]
        rb, ra = np.sqrt(np.mean(before ** 2) + 1e-12), np.sqrt(np.mean(after ** 2) + 1e-12)
        level_jump = abs(20 * np.log10(rb / ra))
        # 継ぎ目の段差を、信号の通常の隣接差（中央値）と比べる。ノイズ系でも連続なら 1 前後になる
        typical = np.median(np.abs(np.diff(m))) + 1e-9
        step_ratio = abs(float(x3[seam] - x3[seam - 1])) / typical
        scores.append(level_jump + max(0.0, step_ratio - 4.0) * 0.5)
    return float(max(scores))


def silence_fraction(x: np.ndarray, thresh_db: float = -70.0) -> float:
    m = x if x.ndim == 1 else np.abs(x).max(axis=1)
    w = n_samples(0.05)
    if len(m) < w:
        return 0.0
    blocks = m[: len(m) // w * w].reshape(-1, w)
    rms = np.sqrt(np.mean(blocks ** 2, axis=1) + 1e-20)
    return float(np.mean(20 * np.log10(rms) < thresh_db))


def check_file(path: str, manifest: dict, strict: bool) -> dict:
    kind = kind_of(path)
    ident = os.path.splitext(os.path.basename(path))[0]
    x, sr = sf.read(path, dtype="float32", always_2d=True)
    meta = manifest.get(ident, {})
    loop = bool(meta.get("loop", kind != "se"))
    problems, warnings = [], []
    if sr != SR:
        problems.append(f"レート {sr}")
    channels = x.shape[1]
    want_stereo = kind in ("bgm", "ambience")
    if want_stereo and channels != 2:
        problems.append(f"ステレオであるべき（{channels}ch）")
    if kind == "se" and channels != 1:
        problems.append(f"モノであるべき（{channels}ch）")
    pk = peak_dbfs(x)
    if pk > PEAK_DBFS + 0.05:
        problems.append(f"ピーク {pk:.1f} dBFS > {PEAK_DBFS}")
    lufs = loudness_lufs(x)
    target = TARGET_LUFS[kind]
    if np.isfinite(lufs) and abs(lufs - target) > LUFS_TOLERANCE:
        problems.append(f"ラウドネス {lufs:.1f} LUFS（目標 {target}）")
    dc = float(np.abs(x.mean(axis=0)).max())
    if dc > 0.01:
        problems.append(f"DC オフセット {dc:.3f}")
    sil = silence_fraction(x)
    if meta.get("allow_silence") is not True and sil > 0.5:
        problems.append(f"無音が {sil * 100:.0f}%")
    elif sil > 0.2 and meta.get("allow_silence") is not True:
        warnings.append(f"無音 {sil * 100:.0f}%")
    seam = None
    if loop:
        seam = loop_seam_score(x)
        if seam > 4.0:
            problems.append(f"ループの継ぎ目 {seam:.1f}")
        elif seam > 2.5:
            warnings.append(f"継ぎ目 {seam:.1f}")
    size = os.path.getsize(path)
    if size > SIZE_LIMIT[kind]:
        (problems if strict else warnings).append(f"サイズ {size / 1000:.0f} KB > {SIZE_LIMIT[kind] / 1000:.0f} KB")
    dec = probe_with_ffmpeg(path)
    if dec != "ok" and dec != "ffmpeg 無し":
        problems.append(f"ffmpeg 復号 {dec}")
    if meta.get("seconds") and abs(meta["seconds"] - len(x) / sr) > 0.05:
        problems.append(f"長さ {len(x) / sr:.2f}s（定義 {meta['seconds']}）")
    return {"id": ident, "kind": kind, "seconds": round(len(x) / sr, 3), "channels": channels, "peak_dbfs": round(pk, 2),
            "lufs": round(lufs, 2) if np.isfinite(lufs) else None, "dc": round(dc, 4), "silence": round(sil, 3),
            "seam": round(seam, 2) if seam is not None else None, "bytes": size, "loop": loop, "ffmpeg": dec,
            "problems": problems, "warnings": warnings}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default="assets/audio")
    ap.add_argument("--json", default=None)
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--only", default=None)
    a = ap.parse_args(argv)
    files = sorted(glob.glob(os.path.join(a.root, "*", "*.ogg")))
    if a.only:
        files = [f for f in files if os.path.splitext(os.path.basename(f))[0] == a.only]
    manifest = load_manifest(a.root)
    results = [check_file(f, manifest, a.strict) for f in files]
    bad = 0
    for r in results:
        flag = "NG" if r["problems"] else ("warn" if r["warnings"] else "ok")
        bad += bool(r["problems"])
        print(f"{flag:4s} {r['kind']:8s} {r['id']:32s} {r['seconds']:7.2f}s {r['channels']}ch peak {r['peak_dbfs']:6.1f} lufs {str(r['lufs']):6s} seam {str(r['seam']):5s} {r['bytes'] // 1000:5d}KB  {' / '.join(r['problems'] + r['warnings'])}")
    print(f"{len(results)} 件、問題 {bad} 件")
    if a.json:
        json.dump(results, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
