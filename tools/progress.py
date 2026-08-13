#!/usr/bin/env python3
"""Live progress page for the gauntlet loop.

State lives in runs/state.json; progress.html is regenerated from it every time.

  python3 tools/progress.py init
  python3 tools/progress.py update P1 --status judging --note "round 2 building"
  python3 tools/progress.py round P1 --ours runs/P1/r2/ours.png \
      --ref refs/screens/dungeon_interior_01.png --ab runs/P1/r2/ab.png \
      --call ref --gap "shadows are too dark and too sharp"
  python3 tools/progress.py log "P4 builder dispatched"
"""

import argparse
import datetime
import html
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE = os.path.join(ROOT, "runs", "state.json")
OUT = os.path.join(ROOT, "progress.html")

PIECES = [
    ("P1", "Camera", "OOT third-person rig: distance, lag, auto-swing, wall handling, recenter"),
    ("P2", "Hero &amp; movement", "Walk/run ramp, turn, roll, backflip, sidehop, animation blend"),
    ("P3", "Z-targeting", "Acquire, reticle, letterbox, strafe, lock camera, break rules"),
    ("P4", "Sword &amp; shield", "Slash set, jump attack, spin, hitstop, knockback, block cone"),
    ("P5", "Bow", "First-person aim, arrow arc, ammo, nocking feel"),
    ("P6", "Bombs", "Fuse, blast, self-damage, physics, bombable walls"),
    ("P7", "Hookshot", "Chain travel, grab, pull hero vs pull object, valid targets"),
    ("P8", "Dungeon look", "N64 stone architecture, torch lighting, fog, materials"),
    ("P9", "Dungeon graph", "Cyclic layout, small keys, locked doors, item gate, boss key"),
    ("P10", "Enemies", "Roster, AI, targetable, telegraphs, death"),
    ("P11", "Boss", "Arena, phases, telegraphs, item-tied vulnerability"),
    ("P12", "HUD", "Health points, magic, C-buttons, rupees, reticle, minimap"),
    ("P13", "Feel &amp; audio", "Hitstop, shake, footsteps, sfx, music, transitions"),
    ("P14", "Pause menu", "Escape menu, save slots, audio/graphics/control options"),
]

STATUS_ORDER = ["pending", "building", "judging", "revising", "passed"]


def now():
    return datetime.datetime.now().strftime("%H:%M:%S")


def load():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {"pieces": {}, "log": [], "started": now()}


def save(s):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(s, f, indent=2)
    render(s)


def piece(s, pid):
    return s["pieces"].setdefault(
        pid, {"status": "pending", "round": 0, "note": "", "gap": "", "rounds": []}
    )


# --- commands ---------------------------------------------------------------

def cmd_init(a):
    s = load()
    for pid, _, _ in PIECES:
        piece(s, pid)
    s["log"].insert(0, {"t": now(), "msg": "gauntlet initialised"})
    save(s)


def cmd_update(a):
    s = load()
    p = piece(s, a.pid)
    if a.status:
        p["status"] = a.status
    if a.note is not None:
        p["note"] = a.note
    if a.round is not None:
        p["round"] = a.round
    if a.gap is not None:
        p["gap"] = a.gap
    s["log"].insert(0, {"t": now(), "msg": "%s → %s %s" % (a.pid, p["status"], a.note or "")})
    save(s)


def cmd_round(a):
    s = load()
    p = piece(s, a.pid)
    p["round"] = a.n if a.n is not None else p["round"] + 1
    p["rounds"].insert(0, {
        "n": p["round"], "t": now(),
        "ours": a.ours, "ref": a.ref, "ab": a.ab,
        "call": a.call or "", "gap": a.gap or "", "verdict": a.verdict or "",
    })
    if a.gap:
        p["gap"] = a.gap
    if a.status:
        p["status"] = a.status
    s["log"].insert(0, {
        "t": now(),
        "msg": "%s round %d judged — critic picked %s" % (a.pid, p["round"], a.call or "?"),
    })
    save(s)


def cmd_log(a):
    s = load()
    s["log"].insert(0, {"t": now(), "msg": a.msg})
    save(s)


def cmd_render(a):
    render(load())


# --- rendering --------------------------------------------------------------

