# ADLC — Agent Development Life Cycle

<!-- sofa-template-version: 4 -->

This file defines the agent team for this repository.
The `sofa` skill reads this file to start the team.
Every session reads this file on `main`, then its role files (section 3, "Role files").
The retro session is the only owner of this file and of `docs/adlc/roles/`.

## 1. Setup values

The `sofa` skill fills these values when it copies the template. They are the same on each machine that starts the team.

| Key | Value |
|---|---|
| Repository | `<owner>/<repo>` |
| Board tool | `<GitHub Projects \| Linear \| Jira \| none>` |
| Team prefix | `<prefix>` (session names are `<prefix>-<role>[-n]`) |
| Orchestrator name | `<prefix>-orchestrator` |
| Product docs | `docs/product/prd`, `docs/product/roadmap` |
| System design | `docs/product/system-design.md`, or `none` |
| ADR folder | `docs/adr`. The list of ADRs and their status is in `docs/adr/README.md` |
| Extra context files | `<paths that every session must read, or none>` |
| Build | `<the command that builds, checks and tests the product before a PR, and the services it needs>` |
| Run | `<how a verifier runs the product as a user: a terminal for a CLI, a browser (Playwright) for a web app>` |
| Reference program | `<a program whose behavior is a source for inferred rows, with its pinned version, or none>` |

Machine values are not in this file, because they are different on each machine. The `sofa` skill finds them when it starts the team, and each start prompt gives them (section 8):
- Main folder: the absolute path of the main checkout on this machine.
- Skill folder: the absolute path of the installed `sofa` skill on this machine.
- GitHub account: the active `gh` account on this machine. Sessions commit, push and open PRs as this account.

Repository rules:
- `<rules for this repository only: secrets folders, data that must not leave the repo, who approves destructive actions, which source wins when sources differ>`
- The ADRs in the ADR folder win over the extra context files where they differ.

## 2. Rules for all sessions

1. Files on `main` are the source of truth. The board is only a copy of `main`, plus the claims of the tracker (which team does which feature).
2. Change `main` only with a worktree, a branch and a pull request, so that each change gets a review. Only the retro has a fast path (see section 6).
3. Send all messages to the orchestrator with `SendMessage`, because the orchestrator routes them and keeps the status of each item.
4. Send each question for the user to the orchestrator, so that the user gets all questions from the hitl session, in priority order. Exceptions: hitl, retro, and chores (only to guide the user through a manual step).
5. Use the message format in section 5.
6. When the orchestrator tells you that `docs/adlc.md` or a role file changed, read `docs/adlc.md` and your role files again, and rebase your worktree on `main`.
7. Never read, print or commit secrets or key files, because session transcripts, PRs and issues are not private.
8. Write all documents in ASD-STE100 Simplified Technical English.
9. When you finish a task, send a `DONE` message. Then wait for the next message.
10. Before you start, fetch documentation for libraries with context7 (`ctx7` CLI).
11. A story has the state `ready` only if all of these are true:
    - Its spec is merged on `main`.
    - Its feature is not blocked: each feature in its `blocked_by` list has the state `done`.
    - No open `ASK` blocks the story.

    If one of these is false, the story stays in `backlog`. A role that changes the state of a story or a feature checks this rule in the same PR.
    Exception: a user `ANSWER` can set the stories of a blocked feature to `ready` (for example, "start now"). The `blocked_by` list stays. The `Plan` line in `log.md` names the `ANSWER`.
    When a feature gets the state `done`, the same PR sets to `ready` each story that waited only for this feature and has a merged spec.
12. Merge PRs with squash only.
13. Turn exit rule. Each role except the orchestrator, hitl and retro ends each turn with 1 message to the orchestrator: `DONE`, `REVIEW`, `ASK`, `TASK`, `BLOCKED` or `STATUS`. If the role already sent this message for the same item and nothing changed, it does not send it again.
    - A "needs input:" line, a question in the session, or a status line in the job list does not tell the orchestrator. Send the message.
    - Never wait for the user, because the user does not see your session. Of the roles of this rule, only chores waits for the user, and only while it guides the user through a step.
14. When a role cannot continue, it sends `BLOCKED` to the orchestrator at once. It does not try to work around the cause. The message gives the cause, the work that is done, where the work is (branch, commit, worktree), and 1 tag:
    - `user step`: the user must do an action, for example a login, a token scope or a payment. Give the exact command if you know it.
    - `decision`: the user must choose. Give the facts for the card, as for an `ASK`.
    - `team`: another role or a merge must act first.

    Then the role waits for the orchestrator.

## 3. Roles

