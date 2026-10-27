# bg-watch: design

Date: 2026-10-27. Size: small change.

## Intent

Background Claude Code sessions sometimes stop on an `API Error` and then do nothing. The `bg-watch` skill finds these sessions on a schedule, restarts them, and sends them `retry`.

The skill is also a test bed for jag. jag decides which sessions are stuck, and the skill keeps a record of each jag call, so that the user can find where jag answers incorrectly and improve it.

## Goals

- Find each stuck session, restart it, and send it `retry`, with no person in the loop.
- Use jag for the stuck decision.
- Keep a record of each jag call that the user can run again after a change to jag.

## Non-goals

- Fix the cause of the API errors.
- Watch sessions on other machines.
- Keep the schedule alive after the host session ends, or after 7 days.

## Anti-goals

These make the skill a failure, even if it works:

- It deletes a session (`claude rm`).
- It restarts a session that is in the middle of a turn (`busy`).
- It replaces the jag decision with the script's own rule. Then it gives no data about jag.

## Approaches

1. **Schedule in a background session (chosen).** `start` calls `CronCreate` in a background session. Few parts, and close to the reference that already worked. The schedule stops when the session ends and expires after 7 days.
2. **The same, with `durable: true`.** Needs less attention, but the meaning of `durable` must first be checked in the docs.
3. **A systemd timer that runs `claude -p`.** Does not expire, but starts a new Claude process for each check, writes its report to a file, and needs setup on each machine.

The user chose 1. A change to 2 later is one line in `SKILL.md`.

## Decided

- Name: `bg-watch`, in `skills/bg-watch/`. The slash command is `/bg-watch`.
- Modes: `start [interval]` (default `5m`), `check`, and `stop`, as in the reference `SKILL.md`. The schedule prompt is `/bg-watch check`.
- A session is stuck when an `API Error` line is the last real event in its `claude logs` output.
- jag decides, with `jag --json --max-chars 8000 --ask`. If `--ask` exits 3 to 6, the script uses `jag -F stuck=true`. If jag is not installed, it uses its own `stuck` flag.
- The script also computes its own `stuck` flag for each session. This flag is only for comparison. It does not change the decision.
- The rules of the reference stay: never `claude rm`, skip `busy`, skip the session that runs the skill, never read `~/.config/jag/`, never run `jag --check` or `jag --setup`.

## Proposed by Claude

- **jag log.** Each check adds one line to `~/.claude/bg-watch/jag-log.jsonl`: the time, the jag command, the mode, the exit code, the duration, the path of the input file, the jag output, and the sessions where jag and the flag do not agree. The input file of each check stays next to the log with a time stamp in its name, so that the same call can run again.
- **jag part of the report.** The report shows the mode that ran and each session where jag and the flag do not agree.
- **State folder** `~/.claude/bg-watch/` (the reference used `~/.claude/bg-session-watch/`). `BG_WATCH_STATE` changes it, as in the reference.
- **Defect fixes:**
  - A busy stuck session shows `STUCK (+1), skipped (busy)`, not `restarted: skipped (busy)`.
  - The failure history removes a session that `claude agents --all` no longer lists.
- **Test:** `skills/bg-watch/tests/` runs the scripts with fake `claude` and `jag` commands on sample log text. It checks the stuck flag, the busy skip, the jag fallback, the jag log line, and that the script never calls `claude rm`.
- **README:** one line in the table, and `bg-watch` in the install command and the test list.
- **Clean up:** after the merge, the user deletes the temporary `bg-watch/` folder at the root of the main checkout.

## Left to the builder

- The exact text of the report table.
- How many input files to keep. A sensible limit is the last 500.