CSS = """
*{box-sizing:border-box}
body{margin:0;background:#0e0e11;color:#e8e8ee;
 font:14px/1.55 ui-sans-serif,-apple-system,"SF Pro Text",Inter,system-ui,sans-serif}
a{color:inherit}
header{padding:26px 30px 18px;border-bottom:1px solid #24242c;
 display:flex;align-items:baseline;gap:16px;flex-wrap:wrap}
h1{margin:0;font-size:19px;letter-spacing:.28px;font-weight:640}
.sub{color:#8a8a99;font-size:12.5px}
.bar{margin-left:auto;display:flex;gap:7px;align-items:center}
.wrap{padding:22px 30px 60px;max-width:1500px}
.piece{border:1px solid #24242c;border-radius:11px;margin-bottom:14px;
 background:#131318;overflow:hidden}
.phead{display:flex;align-items:center;gap:13px;padding:13px 17px;cursor:pointer;
 user-select:none}
.phead:hover{background:#17171d}
.pid{font:600 11.5px ui-monospace,SFMono-Regular,Menlo,monospace;color:#6f6f80;
 min-width:24px}
.pname{font-weight:600;font-size:14.5px}
.pdesc{color:#79798a;font-size:12.5px}
.spacer{flex:1}
.tag{font:600 10.5px ui-monospace,Menlo,monospace;letter-spacing:.5px;
 text-transform:uppercase;padding:3px 9px;border-radius:99px;white-space:nowrap}
.pending{background:#1d1d24;color:#6f6f80}
.building{background:#2a2410;color:#e0b341}
.judging{background:#132433;color:#5aa9e6}
.revising{background:#331a13;color:#e08a56}
.passed{background:#12291a;color:#54c47c}
.rounds{background:#1d1d24;color:#9a9aab;font:600 11px ui-monospace,Menlo,monospace;
 padding:3px 9px;border-radius:99px}
.body{display:none;padding:2px 17px 18px;border-top:1px solid #1e1e26}
.piece.open .body{display:block}
.gap{background:#191013;border-left:2px solid #b8425c;padding:9px 13px;
 border-radius:0 6px 6px 0;margin:13px 0;color:#f0c8d2;font-size:13px}
.note{color:#8a8a99;font-size:12.5px;margin:11px 0}
.round{border-top:1px solid #1e1e26;padding:15px 0 4px}
.rhead{display:flex;gap:11px;align-items:center;margin-bottom:9px;font-size:12.5px}
.rn{font:600 11px ui-monospace,Menlo,monospace;color:#6f6f80}
.call{font:600 10.5px ui-monospace,Menlo,monospace;padding:2px 8px;border-radius:99px}
.call.ours{background:#12291a;color:#54c47c}
.call.ref{background:#331a13;color:#e08a56}
.call.tie{background:#132433;color:#5aa9e6}
.shots{display:flex;gap:11px;flex-wrap:wrap}
.shot{flex:1 1 300px;min-width:0}
.shot img{width:100%;border-radius:7px;border:1px solid #26262f;display:block;
 background:#000}
.cap{color:#6f6f80;font:11px ui-monospace,Menlo,monospace;margin:5px 0 0}
.verdict{color:#b8b8c6;font-size:12.5px;margin-top:9px;white-space:pre-wrap}
.logbox{border:1px solid #24242c;border-radius:11px;background:#131318;padding:6px 0;
 max-height:290px;overflow:auto;margin-top:24px}
.logrow{display:flex;gap:13px;padding:4px 17px;font-size:12.5px}
.logt{color:#57576a;font:11px ui-monospace,Menlo,monospace;padding-top:1px}
.logm{color:#a4a4b4}
.dot{width:7px;height:7px;border-radius:99px;background:#54c47c;
 animation:p 1.7s ease-in-out infinite}
@keyframes p{0%,100%{opacity:1}50%{opacity:.22}}
h2{font-size:12px;text-transform:uppercase;letter-spacing:1.1px;color:#6f6f80;
 margin:26px 0 9px;font-weight:640}
"""

JS = """
document.querySelectorAll('.phead').forEach(h=>h.onclick=()=>{
  const p=h.parentElement, id=p.dataset.id, o=p.classList.toggle('open');
  try{localStorage.setItem('open_'+id,o?'1':'0')}catch(e){}
});
document.querySelectorAll('.piece').forEach(p=>{
  let v=null; try{v=localStorage.getItem('open_'+p.dataset.id)}catch(e){}
  if(v==='1'||(v===null&&p.dataset.active==='1')) p.classList.add('open');
});
"""