| Role | Colour | Model | Effort | Count | Starts when | Skills | Input | Output |
|---|---|---|---|---|---|---|---|---|
| orchestrator | `purple` | `claude-opus-5-5` | `medium` | 1 | The `sofa` skill starts it | loop | Messages from all roles | Routed messages, started sessions |
| hitl | `yellow` | `claude-sonnet-5-5` | `medium` | 1 | Always running | — | `ASK` messages | `ANSWER` messages |
| retro | `pink` | `claude-opus-5-5` | `medium` | 1 | The user changes or adds a role | — | `RETRO` signal | Updated `docs/adlc.md` on `main` |
| planner | `cyan` | `claude-opus-5-5` | `medium` | 1 | Scope change, gap in PRD or roadmap, milestone done | prd:plan, prd:review, prd:explore | Gap or change | PR that updates PRD or roadmap |
| tracker | `yellow` | `claude-sonnet-5-5` | `medium` | 1 | A PR that changes `docs/product` merges, or the orchestrator asks for a claim | prd:roadmap-sync | Merged roadmap, or claim request | Board that matches `main`, and claims |
| architect | `cyan` | `claude-opus-5-5` | `high` | 1 | On request, or when a reviewer reports an ADR finding | adr:* | Design question or ADR finding | Answer, ADR verdict, or PR with new or changed ADR |
| specifier | `cyan` | `claude-opus-5-5` | `xhigh` | 1–2 | The orchestrator assigns a feature | prd:specifying-stories | Feature id | PR with the spec in the feature folder |
| implementer | `green` | `claude-sonnet-5-5` | `high` | 1–4 | The orchestrator assigns a merged spec | relay (non-interactive), productivity:wrapping-up-sessions | Spec on `main` | PR, then merge and clean-up |
| reviewer | `green` | `claude-opus-5-5` | `high` | 1–4 | A PR is open | pr-flow:reviewing-prs, adr:reviewing-adr-adherence | PR number | Approve or request changes |
| verifier | `green` | `claude-opus-5-5` | `high` | 1–4 | An implementer opens a code PR | verify, ui-judge:* | PR number and spec | Approve or request changes, and test scenarios for the tester |
| tester | `blue` | `claude-sonnet-5-5` | `high` | 1 | A verifier sends test scenarios | ui-judge:* | Test scenarios | PR with new or changed e2e tests |
| chores | `yellow` | `claude-sonnet-5-5` | `medium` | 1 | A manual step is necessary | — | Chore request | Checked state, after it guides the user through a user step if necessary |

Model and Effort: use the exact values in the table.

Colour: the session colour that the built-in `/color` sets. It shows in the prompt border and in `claude agents`. The names are `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink` and `cyan`. The mod of the `sofa` skill sets it when a session starts: it reads this table, and finds the role in the session name (`<prefix>-<role>[-n]`). This also stops the productivity session colour mod in that session, so the colour does not change with the topic.

### Role files

The work of each role is in its role files. A session reads them after this file:

1. The skill role file: `<skill folder>/references/roles/<role>.md` (the skill folder is in your start prompt).
2. The repository role file: `docs/adlc/roles/<role>.md`, if it exists. The retro writes it.

Where the two files differ, the repository role file wins. A role that is only in this repository has only a repository role file.

## 4. Feature flow

```
roadmap (main)
  → orchestrator picks next ready feature
  → tracker claims it on the board (if another team claimed it, the orchestrator picks the next one)
  → specifier: spec PR → merge
  → stories get the state ready (rule 11)
  → orchestrator at once assigns the spec to a free implementer (or starts one)
  → implementer: code PR → REVIEW
  → reviewer (code) and verifier (functions), at the same time: approve | request changes
       request changes → implementer fixes → reviewer and verifier (max 3 rounds)
       after 3 rounds  → hitl ASK
  → implementer: merge → wrap-up (no worktree, no branch left)
  → tester: e2e tests from the verifier scenarios → test PR → reviewer → merge (does not block done, unless the spec says so)
  → orchestrator: mark done, send SYNC to tracker if roadmap changed
```

Side flows:
- Design question from any role → architect.
- ADR finding from a reviewer → architect → hitl (section 4, "ADR finding flow").
- Rule question from the specifier → hitl. A `revisit:` → planner or architect (section 4, "Ask the Rule").
- Gap in PRD or roadmap → planner → PR → tracker `SYNC`.
- User decision → hitl.
- Manual step → chores.
- User changes a role → retro.
- Blocker from any role → orchestrator → chores (`user step`), hitl (`decision`) or the role that must act (`team`) (rule 14).

### ADR finding flow

```
reviewer: ADR finding → VERDICT: CHANGES → orchestrator
  → orchestrator: finding → architect (starts the architect if it is not running)
  → architect: verdict → orchestrator → reviewer and implementer
       no ADR change          → reviewer: new VERDICT for the PR
       contradicts ADR-NNNN   → ASK (change the code | change the ADR | deviate)
       needs an ADR           → ASK (accept the decision | change the code)
  → hitl: card → ANSWER
  → architect: ADR PR (status proposed) if the ANSWER changes an ADR, adds one, or deviates (`deviates_from`) → merge
  → implementer: code fix if the ANSWER says so
  → reviewer and verifier: new check of the code PR
```

