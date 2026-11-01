#!/usr/bin/env bash
# Cases for scripts/dispatch.sh.
#
#   dispatch.test.sh
#
# Each case runs dispatch.sh with the fake claude in tests/fake. PATH holds only
# the fake folder and the system folders, so the real claude never runs. The
# fake writes its arguments to $FAKE_CLAUDE_LOG, one per line.
#
# Exit 0 when every case passes, 1 otherwise.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DISPATCH="$(cd "$HERE/../scripts" && pwd)/dispatch.sh"
ROOT="${TMPDIR:-/tmp}/dispatch-test.$$"
rm -rf "$ROOT"; mkdir -p "$ROOT"
trap 'rm -rf "$ROOT"' EXIT
export PATH="$HERE/fake:/usr/bin:/bin"

fails=0
check() { local label="$1"; shift; if "$@"; then echo "ok   $label"; else echo "FAIL $label"; fails=$((fails+1)); fi; }
has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
rc_is() { [ "$(cat "$C/rc")" = "$1" ]; }
# same FILE ARG...: FILE holds exactly ARG..., one per line.
same() { local f="$1"; shift; diff <(printf '%s\n' "$@") "$f" > /dev/null; }
# same_q FILE ARG...: FILE holds exactly ARG..., one per line, shell-quoted with %q.
same_q() { local f="$1"; shift; diff <(printf '%q\n' "$@") "$f" > /dev/null; }

# --- fixtures ---
V6="$ROOT/v6.md"
cat > "$V6" <<'EOF'
# ADLC

## 1. Setup values

| Key | Value |
|---|---|
| Repository | `acme/widgets` |
| Team prefix | `acme` (session names are `<prefix>-<role>[-n]`) |
| Orchestrator name | `acme-orchestrator` |

Tools per role.

| Role | Tool |
|---|---|
| tracker | `gh` |
| security | `semgrep` |

## 3. Roles

| Role | Colour | Model | Effort | Compact at | Output style |
|---|---|---|---|---|---|
| orchestrator | `purple` | `claude-opus-5-5` | `medium` | `400k` | `sofa` |
| implementer | `green` | `claude-sonnet-5-5` | `high` | `300k` | `sofa` |
| chores | `yellow` | `claude-sonnet-5-5` | — | `300k` | `sofa` |
| verifier | `green` | `claude-opus-5-5` | `high` | `400k` | `sofa` |
| tracker | `yellow` | `claude-sonnet-5-5` | | `300k` | `sofa` |

Model and Effort: use the exact values in the table.
EOF

V5="$ROOT/v5.md"
cat > "$V5" <<'EOF'
## 1. Setup values

| Key | Value |
|---|---|
| Team prefix | `old` (session names are `<prefix>-<role>[-n]`) |

## 3. Roles

| Role | Colour | Model | Effort | Compact at | Count |
|---|---|---|---|---|---|
| reviewer | `green` | `claude-opus-5-5` | `high` | `400k` | 1–4 |
EOF

NOEFFORT="$ROOT/noeffort.md"
cat > "$NOEFFORT" <<'EOF'
| Key | Value |
|---|---|
| Team prefix | `ne` (session names are `<prefix>-<role>[-n]`) |

| Role | Colour | Model | Compact at | Output style |
|---|---|---|---|---|
| `hitl` | `yellow` | `claude-sonnet-5-5` | `300k` | `sofa` |
EOF

NOPREFIX="$ROOT/noprefix.md"
sed '/Team prefix/d' "$V6" > "$NOPREFIX"

PROMPT_FILE="$ROOT/prompt.txt"
printf 'line one\nline two\n' > "$PROMPT_FILE"

# new_case NAME: a fresh folder and a fresh fake log for one case.
new_case() {
  C="$ROOT/$1"; mkdir -p "$C"
  export FAKE_CLAUDE_LOG="$C/argv"
  : > "$FAKE_CLAUDE_LOG"
  unset FAKE_CLAUDE_FAIL FAKE_CLAUDE_BACKGROUNDED
}
dispatch() { "$DISPATCH" "$@" > "$C/out" 2> "$C/err"; echo $? > "$C/rc"; }

# --- dry run: a sonnet row with effort and output style ---
new_case dry
dispatch --adlc "$V6" --role implementer --prompt "do the work" --dry-run
check "dry: exit 0"                             rc_is 0
check "dry: exact flags"                        same_q "$C/out" claude --bg -n acme-implementer --model claude-sonnet-5-5 --effort high --autocompact 300k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions "do the work"
check "dry: claude not run"                     test ! -s "$FAKE_CLAUDE_LOG"

# --- v5 file without the Output style column ---
new_case v5
dispatch --adlc "$V5" --role reviewer --prompt "review" --dry-run
check "v5: exit 0"                              rc_is 0
check "v5: no --settings"                       hasnt "$C/out" "--settings"
check "v5: exact flags"                         same_q "$C/out" claude --bg -n old-reviewer --model claude-opus-5-5 --effort high --autocompact 400k --permission-mode bypassPermissions review

