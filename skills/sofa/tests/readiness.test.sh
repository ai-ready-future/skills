#!/usr/bin/env bash
# Cases for scripts/readiness.py.
#
#   readiness.test.sh
#
# Each case runs readiness.py on a fixture repository in a temp folder, with
# fake claude, gh and crontab scripts (READINESS_* variables) and a fake HOME.
# The cases read the --json output.
#
# Exit 0 when every case passes, 1 otherwise.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$(cd "$HERE/../scripts" && pwd)/readiness.py"
TEMPLATE="$(cd "$HERE/../templates" && pwd)/ADLC.md"
ROOT="${TMPDIR:-/tmp}/readiness-test.$$"
rm -rf "$ROOT"; mkdir -p "$ROOT"
trap 'rm -rf "$ROOT"' EXIT
# A folder above $ROOT may be a git repository. git must not find it.
export GIT_CEILING_DIRECTORIES="$ROOT"

fails=0
check() { local label="$1"; shift; if "$@"; then echo "ok   $label"; else echo "FAIL $label"; fails=$((fails+1)); fi; }
rc_is() { [ "$(cat "$C/rc")" = "$1" ]; }
has() { grep -qF -- "$2" "$1"; }
hasnt() { ! grep -qF -- "$2" "$1"; }
# status ID STATUS [BLOCKS]: the item ID in $C/out has STATUS (and blocks_start BLOCKS, when given).
status() {
  python3 -c '
import json, sys
items = {json.loads(l)["id"]: json.loads(l) for l in open(sys.argv[1]) if l.strip()}
it = items.get(sys.argv[2])
if it is None: sys.exit(1)
if it["status"] != sys.argv[3]: sys.exit(1)
if len(sys.argv) > 4 and it["blocks_start"] != (sys.argv[4] == "true"): sys.exit(1)
' "$C/out" "$@"
}
# detail_has ID TEXT: the detail of item ID contains TEXT.
detail_has() {
  python3 -c '
import json, sys
items = {json.loads(l)["id"]: json.loads(l) for l in open(sys.argv[1]) if l.strip()}
sys.exit(0 if sys.argv[2] in items and sys.argv[3] in items[sys.argv[2]]["detail"] else 1)
' "$C/out" "$@"
}
not() { ! "$@"; }
# absent ID: no item ID in $C/out.
absent() { ! grep -qF -- "\"id\": \"$1\"" "$C/out"; }
# every_line_is_json: each line of $C/out parses as JSON with the six keys.
every_line_is_json() {
  python3 -c '
import json, sys
keys = {"id", "area", "status", "blocks_start", "detail", "fix"}
for l in open(sys.argv[1]):
    if l.strip() and set(json.loads(l)) != keys: sys.exit(1)
' "$C/out"
}

# --- fake commands ---
BIN="$ROOT/bin"; mkdir -p "$BIN"
cat > "$BIN/claude" <<'EOF'
#!/usr/bin/env bash
case "$1 ${2:-} ${3:-}" in
  "--help  ") echo "  --bg, --background   Start in the background"; echo "  --autocompact <auto|tokens>  Auto-compact window" ;;
  "plugin list --json") echo '[{"id":"product@lib","enabled":true},{"id":"knowledge@lib","enabled":true},{"id":"slack@lib","enabled":false}]' ;;
  "plugin list ") printf '  ❯ product@lib\n    Status: ✔ enabled\n' ;;
