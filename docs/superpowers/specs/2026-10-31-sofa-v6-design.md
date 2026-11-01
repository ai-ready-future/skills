# sofa v6 — the factory with 29 roles

Date: 2026-10-31. Skill: `sofa`, template version 5 → 6.
Source: a grilling session on the ideas list of the user. Each decision below is confirmed.

## 1. Principles

- **Three proofs.** A job is done when it has evidence, not a claim. The proofs are gates in the flow, and each PR has 1 line per proof with a link to the evidence or `n/a: <reason>`. A missing line blocks the merge.
  - *Proof of concept*: the idea works. The `specifier` spots the need (only when a spec has an unknown: a new library, a performance question, an integration). It first asks the `researcher` for existing proofs. If none exist, it asks the orchestrator, and the orchestrator coordinates the team: the proof is research or a prototype. Prototypes live in `docs/proofs/<name>/` and the docs reference them. The owner of the brain learns the result: `architect` → ADRs, `designer` → system design, `researcher` → `knowledge`. The brain owners capture; they do not build.
  - *Proof of process*: the team followed its own rules. `reviewer` checks the Proofs block of the PR. `plan-auditor` checks again after the merge.
  - *Proof of product*: the product works for a user. `verifier` before the merge. `monitoring`, `feedback` and `ux-quality` after the release.
  - *Proof of intent*: the team built what the human asked. Per feature, not per PR. `monitoring` and `feedback` propose a score, `hitl` confirms it, `plan-auditor` writes it.
- **Autonomy is unlocked by knowledge.** A station decides alone only when the brains hold the answer. Else the question goes to `decision-judge`, then to `hitl`. The brains grow, and fewer questions reach a human.
- **Route each action to the role specialized in it.** No role does the work of another role. Out-of-role work goes back to the orchestrator as a `TASK` suggestion.

## 2. Story and feature states and metrics

- New state `released`, after `done`. `monitoring` sets it when the feature runs in production as expected for the *healthy window* (setup value, default 24 hours). A feature with no metric to watch gets 1 `ASK` to hitl.
- `feedback` and `ux-quality` raise new stories to the orchestrator; `planner` writes them.
- Story metrics (fields in the roadmap frontmatter, written only by `plan-auditor`, copied from the state store when the story reaches `released`): `hitl_questions`, `autonomous_decisions`, `review_defects`, `trips` (implementer → verifier → reviewer → tester rounds), `picked_up_at`, `released_at`.
- Feature metrics: `proofs: {concept, process, product, intent}`, each 0..100.

## 3. Knowledge

- Local knowledge = all brains that `.claude/knowledge.json` lists: `knowledge` (generic), `adr`, `system-design`, `ddd`, `prd`, `roadmap`. `knowledge:ask` crosses them. Setup runs each brain setup and checks the registry has each name.
- Stations use `knowledge:ask` as their primary source of project information. They run it in a fork subagent that retrieves and synthesizes, and keep only the answer. Before a `BLOCKED · decision`, a station runs it and attaches what it returned.
- Writes: `architect` → `adr`; `designer` → `system-design`; `business-domain` → `ddd`; `planner` → `prd` and `roadmap`; `scribe` → `knowledge`, and the veracity metadata of every brain.
- Veracity: each page gets `veracity` (1..100) and `last_validated`. `decision-judge` calls `knowledge:validate` on the pages it used when hitl confirms a decision. Effective validity = f(veracity, age since last validation). A stale page lowers the confidence of `decision-judge`. `scribe` runs a monthly staleness pass.
- Human team: `setup` runs an interview and `scribe` learns the team (who, role, what they decide) into `knowledge`. When a person that the brain does not know talks to the factory, `requests` interviews them and `scribe` adds them.

## 4. decision-judge

Model: PR 207 of `ai-advanced-futures/claude-code-dev-plugins` (assessor subagent, level × confidence tables, set-aside list).

