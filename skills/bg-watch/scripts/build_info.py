import json, os, re, subprocess
# State lives in one fixed folder; the watcher skips its own session (bg job id = $CLAUDE_JOB_DIR basename).
STATE = os.path.expanduser(os.environ.get("BG_WATCH_STATE", "~/.claude/bg-watch"))
os.makedirs(STATE, exist_ok=True)
SELF = os.path.basename(os.environ.get("CLAUDE_JOB_DIR", "").rstrip("/"))
# One JSON line per session whose log mentions an API Error: concise facts for jag to judge.
NOISE = re.compile(r"^\s*(\d+|[✻✶✳✢✽·]\S*|.*(thinking with|Contemplating|Flibbertigibbeting|Pontificating|tokens\)).*)\s*$")
agents = json.loads(subprocess.run(["claude","agents","--json","--all"],capture_output=True,text=True).stdout)
# Every known id, so that run.py can drop history of sessions that no longer exist.
with open(os.path.join(STATE, "agents.json"),"w") as f:
    json.dump([s["id"] for s in agents if s.get("id")], f)
out = []
for s in agents:
    sid = s.get("id")
    if not sid or sid == SELF: continue
    raw = subprocess.run(["claude","logs",sid],capture_output=True,text=True).stdout
    t = re.sub(r"\x1b\[[0-9;]*[A-Za-z]","",raw).replace("\r","").replace("⏺","\n⏺")
    lines = [l.strip() for l in t.split("\n") if l.strip() and not NOISE.match(l)]
    idx = [i for i,l in enumerate(lines) if re.search(r"API Error", l, re.I)]
    if not idx: continue
    after, in_recap = [], False
    for l in lines[idx[-1]+1:]:   # a "※recap:" footer can wrap over lines; it ends at "(disable recaps in /config)"
        if l.startswith("※recap"): in_recap = True
        if not in_recap: after.append(l)
        if in_recap and "disable recaps" in l: in_recap = False
    # stuck = the API Error is the last real event (only completion marks, prompts, or queued messages follow)
    # the terminal can drop letters, for example "1 neds input & 10"
    real_after = [l for l in after if not re.match(r"^(✻|❯|›|…|\?|Checking for updates|\d+ agents|.*\bne+ds? input)", l)]
    out.append({"id": sid, "name": s.get("name"), "state": s.get("state"), "status": s.get("status",""),
                "api_errors_in_log": len(idx),
                "last_error": lines[idx[-1]][:110],
                "real_lines_after_last_error": len(real_after),
                "stuck": len(real_after) == 0,
                "what_follows_last_error": [l[:110] for l in real_after[:3]]})
with open(os.path.join(STATE, "sessions.jsonl"),"w") as f:
    for o in out: f.write(json.dumps(o, ensure_ascii=False)+"\n")
print(len(out), "sessions with API Error in log")
