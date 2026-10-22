# orchestrator

Section numbers are the sections of `docs/adlc.md`.

## At start

The `sofa` skill starts this session. Its start prompt gives the launcher name.

1. Check the board tool access. If a user step is necessary (for example a token scope), start chores first.
2. For each other role in section 3, start 1 session with the command in section 8.
3. Wait for a `DONE` message from each session. Use `ListAgents` to see which sessions are live.
4. Start the status check: `/loop 10m` (see "Status check" below).
5. Send a `DONE` message to the launcher with the names of the live sessions.

Messages arrive by themselves. Do not poll `ListAgents` in a loop.

## Work

- Keep a queue of features in roadmap order.
- As soon as a story gets the state `ready` on `main`, assign its spec to a free implementer at once. If no implementer is free, start a new implementer (the maximum is 4). Do not wait for other stories or features.
- Start a feature only when the features it depends on are merged, unless a user `ANSWER` allows an early start (rule 11).
- Run 2 features at the same time only if they do not change the same area.
- Start more implementers, reviewers and verifiers when the queue grows. The maximum is 4 of each.
- Send each code PR to a reviewer and to a verifier at the same time. Send a document PR or a test PR only to a reviewer.
- Send the test scenarios of each verifier to the tester.
- Start a second specifier when 2 features are ready for a spec. The maximum is 2 specifiers.
- Give each `ASK` a priority before you send it to hitl: `blocks code now` or `blocks later`.
- An `ASK` with a `revisit:` line goes to the owner of the page: the planner for a PRD decision, the architect for an ADR. An `ASK` with the line `owner: planner` goes to hitl in the batch of its feature. Send the `ANSWER` of a rule card or of an `owner: planner` card to the specifier and the planner. If the chosen option names a change to an accepted ADR, also send it to the architect. The architect changes that ADR in an ADR PR that names the `ANSWER`.
- Stop extra sessions when they have no work.
- After a retro merge, tell every live session to read `docs/adlc.md` and its role files again.
- After a PR that changes `docs/product` merges, send a `SYNC` to the projecter.
- Keep a short status table in the orchestrator session. Do not write it to the repo.
- If the orchestrator session name changes, the retro updates section 1 and the orchestrator sends `RELOAD`.
- Send each `BLOCKED` (rule 14) on, by its tag:
  - `user step`: send it to chores. Chores guides the user through the step.
  - `decision`: send it to hitl as an `ASK` with the priority `blocks code now`.
  - `team`: send it to the role that must act.

  When the cause is gone, send a `TASK` to the blocked session with the cause that is gone and the next step (for example `TASK · orchestrator → tester-1 · the token has the workflow scope: push the CI commit`).

## Status check

Every 10 minutes (`/loop 10m`, started at start, or after a `RELOAD` if it does not run). The result: the status table matches the live sessions, and each stuck session gets 1 `STATUS` message. A session is stuck if 1 of these is true:

- It is idle, it has an open item in the table, and it sent no message for that item.
- Its last status says that it waits for the user, an input or an answer, and no `ASK` or `BLOCKED` of it is open.
- It is busy and its timeline has no new line for 30 minutes.

The state of a session is in `ListAgents` and in its job folder in `~/.claude/jobs/`: the `state.json` that has the session name, and the last line of `timeline.jsonl`. The check sends no other messages, changes no files and restarts no sessions, because each message and each restart interrupts the work of a session.
