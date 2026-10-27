import json, os, shutil, subprocess, sys, time
from datetime import datetime, timezone
HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.expanduser(os.environ.get("BG_WATCH_STATE", "~/.claude/bg-watch"))
os.makedirs(STATE, exist_ok=True)
P = lambda n: os.path.join(STATE, n)
KEEP_INPUTS = 500
QUESTION = "Which session is stuck: nothing real happened after its last API Error?"
subprocess.run([sys.executable, os.path.join(HERE, "build_info.py")],check=True,capture_output=True)
info = {}
for line in open(P("sessions.jsonl")):
    o = json.loads(line); info[o["id"]] = o
known = set(json.load(open(P("agents.json"))))
flag = sorted(k for k, o in info.items() if o["stuck"])   # second opinion only: jag decides
# compact records for jag: one per session, decision fields first; each check keeps its own input file
now = datetime.now(timezone.utc)
os.makedirs(P("jag-input"), exist_ok=True)
inp = os.path.join(P("jag-input"), now.strftime("%Y%m%dT%H%M%S.%fZ") + ".txt")
with open(inp,"w") as f:
    for sid, o in info.items():
        nxt = (o["what_follows_last_error"] or ["nothing"])[0][:60]
        f.write(f'SESSION {sid} {o["name"]} | state={o["state"]} | stuck={str(o["stuck"]).lower()} | real_lines_after_last_error={o["real_lines_after_last_error"]} | next_after_error: {nxt}\n---\n')
for old in sorted(os.listdir(P("jag-input")))[:-KEEP_INPUTS]:
    os.remove(os.path.join(P("jag-input"), old))

def jag(args):
    cmd = ["jag","--json","--max-chars","8000",*args,inp]
    t = time.monotonic()
    r = subprocess.run(cmd,capture_output=True,text=True)
    try: out = json.loads(r.stdout)
    except ValueError: out = r.stdout   # keep the raw text for the jag log
    return cmd, r.returncode, out, round(time.monotonic()-t, 2)

def picked(res):
    # no_good_answer=true means no session is stuck; else candidates are its stuck=true lines
    if not isinstance(res, dict) or res.get("no_good_answer"): return []
    return sorted({l["text"].split()[1] for x in res.get("results", []) for l in x.get("lines", [])
                   if l.get("is_match") and "stuck=true" in l.get("text", "") and l["text"].split()[1] in info})

ask_error = None
if not info:   # nothing to judge: no model call
    mode, cmd, code, res, secs, stuck = "no session with an API Error", None, 0, None, 0, []
elif shutil.which("jag") is None:   # jag not installed: use the script's own stuck flag
    mode, cmd, code, res, secs, stuck = "built-in stuck flag (jag not installed)", None, 127, None, 0, flag
else:
    cmd, code, res, secs = jag(["--ask",QUESTION,"SESSION"]); mode = "jag --ask"
    if code in range(3, 7):   # jag cannot run (key, credit, service): free jag search of the same marker
        ask_error = res.get("error") if isinstance(res, dict) else res
        cmd, code, res, s2 = jag(["-F","stuck=true"]); secs += s2; mode = "jag free mode (--ask failed)"
    stuck = picked(res)
disagree = sorted(set(flag) ^ set(stuck))
# history + rescue (stop then respawn; never rm); sessions that no longer exist leave the history
hist = json.load(open(P("failure-history.json"))) if os.path.exists(P("failure-history.json")) else {}
hist = {k: v for k, v in hist.items() if k in known}
rescued = {}
for sid, o in info.items():
    h = hist.setdefault(sid, {"name": o["name"], "count": 0, "keys": []})
    h["name"] = o["name"]; h["count"] = max(h["count"], o["api_errors_in_log"]); h["faulty_last_check"] = sid in stuck
for sid in stuck:
    if info[sid]["status"] == "busy":   # actively running: leave alone
        continue
    subprocess.run(["claude","stop",sid],capture_output=True)
    subprocess.run(["claude","respawn",sid],capture_output=True)
    st = [s for s in json.loads(subprocess.run(["claude","agents","--json","--all"],capture_output=True,text=True).stdout or "[]") if s.get("id")==sid]
    rescued[sid] = st[0].get("state") if st else "?"
json.dump(hist, open(P("failure-history.json"),"w"), indent=1)
with open(P("jag-log.jsonl"),"a") as f:
    f.write(json.dumps({"at": now.isoformat(), "mode": mode, "cmd": cmd, "exit": code, "seconds": secs,
                        "input": inp, "output": res, "ask_error": ask_error,
                        "flag_stuck": flag, "jag_stuck": stuck, "disagree": disagree}, ensure_ascii=False)+"\n")
print(f"jag mode: {mode} | exit {code} | stuck: {len(stuck)}")
if isinstance(ask_error, dict):
    print("jag error cause:", ask_error.get("cause")); print("jag error fix:", ask_error.get("fix"))
print("jag disagrees:", ", ".join(disagree) or "none")
print("jag log:", P("jag-log.jsonl"))
print("| Session | Name | Total failures seen | Status now |\n|---|---|---|---|")
for sid, h in sorted(hist.items(), key=lambda kv: -kv[1]["count"]):
    if sid in stuck:
        now_s = "STUCK (+1), " + (f"restarted: {rescued[sid]}" if sid in rescued else "skipped (busy)")
    elif sid in info: now_s = "recovered"
    else: now_s = "recovered (not in log window)"
    print(f'| `{sid}` | {h["name"]} | {h["count"]} | {now_s} |')
print("RETRY_TO:", json.dumps([info[s]["name"] for s in rescued]))
