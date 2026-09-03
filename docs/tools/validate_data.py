#!/usr/bin/env python3
"""scripts/tools/validate_data.gd と同じ検査を Godot 無しで行う（CI とこの環境用）。

    python3 docs/tools/validate_data.py [--strict]

検査は GDScript 版（scripts/tools/data_checks_refs.gd / data_checks_fields.gd）と対応させて保つ。
片方に検査を足したら、もう片方にも足すこと。エラーがあれば終了コード 1。
"""
import json
import os
import re
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KNOWN_ACTIONS = {
    "message", "set_flag", "clear_flag", "give_item", "remove_item", "unlock_field", "move_player", "advance_day",
    "set_time", "add_points", "wait", "run_event", "end_game", "choice", "autosave", "set_companion", "start_stalker",
    "sleep", "give_evidence", "conceal_evidence", "show_concealment_reveal", "raise_suspicion", "play_sound",
    "play_bgm", "stop_bgm", "entity_speak", "entity_comfort", "entity_pulse", "switch_floor",
}
KNOWN_CONDITIONS = {"flag", "has_item", "field_visited", "day", "day_range", "time_of_day", "not", "any", "all",
                    "suspicion", "can_sleep", "floor"}
FLAG_PREFIXES = ("hid_", "hid_fail_", "ev_", "ev_done_", "day_", "seen_", "visited_", "luck_", "an_done_", "ev_day_")
ANOMALY_TRIGGERS = {"on_enter", "on_interact", "on_condition"}
ANOMALY_MODES = {"once", "repeat", "escalate"}
COMFORT_CONTEXTS = {"after_anomaly", "after_stalker", "night_walk", "yakushi_gate", "heroine_near"}
NEIGHBORS = ((1, 0), (-1, 0), (0, 1), (0, -1))


class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def error(self, cat, msg):
        self.errors.append("[%s] %s" % (cat, msg))

    def warn(self, cat, msg):
        self.warnings.append("[%s] %s" % (cat, msg))