# --- Effort cell is a dash ---
new_case dash
dispatch --adlc "$V6" --role chores --prompt "chore" --dry-run
check "dash: exit 0"                            rc_is 0
check "dash: no --effort"                       hasnt "$C/out" "--effort"
check "dash: model kept"                        has "$C/out" "claude-sonnet-5-5"

# --- Effort cell is empty ---
new_case emptyeffort
dispatch --adlc "$V6" --role tracker --prompt "track" --dry-run
check "emptyeffort: exact flags"                same_q "$C/out" claude --bg -n acme-tracker --model claude-sonnet-5-5 --autocompact 300k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions track

# --- no Effort column, Role cell in backticks ---
new_case noeffort
dispatch --adlc "$NOEFFORT" --role hitl --prompt "ask" --dry-run
check "noeffort: exact flags"                   same_q "$C/out" claude --bg -n ne-hitl --model claude-sonnet-5-5 --autocompact 300k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions ask

# --- --n 2 ---
new_case n2
dispatch --adlc "$V6" --role verifier --n 2 --prompt "verify" --dry-run
check "n2: name has the number"                 has "$C/out" "acme-verifier-2"

# --- --resume ---
new_case resume
dispatch --adlc "$V6" --role verifier --resume abc123 --prompt "You were resumed." --dry-run
check "resume: exact flags"                     same_q "$C/out" claude --bg -n acme-verifier --model claude-opus-5-5 --effort high --autocompact 400k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions --resume abc123 "You were resumed."

# --- the fake runs: id and name ---
new_case run
dispatch --adlc "$V6" --role implementer --prompt "do the work" --cwd "$ROOT"
check "run: exit 0"                             rc_is 0
check "run: one line with id and name"          same "$C/out" "fake1234 acme-implementer"
check "run: fake got the flags"                 same "$FAKE_CLAUDE_LOG" --bg -n acme-implementer --model claude-sonnet-5-5 --effort high --autocompact 300k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions "do the work"

# --- the fake prints only the backgrounded line ---
new_case backgrounded
export FAKE_CLAUDE_BACKGROUNDED=1
dispatch --adlc "$V6" --role orchestrator --prompt "start"
check "backgrounded: exit 0"                    rc_is 0
check "backgrounded: id from that line"         same "$C/out" "fake5678 acme-orchestrator"

# --- the fake fails: no id ---
new_case fail
export FAKE_CLAUDE_FAIL=1
dispatch --adlc "$V6" --role implementer --prompt "do the work"
check "fail: exit 1"                            rc_is 1
check "fail: stdout empty"                      test ! -s "$C/out"
check "fail: claude output on stderr"           has "$C/err" "error: something"

# --- errors: exit 2 ---
new_case norole
dispatch --adlc "$V6" --role tester --prompt "test"
check "norole: exit 2"                          rc_is 2
check "norole: names the role"                  has "$C/err" "tester"

new_case nofile
dispatch --adlc "$ROOT/missing.md" --role implementer --prompt "x"
check "nofile: exit 2"                          rc_is 2

new_case noprefix
dispatch --adlc "$NOPREFIX" --role implementer --prompt "x"
check "noprefix: exit 2"                        rc_is 2
check "noprefix: says prefix"                   has "$C/err" "prefix"

new_case noprompt
dispatch --adlc "$V6" --role implementer
check "noprompt: exit 2"                        rc_is 2
check "noprompt: says prompt"                   has "$C/err" "prompt"

new_case badn
dispatch --adlc "$V6" --role implementer --n 0 --prompt "x"
check "badn: --n 0 exits 2"                     rc_is 2
dispatch --adlc "$V6" --role implementer --n x --prompt "x"
check "badn: --n x exits 2"                     rc_is 2

new_case partialrole
dispatch --adlc "$V6" --role verif --prompt "x"
check "partialrole: a prefix of a role is not the role" rc_is 2

# --- prompt from file keeps newlines ---
new_case promptfile
dispatch --adlc "$V6" --role implementer --prompt-file "$PROMPT_FILE" --dry-run
check "promptfile: one quoted argument with the newline" same_q "$C/out" claude --bg -n acme-implementer --model claude-sonnet-5-5 --effort high --autocompact 300k --settings '{"outputStyle":"sofa"}' --permission-mode bypassPermissions $'line one\nline two\n'
dispatch --adlc "$V6" --role implementer --prompt-file "$PROMPT_FILE"
check "promptfile: fake got both lines"         has "$FAKE_CLAUDE_LOG" "line two"
check "promptfile: fake got line one"           has "$FAKE_CLAUDE_LOG" "line one"

echo
if [ "$fails" -eq 0 ]; then echo "all cases pass"; exit 0; fi
echo "$fails case(s) failed"; exit 1
