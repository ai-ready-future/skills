#!/usr/bin/env bash
# Fixture matrix for build_info.py and run.py.
#
#   bg-watch.test.sh
#
# Each case runs the scripts with the fake claude and jag in tests/fake. PATH holds
# only the fake folder and the system folders, so the real claude and jag never run.
# The fake commands write each call to $CALLS, and the cases read that file.
#
# Exit 0 when every case matches, 1 otherwise.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/../scripts" && pwd)"
ROOT="${TMPDIR:-/tmp}/bg-watch-test.$$"
rm -rf "$ROOT"; mkdir -p "$ROOT"
trap 'rm -rf "$ROOT"' EXIT

FAKE_PATH="$HERE/fake:/usr/bin:/bin"
NOJAG="$ROOT/nojag"; mkdir -p "$NOJAG"; ln -s "$HERE/fake/claude" "$NOJAG/claude"
NOJAG_PATH="$NOJAG:/usr/bin:/bin"

fails=0
check() { local label="$1"; shift; if "$@"; then echo "ok   $label"; else echo "FAIL $label"; fails=$((fails+1)); fi; }
has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
# pyok LABEL FILE EXPR: EXPR sees d, the JSON of FILE (a list of objects for a .jsonl file).
pyok() {
  check "$1" python3 -c '
import json, sys
p = sys.argv[1]
d = [json.loads(x) for x in open(p)] if p.endswith(".jsonl") else json.load(open(p))
sys.exit(0 if eval(sys.argv[2]) else 1)' "$2" "$3"
}

# --- fixtures ---
export FIXTURES="$ROOT/fixtures"
mkdir -p "$FIXTURES/logs"
cat > "$FIXTURES/agents.json" <<'EOF'
[{"id":"s-stuck","name":"stuck-one","state":"working","status":"idle"},
 {"id":"s-ok","name":"ok-one","state":"working","status":"idle"},
 {"id":"s-clean","name":"clean-one","state":"done"},
 {"id":"self","name":"watcher","state":"working","status":"busy"},
 {"id":"s-busy","name":"busy-one","state":"working","status":"busy"},
 {"id":"s-footer","name":"footer-one","state":"working","status":"busy"}]
EOF
printf '⏺ Bash(ls)\n  ⎿  API Error: 529 overloaded\n✻ Cooked for 3s\n  1234\n❯ \n' > "$FIXTURES/logs/s-stuck.txt"
printf 'API Error: 500\n⏺ Read(file.txt)\n  ⎿  Read 10 lines\n' > "$FIXTURES/logs/s-ok.txt"
printf '⏺ All good\n' > "$FIXTURES/logs/s-clean.txt"
printf 'API Error: 500\n' > "$FIXTURES/logs/self.txt"
printf 'API Error: 529\n❯ \n' > "$FIXTURES/logs/s-busy.txt"
# Real footers: a recap block over more than one line, and "needs input" with letters lost.
printf '● API Error: Connection lost\n※recap: We design the linter. Next: pick a\nlibrary? (disable recaps in /config)\n1 neds input & 10\n' > "$FIXTURES/logs/s-footer.txt"
export CLAUDE_JOB_DIR="/somewhere/jobs/self/"

# new_case NAME: a fresh state folder and call record for one case.
new_case() {
  C="$ROOT/$1"; mkdir -p "$C"
  export BG_WATCH_STATE="$C/state" CALLS="$C/calls"
  : > "$CALLS"
  unset FAKE_JAG_OUT FAKE_JAG_EXIT
}
watch() { PATH="${1:-$FAKE_PATH}" python3 "$SCRIPTS/run.py" > "$C/out" 2> "$C/err"; echo $? > "$C/rc"; }

# --- build_info.py ---
new_case build
PATH="$FAKE_PATH" python3 "$SCRIPTS/build_info.py" > /dev/null
S="$BG_WATCH_STATE/sessions.jsonl"
pyok "build: s-stuck is stuck"                  "$S" '{o["id"]: o["stuck"] for o in d}.get("s-stuck") is True'
pyok "build: s-ok is not stuck"                 "$S" '{o["id"]: o["stuck"] for o in d}.get("s-ok") is False'
pyok "build: s-busy is stuck"                   "$S" '{o["id"]: o["stuck"] for o in d}.get("s-busy") is True'
pyok "build: recap and needs-input footers are not real events" "$S" '{o["id"]: o["stuck"] for o in d}.get("s-footer") is True'
pyok "build: s-clean (no error) is left out"    "$S" '"s-clean" not in [o["id"] for o in d]'
pyok "build: own session is left out"           "$S" '"self" not in [o["id"] for o in d]'
pyok "build: agents.json lists all six IDs"     "$BG_WATCH_STATE/agents.json" 'sorted(d) == ["s-busy","s-clean","s-footer","s-ok","s-stuck","self"]'

