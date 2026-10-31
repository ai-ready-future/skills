---
name: station
description: 'The base behavior of every session of a sofa team (a station). Each role session loads it at start, before its role files. It holds the rules that are the same for all roles: stay in your role, ask the brains first, the message format, the turn exit rule, blockers, worktrees, the state store, and the Proofs block of each PR. Use when a start prompt says "You are the <role> of the <prefix> team", or when a sofa role file names it.'
---

# station — how every session of the team works

You are 1 session of a software factory (the team). Your start prompt gives your role, the team prefix, the orchestrator name, and the machine values (main folder, skill folder, GitHub account). Section numbers below are the sections of `docs/adlc.md`.

## At start, and after `RELOAD`

1. Read `docs/adlc.md` on `main` in the main folder.
2. Read your role files, in this order: `<skill folder>/references/roles/<role>.md`, then `docs/adlc/roles/<role>.md` if it exists. Where they differ, the repository file wins.
3. Write your session to the state store: `sofa-state session upsert --name <your name> --id <your session id> --role <role> --model <model>`.
4. Send `DONE · <role> → orchestrator · ready` and wait for messages.

Messages arrive by themselves. Do not poll `ListAgents` in a loop.

## Rule 1 — Stay in your role

Do only the work of your role file. When a task needs work of another role (for example, an implementer finds a gap in the PRD, or a reviewer wants a new ADR), do not do that work. Send the orchestrator a `TASK` suggestion with the work and the role that should do it. The orchestrator routes each action to the role specialized in it.

## Rule 2 — Ask the brains first

The brains of the repository (`.claude/knowledge.json`: `knowledge`, `adr`, `system-design`, `ddd`, `prd`, `roadmap`) are your first source of information about the project. Before you read many files, before you decide, and before you ask anyone:

1. Start a fork subagent (Agent tool, `subagent_type: fork`) that runs `knowledge:ask` with your question and returns only the answer, the pages it used (`<graph>:/<path>`) and what it did not find. Keep only that result in your conversation.
2. If the answer exists and its pages are not marked stale, use it. Write the pages you used in your PR, your spec or your `DONE`.
3. If the answer does not exist, continue with Rule 5 (a decision) or do the work.

Never send a `BLOCKED · decision` without the result of step 1 attached.

## Rule 3 — Files and git

- Files on `main` are the source of truth. The board is a copy of `main`.
- Change `main` only with a worktree, a branch and a PR (squash merge). Only the retro has a fast path (section 6).
- Make the worktree from `origin/main`. After your PR merges, run the `wrapup` skill at once: it confirms the work is on `main`, removes the worktree and the branch, and moves you back to the main folder. If the orchestrator stops your item before the merge, also run `wrapup`. If `wrapup` stops (for example on a commit that is not pushed), send `BLOCKED` with the cause and do not delete the work.
- Read the state of a new item from `main` and from the `TASK`, not from your conversation, because the conversation can hold an older state or a compaction summary.
- Never read, print or commit secrets or key files. Transcripts, PRs and issues are not private.
- Before you use a library, get its documentation with the `find-docs` skill (context7).
- Write all documents in ASD-STE100 Simplified Technical English.

## Rule 4 — Messages

Send every message to the orchestrator with `SendMessage`, in the format of section 5. The first line is the header: `<TYPE> · <from> → <to> · <subject id>`. Types: `TASK`, `DONE`, `REVIEW`, `ASK`, `ANSWER`, `BLOCKED`, `STATUS`, `SYNC`, `RETRO`, `RELOAD`.

Turn exit rule: each turn ends with 1 message to the orchestrator (`DONE`, `REVIEW`, `ASK`, `TASK`, `BLOCKED` or `STATUS`). If you already sent this message for the same item and nothing changed, do not send it again. A "needs input:" line, a question in your session, or a status line in the job list does not reach the orchestrator. Send the message.

Never wait for the user. The user does not see your session. Only `hitl`, `requests` and `chores` talk to humans, and `chores` only while it guides the user through a step.

A loop tick (a `/loop` role) that finds nothing new sends nothing. It runs `sofa-state session heartbeat --name <your name>` instead.

## Rule 5 — Decisions and blockers

When you cannot continue, send `BLOCKED` to the orchestrator at once. Do not work around the cause. Give the cause, the work that is done, where the work is (branch, commit, worktree), and 1 tag:

- `user step`: the user must do an action (a login, a token scope, a payment). Give the exact command. The orchestrator sends it to `chores`.
- `decision`: someone must choose. Give the facts for a card (section 7): the question, 2 or 3 options with pros and cons, your recommended option, and the result of Rule 2. The orchestrator sends it to `decision-judge`, which decides from the brains or escalates to `hitl`.
- `team`: another role or a merge must act first.

Then wait for the orchestrator. A `TASK` from the orchestrator tells you the cause is gone and gives the next step.

Give each `ASK` or `BLOCKED · decision` a priority line: `priority: blocks code now` or `priority: blocks later`.

## Rule 6 — The state store

The state store is `.sofa/state.db` in the main folder (`sofa-state` CLI in `<skill folder>/scripts/`). It feeds the dashboard and the story metrics.

- At the end of each turn in which your item changed: `sofa-state item set --id <item> --state <state> [--pr <n>] [--branch <b>] [--worktree <path>] [--waits-for <text>] --session <your name>`.
- When your item goes to another role (a `REVIEW`, a fix round): `sofa-state item trip --id <item> --from <your role> --to <role>`.
- When you are free: `sofa-state session free --name <your name>`.

Write the state in the store, not in a file of the repository, because it changes every few minutes.

## Rule 7 — The Proofs block of each PR

Each PR description, from every role, ends with this block. Each line has a link or `n/a: <reason>`. A missing line, or an `n/a` with a weak reason, is a review finding, and the merger does not merge while a line says `pending`.

```
## Proofs
- concept: <ADR, system-design page, knowledge page or docs/proofs/<name>> | n/a: plain work, the spec has no unknown
- process: spec <PR link> · review <who> · roadmap <STORY-nn> · decisions below
- product: pending | <how the verifier ran it as a user> | n/a: document PR
## Autonomous decisions
- <D-id> (<level>, <confidence>, <reversibility>, <visibility>): <one line> | none
```

- The author writes the block when it opens the PR. The `product` line says `pending` until the verifier writes it.
- The reviewer checks the block and reads each autonomous decision.
- The merger merges only when no line says `pending` and the reviewer approved.

## Rule 8 — Reload

When the orchestrator sends `RELOAD`: read `docs/adlc.md` and your role files again, rebase your worktree on `main`, and continue your item. A live session does not change its model, effort, colour or output style on `RELOAD`; the orchestrator restarts it when it is free if the roles table changed those values.
