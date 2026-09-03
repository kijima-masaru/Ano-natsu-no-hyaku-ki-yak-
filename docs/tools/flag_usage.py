#!/usr/bin/env python3
"""フラグの棚卸し：docs/FLAGS.md の定義、data/*.json とコードでの set / 参照を突き合わせ、
「立つが参照されない」「参照されるが立たない」「FLAGS.md に無い」を一覧にする（ステップ5 タスク8／12）。
使い方：python3 docs/tools/flag_usage.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(name):
    with open(os.path.join(ROOT, "data", name + ".json"), encoding="utf-8") as f:
        return json.load(f)


FIELD_UNLOCK = {}


def walk_actions(actions, setter, getter):
    for a in actions or []:
        t = a.get("type")
        if t == "set_flag":
            setter(a.get("flag", ""))
        elif t == "unlock_field":
            setter(FIELD_UNLOCK.get(a.get("field", ""), ""))
        elif t == "end_game":
            setter(a.get("ending", ""))
        elif t == "choice":
            for o in a.get("options", []):
                if o.get("set_flag"):
                    setter(o["set_flag"])
                walk_actions(o.get("actions"), setter, getter)
        elif t == "branch":
            walk_conditions(a.get("conditions"), getter)
            walk_actions(a.get("then"), setter, getter)
            walk_actions(a.get("else"), setter, getter)


def walk_conditions(conds, getter):
    if isinstance(conds, dict):
        conds = [conds]
    for c in conds or []:
        if not isinstance(c, dict):
            continue
        for k in ("flag", "not_flag"):
            if c.get(k):
                getter(c[k])
        for k in ("flags", "not_flags", "any_flags", "all_flags"):
            for f in c.get(k, []) or []:
                getter(f)
        if c.get("type") in ("flag", "not_flag") and c.get("id"):
            getter(c["id"])
        for k in ("any", "all"):
            walk_conditions(c.get(k), getter)
        if isinstance(c.get("not"), (dict, list)):
            walk_conditions(c.get("not"), getter)


def main():
    defined = set()
    flags_md = os.path.join(ROOT, "docs", "FLAGS.md")
    for m in re.finditer(r"^\| `([A-Za-z0-9_<>]+)`", open(flags_md, encoding="utf-8").read(), re.M):
        defined.add(m.group(1))
    setters, getters = {}, {}
    for fld in load("fields")["fields"]:
        if fld.get("unlock_flag"):
            FIELD_UNLOCK[fld["id"]] = fld["unlock_flag"]

    def add(d, flag, where):
        if flag:
            d.setdefault(flag, set()).add(where)

    for e in load("events")["events"]:
        eid = e["id"]
        walk_conditions(e.get("conditions"), lambda f: add(getters, f, "events:" + eid))
        walk_actions(e.get("actions"), lambda f: add(setters, f, "events:" + eid), lambda f: add(getters, f, "events:" + eid))
        if e.get("once", False):
            add(setters, "ev_done_" + eid, "events(once)")
    for a in load("anomalies")["anomalies"]:
        aid = a["id"]
        walk_conditions(a.get("conditions"), lambda f: add(getters, f, "anomalies:" + aid))
        for f in a.get("set_flags", []) or []:
            add(setters, f, "anomalies:" + aid)
        if a.get("set_flag"):
            add(setters, a["set_flag"], "anomalies:" + aid)
        walk_actions(a.get("actions"), lambda f: add(setters, f, "anomalies:" + aid), lambda f: add(getters, f, "anomalies:" + aid))
        for st in a.get("stages", []) or []:
            walk_actions(st.get("actions"), lambda f: add(setters, f, "anomalies:" + aid), lambda f: add(getters, f, "anomalies:" + aid))
            for f in st.get("set_flags", []) or []:
                add(setters, f, "anomalies:" + aid)
    for day in load("schedule")["days"]:
        d = "schedule:%s" % day.get("day")
        for f in day.get("set_flags_on_start", []) or []:
            add(setters, f, d)
        for f in day.get("clear_flags_on_start", []) or []:
            add(setters, f, d)
        for f in day.get("set_flags_on_end", []) or []:
            add(setters, f, d)
        for f in day.get("required_flags", []) or []:
            add(getters, f, d)
        walk_conditions(day.get("sleep_conditions"), lambda f: add(getters, f, d))
        walk_conditions(day.get("conditions"), lambda f: add(getters, f, d))
    for fld in load("fields")["fields"]:
        if fld.get("unlock_flag"):
            add(getters, fld["unlock_flag"], "fields:" + fld["id"])
        for ex in fld.get("exits", []) or []:
            lock = ex.get("lock")
            if isinstance(lock, dict) and lock.get("flag"):
                add(getters, lock["flag"], "fields:" + fld["id"])
            elif isinstance(lock, str) and lock:
                add(getters, lock, "fields:" + fld["id"])
    # コード
    for dp, _, files in os.walk(os.path.join(ROOT, "scripts")):
        if "tools" in dp:
            continue
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            path = os.path.join(dp, fn)
            src = open(path, encoding="utf-8").read()
            rel = os.path.relpath(path, ROOT)
            consts = dict(re.findall(r"const ([A-Z_]+): String = \"([a-z0-9_]+)\"", src))
            for m in re.finditer(r"raise_flag\(\"([a-z0-9_]+)\"\)", src):
                add(setters, m.group(1), rel)
            for m in re.finditer(r"raise_flag\(([A-Z_]+)\)", src):
                if m.group(1) in consts:
                    add(setters, consts[m.group(1)], rel)
            for m in re.finditer(r"has_flag\(\"([a-z0-9_]+)\"\)", src):
                add(getters, m.group(1), rel)
            for m in re.finditer(r"const [A-Z_]+_FLAG: String = \"([a-z0-9_]+)\"", src):
                add(getters, m.group(1), rel + "(const)")
    # ev_done_ / seen_ は機構が立てる。集計からは外し、参照だけ見る
    evidence_ids = {e["id"] for e in load("evidence")["evidence"]}

    def family(f):
        if f.startswith("ev_") and f[3:] in evidence_ids:
            return True  # GameState.add_evidence が立てる ev_<evidence_id>
        return f.startswith("ev_done_") or f.startswith("an_done_") or f.startswith("ev_day_") or f.startswith("seen_") or f.startswith("luck_") or f.startswith("hid_") or f.startswith("witnessed_") or f.startswith("visited_")
    all_flags = set(setters) | set(getters) | defined
    rows = []
    for f in sorted(all_flags):
        if family(f):
            continue
        s, g = setters.get(f, set()), getters.get(f, set())
        status = []
        if f not in defined:
            status.append("FLAGS.md に無い")
        if s and not g:
            status.append("立つが参照なし")
        if g and not s:
            status.append("参照されるが立たない")
        if not s and not g:
            status.append("定義のみ")
        if status:
            rows.append((f, "、".join(status), sorted(s)[:3], sorted(g)[:3]))
    print("フラグ %d（族を除く）、定義 %d、set %d、参照 %d" % (len([f for f in all_flags if not family(f)]), len(defined), len(setters), len(getters)))
    for f, st, s, g in rows:
        print("  %-28s %-20s set=%s get=%s" % (f, st, ",".join(s) or "-", ",".join(g) or "-"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