# --- run.py: jag --ask agrees with the flag ---
new_case agree
watch
check "agree: exit 0"                           has "$C/rc" "0"
check "agree: stop s-stuck"                     has "$CALLS" "claude stop s-stuck"
check "agree: respawn s-stuck"                  has "$CALLS" "claude respawn s-stuck"
check "agree: no stop for busy session"         hasnt "$CALLS" "claude stop s-busy"
check "agree: no respawn for busy session"      hasnt "$CALLS" "claude respawn s-busy"
check "agree: never claude rm"                  hasnt "$CALLS" "claude rm"
check "agree: busy shows skipped"               has "$C/out" "STUCK (+1), skipped (busy)"
check "agree: s-stuck shows restarted"          has "$C/out" "STUCK (+1), restarted:"
check "agree: mode is jag --ask"                has "$C/out" "jag mode: jag --ask"
check "agree: no disagreement"                  has "$C/out" "jag disagrees: none"
check "agree: RETRY_TO has stuck-one only"      has "$C/out" 'RETRY_TO: ["stuck-one"]'
pyok "agree: log line has the jag decision"     "$BG_WATCH_STATE/jag-log.jsonl" 'len(d) == 1 and d[0]["jag_stuck"] == ["s-busy","s-footer","s-stuck"] and d[0]["disagree"] == []'
pyok "agree: log line has all keys"             "$BG_WATCH_STATE/jag-log.jsonl" '{"at","mode","cmd","exit","seconds","input","output","flag_stuck","jag_stuck","disagree"} <= set(d[0])'

# --- run.py: jag leaves out the stuck sessions ---
new_case disagree
export FAKE_JAG_OUT='{"no_good_answer":true,"results":[]}'
watch
check "disagree: nothing restarted"             hasnt "$CALLS" "claude respawn"
check "disagree: report names the sessions"     has "$C/out" "jag disagrees: s-busy, s-footer, s-stuck"
check "disagree: RETRY_TO is empty"             has "$C/out" "RETRY_TO: []"
pyok "disagree: log line has the disagreement"  "$BG_WATCH_STATE/jag-log.jsonl" 'd[0]["disagree"] == ["s-busy","s-footer","s-stuck"] and d[0]["jag_stuck"] == []'

# --- run.py: jag --ask cannot run (exit 4) ---
new_case askfail
export FAKE_JAG_EXIT=4 FAKE_JAG_OUT='{"error":{"cause":"no API key","fix":"set a key"},"results":[]}'
watch
check "askfail: free search follows"            has "$CALLS" "-F stuck=true"
check "askfail: mode is free mode"              has "$C/out" "jag mode: jag free mode (--ask failed)"
check "askfail: error cause shown"              has "$C/out" "jag error cause: no API key"
check "askfail: error fix shown"                has "$C/out" "jag error fix: set a key"
check "askfail: s-stuck restarted"              has "$CALLS" "claude respawn s-stuck"

# --- run.py: jag is not installed ---
new_case nojag
watch "$NOJAG_PATH"
check "nojag: exit 0"                           has "$C/rc" "0"
check "nojag: mode is built-in flag"            has "$C/out" "jag mode: built-in stuck flag (jag not installed)"
check "nojag: s-stuck restarted"                has "$CALLS" "claude respawn s-stuck"

# --- run.py: jag prints text that is not JSON ---
new_case notjson
export FAKE_JAG_OUT='not json'
watch
check "notjson: exit 0"                         has "$C/rc" "0"
check "notjson: nothing restarted"              hasnt "$CALLS" "claude respawn"
pyok "notjson: raw output is logged"            "$BG_WATCH_STATE/jag-log.jsonl" 'd[0]["output"] == "not json"'

# --- run.py: history drops sessions that no longer exist ---
new_case prune
mkdir -p "$BG_WATCH_STATE"
echo '{"gone":{"name":"old","count":3,"keys":[]}}' > "$BG_WATCH_STATE/failure-history.json"
watch
pyok "prune: gone is removed from history"      "$BG_WATCH_STATE/failure-history.json" '"gone" not in d and "s-stuck" in d'

# --- run.py: two checks add up ---
new_case twice
watch; watch
pyok "twice: two log lines"                     "$BG_WATCH_STATE/jag-log.jsonl" 'len(d) == 2'
check "twice: two input files" test "$(ls "$BG_WATCH_STATE/jag-input" | wc -l)" -eq 2

# --- run.py: no session has an API Error ---
new_case quiet
echo '[{"id":"s-clean","name":"clean-one","state":"done"}]' > "$ROOT/quiet/agents.json"
FIXTURES="$ROOT/quiet" ; mkdir -p "$FIXTURES/logs"; cp "$ROOT/fixtures/logs/s-clean.txt" "$FIXTURES/logs/"
watch
FIXTURES="$ROOT/fixtures"
check "quiet: exit 0"                           has "$C/rc" "0"
check "quiet: jag is not called"                hasnt "$CALLS" "jag "
check "quiet: mode says no session"             has "$C/out" "jag mode: no session with an API Error"

echo
if [ "$fails" -eq 0 ]; then echo "all cases pass"; exit 0; fi
echo "$fails case(s) failed"; exit 1