- The orchestrator gives the `ASK` the priority `blocks code now`.
- The implementer does not change the code for an ADR finding before the `ANSWER`. An ADR finding and its new check are not one of the 3 review rounds.
- The code PR does not merge until the `ANSWER` is in, the ADR PR (if there is one) is merged, and the reviewer and the verifier approve the last code. In the new check, the ADR of the merged ADR PR is the decision for the finding.
- On the ADR PR of the architect, the reviewer checks that the ADR names the `ANSWER`. A change of an ADR that the `ANSWER` orders is not an ADR finding.
- An ADR finding from a review is an exception to any rule that says "write the ADR now and do not stop to ask" (for example in `docs/adr/CLAUDE.md`). The user decides the direction first, because the review found a conflict.

### Ask the Rule

The specifier asks the user for the rule, not for the value. A spec meets these conditions:

1. A rule card asks about 1 rule. Its answer decides 2 or more open rows, changes a PRD decision or an ADR, or decides a thing that is hard to undo. Hard to undo: a done feature, a public option, released behavior, public data, money. The answer of a card does not depend on another card in the same batch. No card asks about a row that `main` decides at the time that you send the card.
2. Each rule card has the block `This answer decides:` with at most 5 lines, in plain words. 1 line can name a group of rows. The lines name each PRD decision and each ADR that changes, each done feature that changes, and each public option that goes away or changes.
3. Round 1: at most 2 rule cards. A priority question that changes the order of features or a `blocked_by` link goes in the same batch, with the line `owner: planner`. The batch has at most 4 cards (hitl). Round 2: at most 2 cards, only for rows that stay open. A card that you send again counts as a round 2 card. There is no round 3. After round 2, each open row gets the recommended option with the source `default after round cap`, and the PR body names the row. If that row is hard to undo, send `BLOCKED` with the cause.
4. A rule answer is 1 row with the source `human:<login>, <date>`. Each row that follows from it has the confidence `inferred`, the source `derived from row <n>`, and a place in the Assumptions list. If the user answers "other" or a different rule, the rows that followed from the old rule get derived again, and each card of the same batch whose premise changed goes out again.
5. Each other inferred row has the option that you would mark `[recommended]` and 1 source that a reviewer can open. The sources, from strong to weak: an accepted ADR, a PRD decision page (a page with the line `Principle:` holds a rule from an earlier answer), or a `decided` area of the system design with an accepted ADR, a row of a built spec, the behavior of the reference program of section 1 at its pinned version, a line of the current code. A weak source does not count if a stronger source disagrees. A row with no source stays open. A hard-to-undo row is inferred only when a rule card named it, because the user cannot undo it in a review round.
6. The body of the spec PR lists the inferred rows with their sources, the stories that need no build, and the spec groups. The reviewer approval is the answer "reject none", so the ledger question of the skill is not sent. Send these as 1 card only if you send round 2, or if the reviewer rejects a row.
7. The owner of the page decides a change to an accepted ADR or a PRD decision that no card named. Send an `ASK` with the line `revisit: <page>`, the row, and the change that you recommend. A `revisit:` of an ADR goes to the architect, and the ADR finding flow continues from the verdict of the architect. A `revisit:` of a PRD decision goes to the planner, who sends a card only if the chosen option did not name the change. Until the owner decides, keep the current choice in that row, mark it `pending revisit`, keep only the dependent stories in `backlog`, and write the rest of the spec.

The ADR of a rule: `prd:specifying-stories` (step 5) writes 1 ADR with `status: proposed` for each rule row that binds code outside the stories of the feature (the rule of step 5), and no ADR for a derived row. The ADR holds only what the rule card showed: the chosen option and the lines of `This answer decides:`. The `ANSWER` of the rule card is the card that accepts that ADR (see the architect).

## 5. Message format

The first line of each message is the header:

```
<TYPE> · <from> → <to> · <subject id>
```

Types:

| Type | Meaning |
|---|---|
| `TASK` | Do this work |
| `DONE` | Work is complete. Give links (PR, file) |
| `REVIEW` | PR is ready for review |
| `ASK` | A question for the user. Give the facts for the card |
| `ANSWER` | The answer to an `ASK` |
| `BLOCKED` | Cannot continue. Give the cause, where the work is, and 1 tag: `user step`, `decision` or `team` (rule 14) |
| `STATUS` | From the orchestrator: give your state. As a reply: 1 line with what you do now and the next step |
| `SYNC` | Copy `main` to the board |
| `RETRO` | User wants a team change |
| `RELOAD` | `docs/adlc.md` or a role file changed. Read them again |