- Flow: station → `BLOCKED · decision` → orchestrator → `decision-judge`. It runs `knowledge:ask` in a fork, starts the assessor subagent (`references/assessor.md`), cross-checks the pick, and reads a cell: `decide` or `ask`.
  - `decide`: sends `ANSWER` with the line `decided by: decision-judge (<level>, <confidence>, <reversibility>, <visibility>)`, writes the decision to the state store (per story), and sends a `TASK` to `scribe` to learn the fact.
  - `ask`: sends the card to `hitl`.
- Assessor dimensions: **level** (detail / middle / direction), **confidence** (high / medium / low, from the brains and their validity), **reversibility** (reversible / hard to reverse / irreversible: always ask), **visibility** (visible / hidden: how easy it is to spot the result).
- Caution band selects the table: points = reversibility (0 / 2) + visibility (0 / 1) + stage of the feature (new 0 / released 1, read from the roadmap) + risk appetite of the repository (`mvp` 0 / `early customers` 1 / `established` 2). Band: 0–1 `relaxed`, 2–3 `normal`, 4+ `strict`. The 3 tables and the points are in `docs/adlc.md`; the retro edits them. Risk appetite is a setup value.
- A `blocks later` question is never decided at level `direction`.
- Daily digest: `hitl` posts the autonomous decisions of the day. A human vetoes one by number: it becomes an `ASK`, and the pages it used lose veracity.
- The PR lists the autonomous decisions of its story. `reviewer` reads each one.

## 5. hitl, requests and Slack

- Slack is optional. `setup` installs it any time with the Slack plugin and a bot token (in env or `~/.claude/settings.json`, never in the repo). One channel per team.
- `ASK` threads belong to `hitl`; `REQUEST` threads belong to `requests`. Without Slack, `hitl` uses `AskUserQuestion` and `requests` listens on its own session.
- `hitl` polls the open threads on a `/loop` (3 minutes) and keeps `last seen` per thread. On each new message it picks 1 action: **silent** (default), **interject** (once per thread, only a fact from the brains with its source), **summarize** (a human wrote `decided` or `confirmed`, or the last messages agree and the thread is quiet). The summary starts with "I read:". A ✅ or another positive emoji, or `confirmed` / `decided`, closes it. Another reply gives a corrected summary.
- `requests` is inbound only: clarifies, writes the done criterion, answers project questions with `knowledge:ask`, and sends new work to the orchestrator for `planner`. It writes no roadmap file.

## 6. The station skill

Every session loads `sofa:station`. It holds the behavior that is the same for all roles, so the role files hold only the differences. Section 2 of the template (15 rules) moves here; `docs/adlc.md` keeps the setup values, the repository rules, the roles table, the flows, the message formats and the change log. Content:

- Stay in your role. Out-of-role work → `TASK` suggestion to the orchestrator.
- Read `docs/adlc.md` and your role files at start and on `RELOAD`.
- `knowledge:ask` in a fork is your first source. Attach its result to each `BLOCKED · decision`.
- The message format, the turn exit rule, the `BLOCKED` tags, `wrapup` after a merge, the worktree rule, secrets.
- A loop tick that finds nothing sends nothing; it writes a heartbeat to the state store.
- Write your item status to the state store at each turn end (`sofa-state`).
- Only `hitl`, `requests` and `chores` talk to humans.
- The Proofs block of each PR.

## 7. Roles (29)

Tier `always`: started at team start, kept live. Tier `on demand`: started by the orchestrator when an item needs the role; stopped after 1 hour free.

