#!/usr/bin/env bash
# Tests the game template and the self-test runner.
# Usage: bash tests/game-selftest.test.sh
# Exit 0 when every case matches, 1 otherwise.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0

# game NAME DATA: writes $tmp/NAME.html, the template with DATA as the GAME object.
game() {
  node -e '
    const fs = require("fs");
    const [tpl, out, data] = process.argv.slice(1);
    const html = fs.readFileSync(tpl, "utf8").replace(/(\/\*GAME_DATA_START\*\/)[\s\S]*?(\/\*GAME_DATA_END\*\/)/, (m, a, b) => a + "\nconst GAME = " + data + ";\n" + b);
    fs.writeFileSync(out, html);
  ' "$here/templates/call-game.html" "$tmp/$1.html" "$2"
}
# check NAME WANT: runs the runner on $tmp/NAME.html (or the template) and compares the exit code.
check() {
  local file="$tmp/$1.html"; [ "$1" = template ] && file="$here/templates/call-game.html"
  node "$here/scripts/game-selftest.mjs" "$file" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1 (exit $got, want $2)"; fails=$((fails+1)); fi
}
opt() { echo "{ t: \"$1\", p: $2, why: \"$3\", r: \"Okay.\" }"; }
scene() { echo "{ min: \"Minute 1\", who: \"Buyer\", say: \"Hello.\", best: \"Ask.\", opts: [ $(opt Ask 10 "${1-Good.}"), $(opt Pitch "${2:-0}" Bad.), $(opt Wait 4 Meh.), $(opt Talk 5 Meh.) ] }"; }
results='[ { min: 90, label: "Won", text: "Good." }, { min: 0, label: "Lost", text: "Try again." } ]'
data() { echo "{ title: \"T\", intro: \"I\", start: \"S\", scenes: [ $1 ], results: $results }"; }

check template 0
game good "$(data "$(scene)")";                                         check good 0
chapter='{ chapter: "Part one", text: "Open." }'
game chapter "$(data "$chapter, $(scene)")";                           check chapter 0
game easy "$(data "$(scene Good. 2)")";                                check easy 1
game empty "$(data "$(scene '')")";                                    check empty 1
game dash "$(data "$(scene 'Good — bad.')")";                          check dash 1

[ "$fails" -eq 0 ]
