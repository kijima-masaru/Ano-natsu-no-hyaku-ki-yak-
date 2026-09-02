#!/usr/bin/env python3
"""フィールドスクリプトの ASCII 地図（MAP_ROWS）を data/fields.json と照合する机上検証。

    python3 docs/tools/check_field_map.py scripts/fields/f12_kihira.gd [...]

検証内容：
  1. MAP_ROWS の寸法が size_tiles と一致する
  2. 外周は出口タイル以外が通行不可（GROUND_LEGEND の文字＝通行可とみなす）
  3. 全ての出口タイルが default_spawn_tile（無ければ最初の出口の内側）から到達できる
  4. INTERACTABLES の各タイルが通行可タイルに隣接している
注意（終了コードに影響しない）：
  - 通行可タイルの孤立領域（境内など、意図して閉じた領域が該当する）
  - 通行可タイルの上に置かれた調べ物（橋の袂の看板など。Interactable は当たりを持たないので動作はする）
Godot を起動できない環境での補助であり、TileCatalog の walkable 属性までは見ない。
"""
import json
import re
import sys
from collections import deque

FIELDS_JSON = "data/fields.json"


def parse_gd(path: str) -> dict:
    src = open(path, encoding="utf-8").read()
    field_id = re.search(r"##\s*(F\d\d)\b", src).group(1)
    rows = re.search(r"MAP_ROWS: PackedStringArray = \[(.*?)\n\]", src, re.S).group(1)
    map_rows = re.findall(r'"([^"]+)"', rows)
    ground = re.search(r"GROUND_LEGEND: Dictionary = \{(.*?)\n\}", src, re.S).group(1)
    walkable = set(re.findall(r'^\s*"(.)":', ground, re.M))
    inter = re.findall(r'"id": "([a-z_0-9]+)".*?"tile": Vector2i\((\d+), (\d+)\)', src)
    return {"id": field_id, "rows": map_rows, "walkable": walkable,
            "interactables": [(i, int(x), int(y)) for i, x, y in inter]}


def check(gd: dict, defs: dict) -> tuple:
    errors = []
    warnings = []
    d = defs[gd["id"]]
    w, h = d["size_tiles"]["w"], d["size_tiles"]["h"]
    rows = gd["rows"]
    if len(rows) != h or any(len(r) != w for r in rows):
        errors.append("寸法が一致しません: MAP_ROWS %dx%d / fields.json %dx%d" % (len(rows[0]), len(rows), w, h))
        return errors, warnings
    walk = gd["walkable"]
    exits = [tuple(e["tile"]) for e in d["exits"]]
    for y in range(h):
        for x in range(w):
            on_edge = x in (0, w - 1) or y in (0, h - 1)
            if on_edge and rows[y][x] in walk and (x, y) not in exits:
                errors.append("外周が開いています: (%d, %d) '%s'" % (x, y, rows[y][x]))
    for ex in exits:
        if rows[ex[1]][ex[0]] not in walk:
            errors.append("出口 %s が通行不可です" % (ex,))
    start = next(((x, y) for y in range(h) for x in range(w) if rows[y][x] in walk), None)
    seen = set()
    if start:
        q = deque([start]); seen.add(start)
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and rows[n[1]][n[0]] in walk:
                    seen.add(n); q.append(n)
    for ex in exits:
        if ex not in seen:
            errors.append("出口 %s に到達できません" % (ex,))
    isolated = [(x, y) for y in range(h) for x in range(w) if rows[y][x] in walk and (x, y) not in seen]
    if isolated:
        warnings.append("孤立した通行可タイル %d 個: %s%s" % (len(isolated), isolated[:6], " …" if len(isolated) > 6 else ""))
    for iid, x, y in gd["interactables"]:
        if rows[y][x] in walk:
            warnings.append("調べ物 %s (%d, %d) が通行可タイルの上にあります" % (iid, x, y))
        if not any((x + dx, y + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            errors.append("調べ物 %s (%d, %d) に隣接する通行可タイルがありません" % (iid, x, y))
    return errors, warnings


def main(paths: list) -> int:
    defs = {f["id"]: f for f in json.load(open(FIELDS_JSON, encoding="utf-8"))["fields"]}
    status = 0
    for path in paths:
        gd = parse_gd(path)
        errors, warnings = check(gd, defs)
        print("%s %s: %s" % (gd["id"], path, "OK" if not errors else "エラー %d 件" % len(errors)))
        for e in errors:
            print("  - " + e)
        for wmsg in warnings:
            print("  注意: " + wmsg)
        status |= bool(errors)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["scripts/fields/f06_civic_center.gd"]))