def load(name):
    with open(os.path.join(ROOT, "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


def res(path):
    return os.path.join(ROOT, path.replace("res://", ""))


def id_set(items):
    return {str(i.get("id", "")) for i in items if isinstance(i, dict)}


def collect_flags(events, schedule):
    flags = set()
    for e in events:
        for a in e.get("actions", []):
            if a.get("type") in ("set_flag", "clear_flag"):
                flags.add(a.get("flag", ""))
            if a.get("type") == "choice":
                flags.update(o["set_flag"] for o in a.get("options", []) if "set_flag" in o)
    for d in schedule:
        for k in ("set_flags_on_start", "set_flags_on_end", "clear_flags_on_start"):
            flags.update(d.get(k, []))
    doc = os.path.join(ROOT, "docs", "FLAGS.md")
    if os.path.exists(doc):
        flags.update(re.findall(r"^\| `([A-Za-z0-9_<>]+)`", open(doc, encoding="utf-8").read(), re.M))
    return flags


def flag_known(flag, defined):
    return flag in defined or flag.startswith(FLAG_PREFIXES)


def check_condition(r, eid, c, ctx):
    if not isinstance(c, dict):
        r.error("events", "%s: 条件は Dictionary である必要があります" % eid); return
    for k in c:
        if k != "is" and k not in KNOWN_CONDITIONS:
            r.error("events", "%s: 条件キー '%s' は未定義です" % (eid, k))
    if "flag" in c and not flag_known(c["flag"], ctx["flags"]):
        r.error("events", "%s: 条件のフラグ '%s' はどこにも定義されていません（FLAGS.md か set_flag）" % (eid, c["flag"]))
    if "has_item" in c and c["has_item"] not in ctx["items"]:
        r.error("events", "%s: アイテム '%s' は items.json にありません" % (eid, c["has_item"]))
    if "field_visited" in c and c["field_visited"] not in ctx["fields"]:
        r.error("events", "%s: フィールド '%s' は存在しません" % (eid, c["field_visited"]))
    if "not" in c:
        check_condition(r, eid, c["not"], ctx)
    for k in ("any", "all"):
        for sub in c.get(k, []):
            check_condition(r, eid, sub, ctx)


def need_message(r, eid, mid, ctx):
    if mid not in ctx["messages"]:
        r.error("events", "%s: メッセージ '%s' は messages.json にありません" % (eid, mid))


def check_action(r, eid, a, ctx, event_ids):
    t = a.get("type", "")
    if t not in KNOWN_ACTIONS:
        r.error("events", "%s: アクション種別 '%s' は未登録です" % (eid, t))
    if t in ("message", "entity_speak"):
        need_message(r, eid, a.get("id", ""), ctx)
    elif t == "entity_comfort":
        need_message(r, eid, "msg_natsu_comfort_%s" % a.get("context", ""), ctx)
    elif t in ("give_item", "remove_item"):
        if a.get("item") not in ctx["items"]:
            r.error("events", "%s: アイテム '%s' は items.json にありません" % (eid, a.get("item")))
    elif t in ("move_player", "unlock_field"):
        if a.get("field") and a["field"] not in ctx["fields"]:
            r.error("events", "%s: フィールド '%s' は存在しません" % (eid, a["field"]))
    elif t == "run_event":
        if a.get("id") not in event_ids:
            r.error("events", "%s: run_event の '%s' は存在しません" % (eid, a.get("id")))
    elif t in ("give_evidence", "conceal_evidence"):
        if a.get("evidence") not in ctx["evidence"]:
            r.error("events", "%s: 証拠 '%s' は evidence.json にありません" % (eid, a.get("evidence")))
    elif t in ("play_sound", "play_bgm"):
        if a.get("id") not in ctx["tracks"]:
            r.error("events", "%s: 音 '%s' は audio.json にありません" % (eid, a.get("id")))
    elif t == "choice":
        if "prompt_id" in a:
            need_message(r, eid, a["prompt_id"], ctx)
        for o in a.get("options", []):
            need_message(r, eid, o.get("text_id", ""), ctx)
            if "run_event" in o and o["run_event"] not in event_ids:
                r.error("events", "%s: 選択肢の run_event '%s' は存在しません" % (eid, o["run_event"]))


def check_events(r, events, ctx):
    event_ids = id_set(events)
    for e in events:
        eid = e.get("id", "")
        if e.get("field") and e["field"] not in ctx["fields"]:
            r.error("events", "%s: field '%s' は存在しません" % (eid, e["field"]))
        if e.get("trigger") == "on_day_start" and "day_range" not in e:
            r.error("events", "%s: on_day_start には day_range が必要です" % eid)
        for c in e.get("conditions", []):
            check_condition(r, eid, c, ctx)
        for a in e.get("actions", []):
            check_action(r, eid, a, ctx, event_ids)


def check_messages(r, messages, speakers):
    ids = {m["id"]: m for m in messages}
    for m in messages:
        mid = m["id"]
        if "truth_id" in m and m["truth_id"] not in ids:
            r.error("messages", "%s: truth_id '%s' が存在しません" % (mid, m["truth_id"]))
        if mid.endswith("_t"):
            base = mid[:-2]
            if base in ids and ids[base].get("truth_id") != mid:
                r.error("messages", "%s: 真相版があるのに '%s' に truth_id が付いていません" % (mid, base))
        if m.get("speaker", "") not in speakers:
            r.error("messages", "%s: 話者 '%s' は meta.speakers にありません" % (mid, m.get("speaker", "")))


def check_schedule(r, schedule, ctx, event_ids, strict):
    reachable = set()
    unimplemented_days = {}
    for d in schedule:
        day = d.get("day", 0)
        op = d.get("opening_event")
        if op and op not in event_ids:
            r.error("schedule", "day %d: opening_event '%s' は存在しません" % (day, op))
        for fid in d.get("available_fields", []):
            reachable.add(fid)
            if fid not in ctx["fields"]:
                r.error("schedule", "day %d: available_fields の '%s' は存在しません" % (day, fid))
            elif fid not in ctx["implemented"]:
                unimplemented_days.setdefault(fid, []).append(day)
    for fid in sorted(unimplemented_days):
        days = unimplemented_days[fid]
        (r.error if strict else r.warn)("schedule", "%s は未実装（シーン無し）ですが day %d〜%d の available_fields に含まれます" % (fid, min(days), max(days)))
    for fid in sorted(ctx["fields"]):
        if fid not in reachable:
            r.error("schedule", "%s はどの日の available_fields にも含まれず到達できません" % fid)


def check_evidence(r, evidence, ctx):
    for e in evidence:
        if e.get("field") and e["field"] not in ctx["fields"]:
            r.error("evidence", "%s: field '%s' は存在しません" % (e["id"], e["field"]))
        for k in ("title_id", "surface_id", "truth_id", "shown_id", "action_id"):
            if k in e and e[k] not in ctx["messages"]:
                r.error("evidence", "%s: %s '%s' は messages.json にありません" % (e["id"], k, e[k]))


def check_anomalies(r, anomalies, ctx, event_ids, targets):
    for a in anomalies:
        aid, field = a.get("id", ""), a.get("field", "")
        if field not in ctx["fields"]:
            r.error("anomalies", "%s: field '%s' は存在しません" % (aid, field))
        trig = a.get("trigger", "on_enter")
        if trig not in ANOMALY_TRIGGERS:
            r.error("anomalies", "%s: trigger '%s' は %s のいずれか" % (aid, trig, sorted(ANOMALY_TRIGGERS)))
        if trig == "on_interact" and field in targets and a.get("target", "") not in targets[field]:
            r.error("anomalies", "%s: target '%s' は %s の調べ物にありません" % (aid, a.get("target", ""), field))
        mode = a.get("mode", "once")
        if mode not in ANOMALY_MODES:
            r.error("anomalies", "%s: mode '%s' は %s のいずれか" % (aid, mode, sorted(ANOMALY_MODES)))
        if a.get("comfort") and a["comfort"] not in COMFORT_CONTEXTS:
            r.error("anomalies", "%s: comfort '%s' は未定義です" % (aid, a["comfort"]))
        for c in a.get("conditions", []):
            check_condition(r, aid, c, ctx)
        lists = [a.get("actions", [])]
        if mode == "escalate":
            lists = [st.get("actions", []) for st in a.get("stages", [])]
            if not lists:
                r.error("anomalies", "%s: escalate には stages が必要です" % aid)
        for acts in lists:
            if not acts:
                r.error("anomalies", "%s: actions が空です" % aid)
            for act in acts:
                check_action(r, aid, act, ctx, event_ids)


def check_fields(r, fields):
    by_id = {f["id"]: f for f in fields}
    implemented = set()
    for f in fields:
        if os.path.exists(res(f.get("scene_path", ""))):
            implemented.add(f["id"])
        else:
            # scripts/fields/fXX_*.gd があるのに scene_path のシーンが無い → 名前の不一致（プレースホルダ表示になる）
            stray = [g for g in os.listdir(os.path.join(ROOT, "scripts", "fields")) if g.startswith(f["id"].lower() + "_") and g.endswith(".gd")]
            if stray:
                r.error("fields", "%s: %s があるのに scene_path '%s' のシーンが無い（ファイル名を fields.json に合わせる）" % (f["id"], stray[0], f.get("scene_path")))
        for e in f.get("exits", []):
            to = e.get("to")
            if to not in by_id:
                r.error("fields", "%s: 出口の接続先 '%s' は存在しません" % (f["id"], to)); continue
            if not any(e2.get("to") == f["id"] for e2 in by_id[to].get("exits", [])):
                r.error("fields", "%s→%s があるのに %s→%s がありません（双方向でない）" % (f["id"], to, to, f["id"]))
    return implemented


def interactable_ids(text):
    """調べ物 id → kind。動的に出す NPC は kind を npc とする"""
    ids = {}
    for pid, kind in re.findall(r'"id": "([a-z_0-9]+)"[^\n]*?"kind": "([a-z_]+)"', text):
        ids[pid] = kind
    for pat in (r'set_npc_present\("([a-z_0-9]+)"', r'Interactable\.create\("([a-z_0-9]+)"', r'add_point_of_interest\("([a-z_0-9]+)"'):
        for pid in re.findall(pat, text):
            ids.setdefault(pid, "npc")
    return ids


def flood(rows, walk, start, w, h):
    seen = set()
    if start is None:
        return seen
    q = deque([start]); seen.add(start)
    while q:
        x, y = q.popleft()
        for dx, dy in NEIGHBORS:
            n = (x + dx, y + dy)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and rows[n[1]][n[0]] in walk:
                seen.add(n); q.append(n)
    return seen


def check_map(r, f, text):
    fid = f["id"]
    m = re.search(r"MAP_ROWS: PackedStringArray = \[([\s\S]*?)\n\]", text)
    if not m:
        r.warn("map", "%s: MAP_ROWS が見つかりません（独自の _build なら問題なし）" % fid); return
    rows = re.findall(r'"([^"]+)"', m.group(1))
    g = re.search(r"GROUND_LEGEND: Dictionary = \{([\s\S]*?)\n\}", text)
    walk = set(re.findall(r'"(.)":', g.group(1))) if g else set()
    w, h = f["size_tiles"]["w"], f["size_tiles"]["h"]
    if len(rows) != h or not rows or len(rows[0]) != w:
        r.error("map", "%s: MAP_ROWS %dx%d が size_tiles %dx%d と一致しません" % (fid, len(rows[0]) if rows else 0, len(rows), w, h)); return
    exits = {tuple(e["tile"]) for e in f.get("exits", [])}
    locked = {tuple(e["tile"]) for e in f.get("exits", []) if e.get("lock")}
    for y in range(h):
        for x in range(w):
            ch = rows[y][x]
            edge = x in (0, w - 1) or y in (0, h - 1)
            if edge and ch in walk and (x, y) not in exits:
                r.error("map", "%s: 外周 (%d, %d) '%s' が開いています" % (fid, x, y, ch))
    for ex in exits:
        if rows[ex[1]][ex[0]] not in walk:
            r.error("map", "%s: 出口 %s が通行不可です" % (fid, ex))
    # 主領域＝出口から辿れる最大の領域（施錠出口は落石などで塞がれていてよい）
    seen = set()
    for ex in sorted(exits):
        if rows[ex[1]][ex[0]] in walk:
            region = flood(rows, walk, ex, w, h)
            if len(region) > len(seen):
                seen = region
    for ex in exits:
        if ex not in seen:
            (r.warn if ex in locked else r.error)("map", "%s: 出口 %s に主領域から到達できません%s" % (fid, ex, "（施錠出口。フラグで開くなら可）" if ex in locked else ""))
    isolated = sum(1 for y in range(h) for x in range(w) if rows[y][x] in walk and (x, y) not in seen)
    if isolated:
        r.warn("map", "%s: 孤立した通行可タイル %d 個（意図した閉域なら可）" % (fid, isolated))
    block = re.search(r"\nconst INTERACTABLES: Array = \[(.*?)\n\]", text, re.S)
    for pid, x, y in re.findall(r'"id": "([a-z_0-9]+)"[^\n]*?"tile": Vector2i\((-?\d+), (-?\d+)\)', block.group(1) if block else ""):
        x, y = int(x), int(y)
        if not (0 <= x < w and 0 <= y < h):
            r.error("map", "%s: 調べ物 %s の座標 (%d, %d) がフィールド外です（雛形の未設定値も含む）" % (fid, pid, x, y)); continue
        if rows[y][x] in walk:
            r.warn("map", "%s: 調べ物 %s (%d, %d) が通行可タイルの上にあります" % (fid, pid, x, y))
        if not any((x + dx, y + dy) in seen for dx, dy in NEIGHBORS):
            r.error("map", "%s: 調べ物 %s (%d, %d) に隣接する通行可タイルがありません" % (fid, pid, x, y))


def check_maps(r, fields, implemented):
    targets = {}
    for f in fields:
        if f["id"] not in implemented:
            continue
        path = os.path.join(ROOT, "scripts", "fields", os.path.splitext(os.path.basename(f["scene_path"]))[0] + ".gd")
        if not os.path.exists(path):
            r.warn("map", "%s: %s が無いため地図の検査を飛ばします" % (f["id"], path)); continue
        text = open(path, encoding="utf-8").read()
        targets[f["id"]] = interactable_ids(text)
        check_map(r, f, text)
    return targets


def check_targets(r, events, targets):
    used = set()
    for e in events:
        if e.get("trigger") != "on_interact" or not e.get("field") or e["field"] not in targets:
            continue
        used.add((e["field"], e.get("target", "")))
        if e.get("target", "") not in targets[e["field"]]:
            r.error("events", "%s: target '%s' は %s の調べ物にありません" % (e["id"], e.get("target"), e["field"]))
    for fid, pois in targets.items():
        for poi in sorted(pois):
            if pois[poi] == "save_point":  # セーブ地点は Main が直接扱う
                continue
            if (fid, poi) not in used:
                r.warn("events", "%s: 調べ物 '%s' に on_interact イベントがありません（msg_nothing_here が出ます）" % (fid, poi))


def check_points(r, schedule, events):
    for d in schedule:
        if d.get("type") != "free":
            continue
        day, required = d["day"], d.get("advance_condition", {}).get("points", 0)
        avail = d.get("available_fields", [])
        supply, repeatable = 0, []
        for e in events:
            if not any(a.get("type") == "add_points" for a in e.get("actions", [])):
                continue
            if e.get("field") and e["field"] not in avail:
                continue
            rng = e.get("day_range")
            if rng and not (rng[0] <= day <= rng[1]):
                continue
            if not e.get("once", False) and not e.get("daily", False):
                repeatable.append(e["id"])
            supply += 1
        for rid in repeatable:
            r.error("points", "%s は once=false なのに add_points を持ち、無限に P を得られます" % rid)
        if supply < required:
            r.warn("points", "day %d: 調査 P の供給源 %d < 必要 %d（初訪問ボーナスを除く）" % (day, supply, required))


def main(argv):
    strict = "--strict" in argv
    r = Report()
    fields = load("fields")["fields"]; events = load("events")["events"]; msgs = load("messages")
    schedule = load("schedule")["days"]; evidence = load("evidence")["evidence"]
    ctx = {"fields": id_set(fields), "messages": id_set(msgs["messages"]), "items": id_set(load("items")["items"]),
           "evidence": id_set(evidence), "tracks": id_set(load("audio")["tracks"]), "flags": collect_flags(events, schedule)}
    ctx["implemented"] = check_fields(r, fields)
    check_events(r, events, ctx)
    check_messages(r, msgs["messages"], msgs.get("meta", {}).get("speakers", {}))
    check_schedule(r, schedule, ctx, id_set(events), strict)
    check_evidence(r, evidence, ctx)
    targets = check_maps(r, fields, ctx["implemented"])
    check_targets(r, events, targets)
    check_anomalies(r, load("anomalies")["anomalies"], ctx, id_set(events), targets)
    check_points(r, schedule, events)
    for f in fields:
        if f.get("ambience_track") and f["ambience_track"] not in ctx["tracks"]:
            r.error("audio", "%s: ambience_track '%s' は audio.json にありません" % (f["id"], f["ambience_track"]))
    for w in r.warnings:
        print("注意 " + w)
    for e in r.errors:
        print("エラー " + e, file=sys.stderr)
    print("エラー %d 件・注意 %d 件" % (len(r.errors), len(r.warnings)))
    return 1 if r.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