def img(path, cap):
    if not path:
        return ""
    return ('<div class="shot"><img src="%s" alt="%s"><p class="cap">%s</p></div>'
            % (html.escape(path), html.escape(cap), html.escape(cap)))


def render(s):
    parts = []
    passed = sum(1 for p in s["pieces"].values() if p.get("status") == "passed")
    total_rounds = sum(p.get("round", 0) for p in s["pieces"].values())

    for pid, name, desc in PIECES:
        p = s["pieces"].get(pid, {"status": "pending", "round": 0, "rounds": []})
        st = p.get("status", "pending")
        active = "1" if st in ("building", "judging", "revising") else "0"
        rs = []
        for r in p.get("rounds", [])[:4]:
            call = (r.get("call") or "").lower()
            cls = "ours" if "our" in call else ("ref" if "ref" in call else "tie")
            label = {"ours": "critic picked OURS", "ref": "critic picked the real game",
                     "tie": "critic could not tell"}[cls]
            shots = img(r.get("ab"), "blind A/B") or (
                img(r.get("ours"), "ours") + img(r.get("ref"), "reference"))
            rs.append(
                '<div class="round"><div class="rhead"><span class="rn">ROUND %s</span>'
                '<span class="call %s">%s</span><span class="rn">%s</span></div>'
                '<div class="shots">%s</div>%s%s</div>'
                % (r.get("n", "?"), cls, label, r.get("t", ""), shots,
                   '<p class="verdict">%s</p>' % html.escape(r["verdict"]) if r.get("verdict") else "",
                   '<div class="gap"><b>Biggest gap →</b> %s</div>' % html.escape(r["gap"]) if r.get("gap") else "")
            )

        parts.append(
            '<div class="piece" data-id="%s" data-active="%s"><div class="phead">'
            '<span class="pid">%s</span><span class="pname">%s</span>'
            '<span class="pdesc">%s</span><span class="spacer"></span>'
            '<span class="rounds">%d rd</span><span class="tag %s">%s</span></div>'
            '<div class="body">%s%s%s</div></div>'
            % (pid, active, pid, name, desc, p.get("round", 0), st, st,
               '<p class="note">%s</p>' % html.escape(p["note"]) if p.get("note") else "",
               '<div class="gap"><b>Open gap →</b> %s</div>' % html.escape(p["gap"])
               if p.get("gap") and st != "passed" else "",
               "".join(rs) or '<p class="note">No judged rounds yet.</p>')
        )

    logs = "".join(
        '<div class="logrow"><span class="logt">%s</span><span class="logm">%s</span></div>'
        % (html.escape(l["t"]), html.escape(l["msg"])) for l in s["log"][:80]
    )

    doc = """<!doctype html><html><head><meta charset="utf-8">
<title>The Lower Worlds: Awakening — build</title>
<meta http-equiv="refresh" content="15">
<style>%s</style></head><body>
<header><h1>The Lower Worlds: Awakening &mdash; build loop</h1>
<span class="sub">bar: The Legend of Zelda: Link's Awakening (Switch, 2019) &middot; refs/</span>
<span class="bar"><span class="dot"></span><span class="sub">%d/8 passed &middot; %d rounds judged &middot; updated %s</span></span>
</header><div class="wrap">
<h2>Pieces</h2>%s
<h2>Activity</h2><div class="logbox">%s</div>
</div><script>%s</script></body></html>""" % (
        CSS, passed, total_rounds, now(), "".join(parts), logs, JS)

    with open(OUT, "w") as f:
        f.write(doc)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="c", required=True)
    sub.add_parser("init").set_defaults(fn=cmd_init)
    sub.add_parser("render").set_defaults(fn=cmd_render)

    u = sub.add_parser("update")
    u.add_argument("pid")
    u.add_argument("--status", choices=STATUS_ORDER)
    u.add_argument("--note")
    u.add_argument("--round", type=int)
    u.add_argument("--gap")
    u.set_defaults(fn=cmd_update)

    r = sub.add_parser("round")
    r.add_argument("pid")
    r.add_argument("--n", type=int)
    r.add_argument("--ours")
    r.add_argument("--ref")
    r.add_argument("--ab")
    r.add_argument("--call", help="ours | ref | tie")
    r.add_argument("--gap")
    r.add_argument("--verdict")
    r.add_argument("--status", choices=STATUS_ORDER)
    r.set_defaults(fn=cmd_round)

    g = sub.add_parser("log")
    g.add_argument("msg")
    g.set_defaults(fn=cmd_log)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