esac
EOF
cat > "$BIN/claude-old" <<'EOF'
#!/usr/bin/env bash
case "$1" in --help) echo "  --model <model>" ;; plugin) echo "[]" ;; esac
EOF
cat > "$BIN/gh" <<'EOF'
#!/usr/bin/env bash
[ "${FAKE_GH_OK:-1}" = "1" ] && exit 0
echo "You are not logged into any GitHub hosts." >&2; exit 1
EOF
cat > "$BIN/crontab" <<'EOF'
#!/usr/bin/env bash
[ "${FAKE_CRON_SET:-1}" = "1" ] && echo "*/5 * * * * claude -p --model haiku '/bg-watch check'"
exit 0
EOF
chmod +x "$BIN"/*
export READINESS_CLAUDE="$BIN/claude" READINESS_GH="$BIN/gh" READINESS_CRONTAB="$BIN/crontab"

# --- fake HOME ---
export HOME="$ROOT/home"
mkdir -p "$HOME/.claude/skills/wrapup" "$HOME/.claude/skills/find-docs" "$HOME/.claude/skills/bg-watch" \
         "$HOME/.claude/skills/rebase" "$HOME/.claude/skills/station" "$HOME/.claude/skills/systematic-debugging"
echo '{"permissions":{"defaultMode":"auto"},"advisor":{"enabled":true}}' > "$HOME/.claude/settings.json"

# --- fixture repository ---
REPO="$ROOT/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
mkdir -p "$REPO/docs" "$REPO/.claude" "$REPO/src/api" "$REPO/src/web" "$REPO/tools" "$REPO/node_modules/x" \
         "$REPO/docs/knowledge/people" "$REPO/docs/product/prd" "$REPO/docs/product/roadmap" "$REPO/docs/adr"
# Fill the placeholders of the template, so the version check follows the template of today.
sed -e 's/| Repository | `<owner\/repo>`/| Repository | `acme\/widgets`/' \
    -e 's/| Team prefix | `<prefix>`/| Team prefix | `acme`/' \
    -e 's/| Slack | `<channel name, or none>`/| Slack | `#team`/' \
    -e 's/| tracker | `<gh[^`]*`/| tracker | `gh`/' \
    -e 's/| security | `<built-in[^`]*`/| security | `semgrep`/' \
    -e 's/| code-quality | `<built-in[^`]*`/| code-quality | `sonarqube`/' \
    -e 's/| monitoring | `<built-in[^`]*`/| monitoring | `built-in`/' \
    -e 's/| feedback | `<none[^`]*`/| feedback | `none`/' \
    -e 's/| ux-quality | `<none[^`]*`/| ux-quality | `none`/' \
    "$TEMPLATE" > "$REPO/docs/adlc.md"
echo '{"graphs":{"knowledge":{"path":"docs/knowledge"},"prd":{"path":"docs/product/prd"},"roadmap":{"path":"docs/product/roadmap"},"adr":{"path":"docs/adr"}}}' > "$REPO/.claude/knowledge.json"
printf '# Widgets\n\nRun `make verify` before a PR.\n' > "$REPO/CLAUDE.md"
printf 'node_modules\n' > "$REPO/.gitignore"
echo "def main(): pass" > "$REPO/src/api/app.py"
echo "console.log(1)" > "$REPO/src/web/index.ts"
echo "echo hi" > "$REPO/tools/run.sh"
echo "x" > "$REPO/node_modules/x/index.js"
printf '# api\n\nRead app.py.\n' > "$REPO/src/api/CLAUDE.md"
# A router that is too long (40 lines) in tools/.
for i in $(seq 1 40); do echo "line $i"; done > "$REPO/tools/CLAUDE.md"

# new_case NAME: a fresh folder for the output of one case.
new_case() { C="$ROOT/case-$1"; mkdir -p "$C"; unset FAKE_GH_OK FAKE_CRON_SET SLACK_BOT_TOKEN; }
readiness() { python3 "$SCRIPT" "$@" > "$C/out" 2> "$C/err"; echo $? > "$C/rc"; }

# --- the fixture repository ---
new_case full
export SLACK_BOT_TOKEN="xoxb-secret-token-value"
readiness --repo "$REPO" --json
check "full: exit 0"                            rc_is 0
check "full: each line is a JSON item"          every_line_is_json
check "full: claude cli ok"                     status claude-cli ok
check "full: autocompact ok"                    status autocompact ok
check "full: permission mode ok"                status permission-mode ok
check "full: advisor ok"                        status advisor ok
check "full: root CLAUDE.md ok"                 status root-claude-md ok
check "full: src/web has no router"             status folder-routers wrong
check "full: names src/web"                     detail_has folder-routers "src/web"
check "full: node_modules is skipped"           not detail_has folder-routers "node_modules"
check "full: tools router too long"             status router-length wrong
check "full: names tools/CLAUDE.md"             detail_has router-length "tools/CLAUDE.md (40 lines)"
check "full: gitignore ok"                      status gitignore ok
check "full: git exclude missing"               status git-exclude-sofa missing
check "full: verify named in CLAUDE.md"         status verify-skill ok
check "full: brain prd ok"                      status brain-prd ok false
check "full: brain roadmap ok"                  status brain-roadmap ok
check "full: brain ddd missing, not blocking"   status brain-ddd missing false
check "full: brain system-design missing"       status brain-system-design missing
check "full: adlc ok"                           status adlc ok
check "full: adlc version ok"                   status adlc-version ok
check "full: placeholders left"                 status adlc-placeholders wrong
check "full: names a placeholder key"           detail_has adlc-placeholders "Board tool"
check "full: scheduler ok"                      status scheduler ok
check "full: state store missing"               status state-store missing
check "full: gh auth ok"                        status gh-auth ok
check "full: tool gh on PATH"                   status tool-tracker ok
check "full: tool semgrep not on PATH"          status tool-security missing
check "full: tool sonarqube unknown"            status tool-code-quality unknown
check "full: tool built-in ok"                  status tool-monitoring ok
check "full: plugin product ok"                 status skill-product ok
check "full: plugin slack disabled is missing"  status skill-slack missing
check "full: plugin relay missing"              status skill-relay missing
check "full: skill from HOME ok"                status skill-systematic-debugging ok
check "full: built-in verify not listed"        absent skill-verify
check "full: own skill wrapup not listed"       absent skill-wrapup
check "full: slack token set"                   status slack ok
check "full: token never printed"               hasnt "$C/out" "xoxb-secret"
check "full: people page ok"                    status people-page ok

# --- the same repository, with the fakes in their bad modes ---
new_case bad
export FAKE_GH_OK=0 FAKE_CRON_SET=0 READINESS_CLAUDE="$BIN/claude-old"
readiness --repo "$REPO" --json
export READINESS_CLAUDE="$BIN/claude"
check "bad: exit 0"                             rc_is 0
check "bad: gh not logged in blocks"            status gh-auth wrong true
check "bad: scheduler missing"                  status scheduler missing
check "bad: old claude is wrong"                status claude-cli wrong true
check "bad: slack token not set"                status slack missing
check "bad: plugins from empty list missing"    status skill-product missing

# --- settings that are wrong ---
new_case settings
echo '{"autoCompactEnabled":false,"permissions":{"defaultMode":"default"},"advisorEnabled":false}' > "$HOME/.claude/settings.json"
readiness --repo "$REPO" --json
echo '{"permissions":{"defaultMode":"auto"},"advisor":{"enabled":true}}' > "$HOME/.claude/settings.json"
check "settings: autocompact off is wrong"      status autocompact wrong
check "settings: default mode is wrong"         status permission-mode wrong
check "settings: advisor off is wrong"          status advisor wrong

# --- no settings at all ---
new_case nosettings
rm "$HOME/.claude/settings.json"
readiness --repo "$REPO" --json
echo '{"permissions":{"defaultMode":"auto"},"advisor":{"enabled":true}}' > "$HOME/.claude/settings.json"
check "nosettings: permission mode unknown"     status permission-mode unknown
check "nosettings: advisor unknown"             status advisor unknown
check "nosettings: autocompact ok"              status autocompact ok

# --- an old adlc version ---
new_case oldversion
sed -i 's/sofa-template-version: [0-9]*/sofa-template-version: 5/' "$REPO/docs/adlc.md"
readiness --repo "$REPO" --json
sed -i "s/sofa-template-version: 5/sofa-template-version: $(sed -n 's/.*sofa-template-version: \([0-9]*\).*/\1/p' "$TEMPLATE")/" "$REPO/docs/adlc.md"
check "oldversion: wrong and blocks"            status adlc-version wrong true

