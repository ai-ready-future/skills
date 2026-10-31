#!/usr/bin/env bash
# Cases for scripts/sofa-state, the SQLite state store.
#
#   sofa-state.test.sh
#
# Each case gets its own database in a temp folder through --db. Row counts are
# read with the sqlite3 module of python3, so the sqlite3 binary is not needed.
#
# Exit 0 when every case matches, 1 otherwise.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$(cd "$HERE/../scripts" && pwd)/sofa-state"
ROOT="${TMPDIR:-/tmp}/sofa-state-test.$$"
rm -rf "$ROOT"; mkdir -p "$ROOT"
trap 'rm -rf "$ROOT"' EXIT

fails=0
check() { local label="$1"; shift; if "$@"; then echo "ok   $label"; else echo "FAIL $label"; fails=$((fails+1)); fi; }
has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
# sql DB QUERY: print the first column of the first row.
sql() { python3 -c 'import sqlite3, sys; print(sqlite3.connect(sys.argv[1]).execute(sys.argv[2]).fetchone()[0])' "$1" "$2"; }
# pyok LABEL FILE EXPR: EXPR sees d, the JSON of FILE.
pyok() {
  check "$1" python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if eval(sys.argv[2]) else 1)' "$2" "$3"
}

# new_case NAME: a fresh database for one case.
new_case() { C="$ROOT/$1"; mkdir -p "$C"; DB="$C/state.db"; }
# --db is a flag of each leaf, so it goes after the command words.
st() { local cmd=(); while [ $# -gt 0 ] && [[ "$1" != -* ]]; do cmd+=("$1"); shift; done; "$S" "${cmd[@]}" --db "$DB" "$@"; }

# --- init is idempotent ---
new_case init
st init; st init
check "init: exit 0 twice"                      test $? -eq 0
check "init: 11 tables"                         test "$(sql "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")" -eq 11
check "init: journal mode is wal"               test "$(sql "$DB" "PRAGMA journal_mode")" = "wal"

# --- sessions ---
new_case session
st session upsert --name impl-1 --id s1 --role implementer --model opus --item ST-1 --at 2026-10-31T10:00:00Z
st session upsert --name impl-1 --id s1 --role implementer --at 2026-10-31T11:00:00Z
st session list --json > "$C/list.json"
pyok "session: one row after two upserts"       "$C/list.json" 'len(d) == 1'
pyok "session: second upsert keeps model and item" "$C/list.json" 'd[0]["model"] == "opus" and d[0]["item"] == "ST-1"'
pyok "session: since is kept when state is the same" "$C/list.json" 'd[0]["since"] == "2026-10-31T10:00:00Z"'
st session upsert --name impl-1 --id s1 --role implementer --state stopped --at 2026-10-31T12:00:00Z
st session list --json > "$C/list.json"
pyok "session: since moves with the state"      "$C/list.json" 'd[0]["state"] == "stopped" and d[0]["since"] == "2026-10-31T12:00:00Z"'
st session upsert --name impl-1 --id s1 --role implementer --at 2026-10-31T12:30:00Z
st session list --json > "$C/list.json"
pyok "session: upsert without --state keeps stopped" "$C/list.json" 'd[0]["state"] == "stopped" and d[0]["since"] == "2026-10-31T12:00:00Z"'
st session free --name impl-1 --at 2026-10-31T13:00:00Z
st session list --json > "$C/list.json"
pyok "session: free clears item and sets free_since" "$C/list.json" 'd[0]["item"] is None and d[0]["free_since"] == "2026-10-31T13:00:00Z"'
st session upsert --name impl-1 --id s1 --role implementer --item ST-2
st session list --json > "$C/list.json"
pyok "session: a new item clears free_since"    "$C/list.json" 'd[0]["item"] == "ST-2" and d[0]["free_since"] is None'
st session heartbeat --name impl-1 --at 2026-10-31T14:00:00Z
st session heartbeat --name new-one --at 2026-10-31T14:00:00Z
st session list --json > "$C/list.json"
pyok "session: heartbeat sets last_heartbeat"   "$C/list.json" '[x for x in d if x["name"] == "impl-1"][0]["last_heartbeat"] == "2026-10-31T14:00:00Z"'
pyok "session: heartbeat before upsert makes a row" "$C/list.json" 'len(d) == 2'
check "session: two heartbeat rows"             test "$(sql "$DB" "SELECT COUNT(*) FROM heartbeats")" -eq 2

# --- items ---
new_case item
st item set --id ST-1 --state in_progress --branch feat/x --session impl-1 --at 2026-10-30T10:00:00Z
check "item: picked_up_at is set on insert"     test "$(sql "$DB" "SELECT picked_up_at FROM items WHERE id='ST-1'")" = "2026-10-30T10:00:00Z"
check "item: released_at is empty before release" test "$(sql "$DB" "SELECT released_at IS NULL FROM items WHERE id='ST-1'")" = "1"
st item set --id ST-1 --state blocked --waits-for ST-0 --pr 12 --at 2026-10-30T12:00:00Z
check "item: picked_up_at does not change"      test "$(sql "$DB" "SELECT picked_up_at FROM items WHERE id='ST-1'")" = "2026-10-30T10:00:00Z"
check "item: omitted flags keep the old value"  test "$(sql "$DB" "SELECT branch || ' ' || session FROM items WHERE id='ST-1'")" = "feat/x impl-1"
check "item: waits_for is set"                  test "$(sql "$DB" "SELECT waits_for FROM items WHERE id='ST-1'")" = "ST-0"
st item set --id ST-1 --state released --waits-for '' --at 2026-10-31T13:30:00Z
check "item: released_at is set on release"     test "$(sql "$DB" "SELECT released_at FROM items WHERE id='ST-1'")" = "2026-10-31T13:30:00Z"
check "item: an empty value clears waits_for"   test "$(sql "$DB" "SELECT waits_for IS NULL FROM items WHERE id='ST-1'")" = "1"
st item set --id ST-1 --state released --at 2026-11-01T00:00:00Z
check "item: released_at is set only one time"  test "$(sql "$DB" "SELECT released_at FROM items WHERE id='ST-1'")" = "2026-10-31T13:30:00Z"

# --- trips, decisions, asks, interactions and metrics ---
new_case metrics
st item set --id ST-1 --state in_progress --at 2026-10-30T10:00:00Z
st metrics --story ST-1 --json > "$C/m0.json"
pyok "metrics: cycle_hours is null before release" "$C/m0.json" 'd["cycle_hours"] is None and d["released_at"] is None'
st item trip --id ST-1 --from implementer --to verifier
st item trip --id ST-1 --from verifier --to reviewer
st item trip --id ST-1 --from reviewer --to tester
st item trip --id ST-9 --from implementer --to verifier
D="--level detail --confidence high --reversibility reversible --visibility visible"
st decision log --id D1 --story ST-1 $D --by decision-judge --summary "use sqlite"
st decision log --id D2 --story ST-1 $D --by decision-judge --summary "a bad one"
st decision log --id D3 --story ST-1 $D --by hitl --summary "a human one"
st decision log --id D4 --story ST-2 $D --by decision-judge --summary "other story"
st decision veto --id D2
st decision list --story ST-1 --json > "$C/d.json"
pyok "decision: list by story has 3"            "$C/d.json" 'len(d) == 3'
pyok "decision: veto sets vetoed_at"            "$C/d.json" '[x for x in d if x["id"] == "D2"][0]["vetoed_at"] is not None'
st decision veto --id D-none 2> "$C/err"; rc=$?
check "decision: veto of a missing id exits 1"  test $rc -eq 1
check "decision: veto of a missing id says so"  has "$C/err" "no decision with id D-none"
st decision list --since 2999-01-01T00:00:00Z --json > "$C/d2.json"
pyok "decision: --since filters"                "$C/d2.json" 'd == []'
st ask open --id A1 --story ST-1 --priority high
st ask open --id A2 --story ST-1 --priority low
st ask open --id A3 --story ST-2 --priority low
st ask close --id A1
st ask list --json > "$C/a.json"
pyok "ask: three asks, one closed"              "$C/a.json" 'len(d) == 3 and sum(1 for x in d if x["closed_at"]) == 1'
st interaction log --story ST-1 --kind ask --by hitl
st interaction log --story ST-1 --kind defect --by reviewer
st interaction log --story ST-1 --kind defect --by reviewer
st interaction log --story ST-1 --kind bogus --by reviewer 2>/dev/null; rc=$?
check "interaction: a bad kind exits 2"         test $rc -eq 2
st item set --id ST-1 --state released --at 2026-10-31T13:30:00Z
st metrics --story ST-1 --json > "$C/m.json"
pyok "metrics: trips counts the story only"     "$C/m.json" 'd["trips"] == 3'
pyok "metrics: autonomous_decisions skips hitl and vetoed" "$C/m.json" 'd["autonomous_decisions"] == 1'
pyok "metrics: hitl_questions = closed asks + ask interactions" "$C/m.json" 'd["hitl_questions"] == 2'
pyok "metrics: review_defects"                  "$C/m.json" 'd["review_defects"] == 2'
pyok "metrics: cycle_hours one decimal"         "$C/m.json" 'd["cycle_hours"] == 27.5'
st metrics --story ST-1 > "$C/m.txt"
check "metrics: text form names the story"      has "$C/m.txt" "story: ST-1"

# --- usage, queue, kv ---
new_case small
st usage set --session impl-1 --item ST-1 --tokens 1000
st usage set --session impl-1 --item ST-1 --tokens 2500
check "usage: one row per session and item"     test "$(sql "$DB" "SELECT COUNT(*) FROM usage")" -eq 1
check "usage: the last value wins"              test "$(sql "$DB" "SELECT tokens FROM usage")" -eq 2500
st queue set ST-3 ST-1 ST-2
st queue list > "$C/q.txt"
check "queue: list keeps the order"             test "$(tr '\n' ' ' < "$C/q.txt")" = "ST-3 ST-1 ST-2 "
st queue set ST-2
st queue list > "$C/q.txt"
check "queue: set replaces the queue"           test "$(tr '\n' ' ' < "$C/q.txt")" = "ST-2 "
st queue set
check "queue: set with no item empties it"      test "$(sql "$DB" "SELECT COUNT(*) FROM queue")" -eq 0
st kv set risk mvp; st kv set risk established
check "kv: get returns the last value"          test "$(st kv get risk)" = "established"
st kv get nope 2> "$C/err"; rc=$?
check "kv: a missing key exits 1"               test $rc -eq 1
check "kv: a missing key is named on stderr"    has "$C/err" "no key nope"

# --- report ---
new_case report
st session upsert --name impl-1 --id s1 --role implementer --item ST-1
st session heartbeat --name impl-1
st item set --id ST-1 --state in_progress --pr 12 --session impl-1
st ask open --id A1 --story ST-1 --priority high
st queue set ST-2 ST-3
st decision log --id D1 --story ST-1 --level detail --confidence high --reversibility reversible --visibility visible --by decision-judge --summary "use sqlite"
st decision log --id D0 --story ST-1 --level detail --confidence high --reversibility reversible --visibility visible --by decision-judge --summary "old one" --at 2020-01-01T00:00:00Z
st report > "$C/out" 2> "$C/err"; rc=$?
check "report: exit 0"                          test $rc -eq 0
check "report: names the session"               has "$C/out" "impl-1"
check "report: names the item"                  has "$C/out" "ST-1"
check "report: names the open ask"              has "$C/out" "A1"
check "report: shows the queue"                 has "$C/out" "ST-2 ST-3"
check "report: shows the decision of today"     has "$C/out" "use sqlite"
check "report: hides an old decision"           hasnt "$C/out" "old one"
st report --json > "$C/r.json"
pyok "report: json has the five parts"          "$C/r.json" 'set(d) == {"sessions","items","open_asks","queue","decisions_24h"}'
st report --at 2030-01-01T00:00:00Z > "$C/out2"
check "report: heartbeat age is in days"        grep -qE 'impl-1 .* [0-9]+d' "$C/out2"

# --- two writers in parallel lose no rows ---
new_case parallel
writer() { local i; for i in $(seq 1 20); do st message log --type TASK --from "$1" --to orch --subject "n$i" || echo "write $1 $i failed"; done; }
writer A > "$C/a.err" 2>&1 &
writer B > "$C/b.err" 2>&1 &
wait
check "parallel: 40 messages"                   test "$(sql "$DB" "SELECT COUNT(*) FROM messages")" -eq 40
check "parallel: no writer error"               test ! -s "$C/a.err" -a ! -s "$C/b.err"

# --- prune ---
new_case prune
st message log --type TASK --from a --to b --subject old --at 2026-01-01T00:00:00Z
st message log --type TASK --from a --to b --subject new
st session heartbeat --name x --at 2026-01-01T00:00:00Z
st session heartbeat --name x
st prune --days 7
check "prune: old message is gone"              test "$(sql "$DB" "SELECT COUNT(*) FROM messages")" -eq 1
check "prune: new message stays"                test "$(sql "$DB" "SELECT subject FROM messages")" = "new"
check "prune: old heartbeat is gone"            test "$(sql "$DB" "SELECT COUNT(*) FROM heartbeats")" -eq 1
check "prune: session row stays"                test "$(sql "$DB" "SELECT COUNT(*) FROM sessions")" -eq 1

# --- exit codes ---
new_case exits
st bogus 2>/dev/null; rc=$?
check "exit: unknown command is 2"              test $rc -eq 2
st item set --id x --state y --at garbage 2>/dev/null; rc=$?
check "exit: a bad --at is 2"                   test $rc -eq 2
if git -C "$C" rev-parse --show-toplevel > /dev/null 2>&1; then
  echo "skip exit: no git case, the temp folder is inside a git repository"
else
  ( cd "$C" && env -u SOFA_STATE_DB "$S" init 2> "$C/err" ); rc=$?
  check "exit: no git, no --db, no env is 1"      test $rc -eq 1
  check "exit: one line on stderr"                test "$(wc -l < "$C/err")" -eq 1
fi
( cd "$C" && SOFA_STATE_DB="$C/env.db" "$S" init )
check "env: SOFA_STATE_DB picks the path"       test -f "$C/env.db"

echo
if [ "$fails" -eq 0 ]; then echo "all cases pass"; exit 0; fi
echo "$fails case(s) failed"; exit 1