| Role | Tier | Model | Owns / does |
|---|---|---|---|
| orchestrator | always | opus | routes, queue, work status |
| hitl | always | sonnet | cards, Slack ASK threads, digest |
| requests | always | sonnet | inbound requests, human team |
| decision-judge | always | opus | decides or escalates |
| scribe | always | sonnet | `knowledge` brain, veracity |
| tracker | always | haiku | board = copy of `main` + claims |
| plan-auditor | always | sonnet | roadmap vs `main`, metrics |
| merger | always | haiku | rebase, squash merge |
| scheduler | always (system cron) | haiku | `bg-watch check` every 5 min |
| monitoring | always | sonnet | logs, metrics, `released` |
| retro | on demand | opus | `docs/adlc.md` |
| planner | on demand | opus | PRD, roadmap |
| architect | on demand | opus | ADRs only |
| designer | on demand | opus | system design, code map |
| business-domain | on demand | opus | `ddd` brain, domain review of specs |
| specifier | on demand | opus xhigh | specs, spots proof of concept |
| implementer | on demand | sonnet | code PRs |
| reviewer | on demand | opus | code review, Proofs block, decisions |
| verifier | on demand | opus | runs the product, product proof line |
| tester | on demand | sonnet | e2e tests |
| security | on demand | sonnet | `/security-review`, external scanner |
| code-quality | on demand | sonnet | lint, types, `/simplify` report, sonarqube |
| researcher | on demand | opus | studies, existing proofs |
| troubleshooter | on demand | opus | root cause, proposed fix |
| operator | on demand | sonnet | runs commands in environments |
| feedback | on demand (loop) | haiku | feedback sources |
| ux-quality | on demand (loop) | sonnet | Sentry / PostHog |
| updater | on demand (daily loop) | haiku | skill and plugin versions |
| chores | on demand | sonnet | user steps |

Output style column: orchestrator `Proactive`; requests, researcher, troubleshooter `Explanatory`; all others `Concise`. The names are built-in and case-sensitive.

Renames: `prd:*` → `product:*`, `adr:*` → `architecture:*`, `pr-flow:reviewing-prs` → `code-review:reviewing-prs`, `ui-judge:*` → `playwright`.

## 8. Who writes which file

| File or brain | Writer |
|---|---|
| PRD, roadmap stories and features | planner |
| specs | specifier |
| story and feature metrics, missing stories | plan-auditor |
| board | tracker |
| `adr` | architect |
| `system-design`, nested `CLAUDE.md` routers, `.claude/rules` | designer |
| `ddd` | business-domain |
| `knowledge`, veracity of all brains | scribe |
| `docs/adlc.md`, `docs/adlc/roles/` | retro |
| state store | hooks and `sofa-state` |

## 9. Code map

- Nested `CLAUDE.md` = router: under 30 lines, what the folder holds, 1 line per subfolder, where the tests are, 1 link to the system-design page. No rules.
- `.claude/rules/<topic>.md` with `paths:` = rules scoped to files. They load only when a matching file is touched.
- Root `CLAUDE.md` stays short. `designer` grooms the routers when a PR adds or removes a folder. `reviewer` flags a new folder without a router. `readiness` checks that each folder with code has a router under 30 lines.

## 10. readiness, setup, maturity

- `sofa:readiness` (read-only): a table of each item (present / missing / wrong) with the fix command. Items: `autocompact`, auto mode, advisor, output styles; `CLAUDE.md` current, routers, `.gitignore`, `verify` and `simplify` wired; brains registered and passing their checks; each skill of the roles table installed; each tool per role configured or `built-in`; Slack; cron; state store; human team in the brain.
- `sofa:setup` (idempotent, any time): runs `readiness`, then fixes each item one at a time (osaat). Script-level fixes it does itself (registry add, cron line, `.git/info/exclude`, state store). Built-in commands the model cannot run (`/init`, `/autocompact`, `/config`, brain setups) it prints with the `$ ` prefix and waits, then re-checks. Holds the 2 interviews: the human team, and the tool per role (tracker, security, code quality, monitoring, feedback, ux). Answers go into section 1 of `docs/adlc.md`.
- `sofa:maturity`: scores the proofs per story, the hitl-questions trend, the veracity of the brains, and the prompts of the repo. Offers `prompt:review` and `prompt:revise`. Writes `docs/adlc/maturity-<date>.md`.

