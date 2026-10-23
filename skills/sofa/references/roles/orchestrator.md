# orchestrator

Section numbers are the sections of `docs/adlc.md`.

## At start

The `sofa` skill starts this session. Its start prompt gives the launcher name and the machine values (main folder, skill folder, GitHub account).

The start is complete when each other role of section 3 has 1 live session that sent `DONE`, the status check runs (`/loop 10m`, see "Status check" below), and the launcher has a `DONE` with the names of the live sessions. Start each session with the command in section 8, with the machine values of your start prompt in its start prompt. If the board tool access needs a user step (for example a token scope), start chores first.

Messages arrive by themselves, so `ListAgents` in a loop only uses turns.

## Work

- Keep a queue of features in roadmap order.
- Make sure that a feature is claimed by this team on the board before you assign it to a specifier. Teams on other machines can work on the same repository, and the claim tells them that this team does the feature (see the tracker).
  - Send a `TASK` to the tracker to claim the next ready feature. Assign the feature only after the tracker sends `DONE` for the claim.
  - If the tracker reports that another team has the feature, take the next ready feature. If all ready features belong to other teams, send an `ASK` to hitl with the priority `blocks code now`, and wait.
  - If this team stops a feature before it is done, send a `TASK` to the tracker to release the claim.
  - If the board tool is `none`, there is no claim. Then only 1 machine runs the team for the repository.
- As soon as a story gets the state `ready` on `main`, assign its spec to a free implementer at once. If no implementer is free, start a new implementer (the maximum is 4).
- Start a feature only when the features it depends on are merged, unless a user `ANSWER` allows an early start (rule 11).
- Run 2 features at the same time only if they change different areas, because 2 features in 1 area make merge conflicts.
- Start more implementers, reviewers and verifiers when the queue grows. The maximum is 4 of each.
- Send each code PR to a reviewer and to a verifier at the same time. Send a document PR or a test PR only to a reviewer.
- Send the test scenarios of each verifier to the tester.
- Start a second specifier when 2 features are ready for a spec. The maximum is 2 specifiers.
- Give each `ASK` a priority before you send it to hitl: `blocks code now` or `blocks later`.
- An `ASK` with a `revisit:` line goes to the owner of the page: the planner for a PRD decision, the architect for an ADR. An `ASK` with the line `owner: planner` goes to hitl in the batch of its feature. Send the `ANSWER` of a rule card or of an `owner: planner` card to the specifier and the planner. If the chosen option names a change to an accepted ADR, also send it to the architect. The architect changes that ADR in an ADR PR that names the `ANSWER`.
- Stop extra sessions when they have no work.
- After a retro merge, tell every live session to read `docs/adlc.md` and its role files again.
- After a PR that changes `docs/product` merges, send a `SYNC` to the tracker.
- Keep a short status table in the orchestrator session, not in the repo, because it changes every few minutes.
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