# --- an empty git repository ---
new_case empty
EMPTY="$ROOT/empty"; mkdir -p "$EMPTY"; git -C "$EMPTY" init -q
readiness --repo "$EMPTY" --json
check "empty: exit 0"                           rc_is 0
check "empty: adlc missing blocks"              status adlc missing true
check "empty: brain prd missing blocks"         status brain-prd missing true
check "empty: brain roadmap missing blocks"     status brain-roadmap missing true
check "empty: root CLAUDE.md missing"           status root-claude-md missing
check "empty: no code folder is ok"             status folder-routers ok
check "empty: skills come from the template"    status skill-relay missing
check "empty: people page unknown"              status people-page unknown
check "empty: slack unknown"                    status slack unknown

# --- the text table ---
new_case table
readiness --repo "$REPO"
check "table: exit 0"                           rc_is 0
check "table: header row"                       has "$C/out" "area"
check "table: blocks line"                      has "$C/out" "blocks start:"

# --- not a git repository ---
new_case nogit
mkdir -p "$ROOT/plain"
readiness --repo "$ROOT/plain" --json
check "nogit: exit 2"                           rc_is 2
check "nogit: says so"                          has "$C/err" "not a git repository"

echo
if [ "$fails" -eq 0 ]; then echo "all cases pass"; exit 0; fi
echo "$fails case(s) failed"; exit 1