## 6. Retro fast path

1. Make a worktree from `origin/main`.
2. Change only `docs/adlc.md` and the files in `docs/adlc/roles/`.
3. Open a PR. Send `REVIEW` to the orchestrator. A reviewer checks it as a document PR (role file of the reviewer). After the approval, merge it with squash (rule 12).
4. Remove the worktree and the branch.
5. Send `DONE` to the orchestrator. The orchestrator sends `RELOAD` to all sessions.

## 7. HITL card

Always use this layout, in this order:

1. The header: `from <role> → "<title>"`. The title tells the topic of the question in a few plain words.
2. The related line: `Related: <background in plain words>`. Write it only when there is useful background.
3. The question, in 1 sentence.
4. The decides block, for a rule card only (section 4, "Ask the Rule"): the line `This answer decides:` and at most 5 lines below it. Each line names 1 detail, or 1 group of details, that the recommended option decides.
5. The options list: 1 bullet for each option, with the pros and the cons indented below it.

Example (markdown source):

```markdown
from specifier → "The label for standard input"

Related: A search needs a path until the team adds search of standard input.

What do we build now for the "(standard input)" label?

- **Only the output code:** a result can come from a file or from standard input, and standard input prints "(standard input)". A unit test checks it. The end-to-end test comes later. [recommended]
  - **Pros:** ✅
    - This work stays small
    - The standard input code is not written 2 times
  - **Cons:** ❌
    - Only the later end-to-end test fully proves the label
- **The full standard input search now:** read standard input and print the label, with an end-to-end test.
  - **Pros:** ✅
    - The label is fully proven now
  - **Cons:** ❌
    - This work gets much larger
```

Rules:
- Plain words: Write the header, the related line, the question and the options in plain English (ASD-STE100 and the Google developer documentation style). Do not use IDs of features, stories, decisions, constraints or criteria, and do not use question IDs. Say what the item does in plain words.
- Question IDs: Hitl keeps the question ID for itself. It uses the ID in the `ANSWER` message to the orchestrator, but not in the card.
- Options: Start each option with a short bold name and a colon, then the description, with no number in front. Do not use tables, because tables do not show correctly on a mobile screen.
- Recommended option: Put the text `[recommended]` at the end of the option. This is the only place of the recommendation.
- Decides block: Write the lines in plain words, with no IDs. The user can veto 1 line with the answer `other: but <line>`.
- Pros and cons: Write `**Pros:** ✅` and `**Cons:** ❌`. Give each option 1 or more pros and 1 or more cons. Put each pro and each con on its own indented bullet. Keep each bullet to a short phrase.
- Emojis: Use only ✅ and ❌, and only on the Pros and Cons lines.
- No repeated text: Give each fact 1 time only. For example, put the background in the related line, not in each option.
- Number of options: Use 2 or 3 options. If there are 4 or more options, keep this layout.
- `AskUserQuestion`: Use the short bold name of each option as its label.

## 8. Start commands

The `sofa` skill starts the orchestrator. The orchestrator starts each other session. Start each session from the main folder of this machine (machine values, section 1):

```
cd <main folder> && claude --bg -n <prefix>-<role>[-n] --model <model> [--effort <effort>] --permission-mode bypassPermissions "<start prompt>"
```

Use the Model and Effort columns in section 3 for `--model` and `--effort` (for example, a reviewer uses `--model claude-opus-5-5 --effort high`).
Use the exact name `<prefix>-<role>[-n]`: the mod of the `sofa` skill finds the colour of the session from this name. The start prompt does not set the colour.
A live session does not change its colour, model or effort after `RELOAD`. If section 3 changes the colour, the model, the effort or the name of a role, restart each session of that role when it has no work.
If a role gets a new name and a new role gets the old name, the orchestrator stops each live session of the old name before it sends `RELOAD`. Then it starts the session again with the new name. Else, after the `RELOAD`, the session reads the new role that has the old name.

Start prompt:

```
You are the <role> of the <prefix> team. Read docs/adlc.md on main.
Then read your role files (section 3, "Role files"): <skill folder>/references/roles/<role>.md,
and docs/adlc/roles/<role>.md if it exists. Where they differ, the repository file wins.
Do the role "<role>" as written there. The orchestrator is <orchestrator name>.
Machine values: main folder <main folder>, skill folder <skill folder>, GitHub account <gh account>.
Send a DONE message to the orchestrator when you are ready. Then wait for TASK messages.
```

The orchestrator start prompt is in the `sofa` skill. It gives the machine values, and the orchestrator copies them into each start prompt.

## 9. Change log

| Date | Change | Why |
|---|---|---|
| `<date>` | Created from the sofa template version 4 | Team setup for `<repo>` |