## 11. dispatch and scheduler

- `scripts/dispatch.sh --adlc <path> --role <role> [--n N] (--prompt-file F | --prompt T) [--resume ID] [--cwd DIR] [--dry-run]`: reads the row of the role from the ADLC file, starts `claude --bg -n <prefix>-<role>[-n] --model --effort --autocompact --settings '{"outputStyle":"..."}' --permission-mode bypassPermissions "<prompt>"`, prints `<session id> <session name>`. Tests: a fake `claude` in `tests/fake/`, and 1 real smoke test that proves `--settings` reaches the bg session.
- `scheduler`: a crontab line every 5 minutes runs `claude -p --model haiku "/bg-watch check"` outside any long session. `setup` installs it. The orchestrator status check keeps only the work status (stuck items), not restarts.

## 12. State store, dashboard, commands

- `.sofa/state.db` (SQLite, WAL, busy timeout) in the main folder, git-ignored through `.git/info/exclude`. Tables: `sessions`, `items`, `messages` (header only, never the body), `decisions`, `human_interactions`, `usage` (tokens per session per item), `heartbeats`.
- Writers: the mod hooks `classic.SessionStart`, `classic.Stop`, `classic.PostToolUse` and runs `sofa-state`; the station skill runs `sofa-state item ...` at turn end. Token usage comes from `~/.claude/jobs/<id>/`.
- Dashboard: the mod opens a pane with sessions, items, queue, open asks. `sofa-state report` prints the same table.
- Commands: `/sofa:status`, `/sofa:request <text>`, `/sofa:pause [--now]`, `/sofa:resume`, `/sofa:handoff`, `/sofa:stop`.

## 13. Plugin layout and install

- `skills/sofa/` is a plugin: `.claude-plugin/plugin.json`, `skills/{sofa,station,readiness,setup,maturity}/SKILL.md`, `commands/*.md`, `hooks/` (mod), `scripts/`, `references/`, `templates/`, `tests/`.
- The repo root gets `.claude-plugin/marketplace.json` with `sofa` at `./skills/sofa`. Install: `claude plugin marketplace add ai-ready-future/skills`, `claude plugin install sofa@ai-ready-future-skills`. A local checkout added as a folder marketplace is read in place.

## 14. Migration v5 → v6

`templates/MIGRATION.md` maps each v5 section to v6: section 2 → station skill; new rows; renamed skills; `.sofa.state.json` → `.sofa/state.db`; new section 1 values (risk appetite, environments, healthy window, tools per role); new states and metrics.

## 15. Phases (one PR)

1. Foundation: plugin layout, station, dispatch, sofa-state + dashboard, renames, readiness, setup, template v6 with all 29 rows and all role files.
2. Autonomy: decision-judge, scribe, plan-auditor, merger, Proofs block, caution tables.
3. Humans and ops: Slack for hitl and requests, operator, monitoring, troubleshooter, security, code-quality.
4. The rest: ux-quality, feedback, updater, maturity, business-domain and designer grooming.

## 16. Handoff to the plugin session (not in this PR)

1. `knowledge` base schema: `veracity` 1..100 and `last_validated` stamp, inherited by every brain.
2. `knowledge:validate <graph>:/<path> --by <actor>`: raises veracity, sets `last_validated`. A check rule that lowers the effective validity by age.
3. `architecture:ask` and `business-domain:ask`: add `Agent` and `Skill` to `allowed-tools`.
4. `product` WorkItem: fields `hitl_questions`, `autonomous_decisions`, `review_defects`, `trips`, `picked_up_at`, `released_at`, `proofs {concept, process, product, intent}`; state `released`.
5. `product`: `prd.py set` accepts these fields, so `plan-auditor` can write them.
