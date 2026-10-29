# orchestrator

Section numbers are the sections of `docs/adlc.md`.

## At start

The `sofa` skill starts this session. Its start prompt gives the launcher name and the machine values (main folder, skill folder, GitHub account).

The start is complete when each other role of section 3 has 1 live session that sent `DONE`, the status check runs (`/loop 10m`, see "Status check" below), and the launcher has a `DONE` with the names of the live sessions. Start each session with the command in section 8, with the machine values of your start prompt in its start prompt. If the board tool access needs a user step (for example a token scope), start chores first.

Before you start a session, read the state file (see "State file" below) if it exists. It is the status table of an earlier orchestrator of this team. Continue its open items. A session of the team that `ListAgents` shows as live is already started: send it a `RELOAD`, and do not start a second session for its role, because 2 sessions would do the same items.

Messages arrive by themselves, so `ListAgents` in a loop only uses turns.

## Work

- Keep a queue of features in roadmap order.
- Make sure that a feature is claimed by this team on the board before you assign it to a specifier. Teams on other machines can work on the same repository, and the claim tells them that this team does the feature (see the tracker).
  - Send a `TASK` to the tracker to claim the next ready feature. Assign the feature only after the tracker sends `DONE` for the claim.
  - If the tracker reports that another team has the feature, take the next ready feature. If all ready features belong to other teams, send an `ASK` to hitl with the priority `blocks code now`, and wait.
  - If this team stops a feature before it is done, send a `TASK` to the tracker to release the claim.
  - If the board tool is `none`, there is no claim. Then only 1 machine runs the team for the repository.
- As soon as a story gets the state `ready` on `main`, assign its spec to an implementer at once.
- Start a feature only when the features it depends on are merged, unless a user `ANSWER` allows an early start (rule 11).
- Run 2 features at the same time only if they change different areas, because 2 features in 1 area make merge conflicts.
- Send each code PR to a reviewer and to a verifier at the same time. Send a document PR or a test PR only to a reviewer.
- Send the test scenarios of each verifier to the tester.
- Send each study, bench, spike or measurement to the researcher, never to an implementer, because a large study makes the conversation of the implementer long for its next PRs. Send a follow-up question about a result to the researcher that made it.
- Start a second specifier only when 2 features are ready for a spec.
- Give each `ASK` a priority before you send it to hitl: `blocks code now` or `blocks later`.
- An `ASK` with a `revisit:` line goes to the owner of the page: the planner for a PRD decision, the architect for an ADR. An `ASK` with the line `owner: planner` goes to hitl in the batch of its feature. Send the `ANSWER` of a rule card or of an `owner: planner` card to the specifier and the planner. If the chosen option names a change to an accepted ADR, also send it to the architect. The architect changes that ADR in an ADR PR that names the `ANSWER`.
- Use the sessions again (rule 15). Send each new item to a free live session of its role. Start a new session only if no session of the role is free and the role has fewer sessions than its Count in section 3. A session is free when it sent `DONE` for its last item and has no open item in the status table.
  - Keep 1 session of each role live, also when it has no work, because the next item of its role goes to it.
  - If a role has more than 1 session, and 1 of them has been free for 1 hour, stop it (`claude stop <id>`) and delete it (`claude rm <id>`). Then its number is free again (section 8).
- After a retro merge, tell every live session to read `docs/adlc.md` and its role files again.
- After a PR that changes `docs/product` merges, send a `SYNC` to the tracker.
- Keep a short status table, and write it to the state file (see "State file" below). Do not put it in the repo, because it changes every few minutes.
- If the orchestrator session name changes, the retro updates section 1 and the orchestrator sends `RELOAD`.
- Send each `BLOCKED` (rule 14) on, by its tag:
  - `user step`: send it to chores. Chores guides the user through the step.
  - `decision`: send it to hitl as an `ASK` with the priority `blocks code now`.
  - `team`: send it to the role that must act.

  When the cause is gone, send a `TASK` to the blocked session with the cause that is gone and the next step (for example `TASK · orchestrator → tester-1 · the token has the workflow scope: push the CI commit`).

## Status check

Every 10 minutes (`/loop 10m`, started at start, or after a `RELOAD` if it does not run). The result: the status table matches the live sessions, each stuck session gets 1 `STATUS` message, each stopped session with an open item is resumed (section 8), and each extra free session is stopped and deleted (see "Work"). A session is stuck if 1 of these is true:

- It is idle, it has an open item in the table, and it sent no message for that item.
- Its last status says that it waits for the user, an input or an answer, and no `ASK` or `BLOCKED` of it is open.
- It is busy and its timeline has no new line for 30 minutes.

The state of a session is in `ListAgents` and in its job folder in `~/.claude/jobs/`: the `state.json` that has the session name, and the last line of `timeline.jsonl`. The check sends no other messages, changes no file other than the state file, and restarts no live session, because each message and each restart interrupts the work of a session.

## State file

The status table is in your conversation, and the orchestrator is the session that lives longest. A compaction or a restart can lose the table, so keep a copy in a file.

- The file is `<main folder>/.sofa.state.json`. Git ignores it on this machine (the `sofa` skill adds it to `.git/info/exclude`), so it never goes into a commit.
- Write it after each status check, and after each change of an item or of a session.
- It holds the time of the last write, and:
  - Each session of the team: name, session ID, role, live or stopped, its open item, and the time it became free.
  - Each open item: its id, its state, its PR, its branch and worktree, and what it waits for.
  - Each open `ASK` and `BLOCKED`, with its priority or tag.
  - Each local commit or branch that waits for an approval.
  - The feature queue.
- Read it at start, and again after a compaction of your conversation. After a start or a compaction, where the file and the conversation differ, the file wins, because it is newer than a compaction summary.
