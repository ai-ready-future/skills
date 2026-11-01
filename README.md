# Skills

Skills for Claude Code.

| Skill | Description |
| --- | --- |
| [bg-watch](skills/bg-watch/SKILL.md) | Watches the background sessions on a schedule. Restarts each session that stopped on an API error, sends it `retry`, and logs each jag decision. |
| [dispatch](skills/dispatch/SKILL.md) | Forks the current session into a new background session that starts work on one item at once. |
| [doc-style](skills/doc-style/SKILL.md) | Writing style for docs, README files, PRs, commits, comments, and chat replies. Paraphrased from the Google developer documentation style guide, with reference files that load on demand and an optional Vale check. |
| [handoff](skills/handoff/SKILL.md) | Writes a handoff document in the reply, so that a new agent can continue the work of this conversation. |
| [osaat](skills/osaat/SKILL.md) | One step at a time. Does a series of steps one by one, and asks the user to approve each step first. |
| [rebase](skills/rebase/SKILL.md) | Rebases the current branch onto the latest default branch or onto a branch you name, or continues a rebase in progress. Helps with each conflict. Only you can start it, with `/rebase`. |
| [sofa](skills/sofa/skills/sofa/SKILL.md) | Software factory, as a plugin. Starts a team of 29 Claude Code roles that build a product from the PRD and the roadmap of a repository. Includes `sofa:station`, `sofa:readiness`, `sofa:setup`, `sofa:maturity`, the `/sofa:*` commands, and a dashboard pane. |
| [wrapup](skills/wrapup/SKILL.md) | After the work of a session is on the default branch, deletes the local branch, removes the worktree, and moves the session back to the main checkout. |

## Install

Link each skill into `~/.claude/skills`. A link to this checkout gets each change after you pull.

```
$ for s in bg-watch dispatch handoff osaat rebase wrapup; do ln -s "$PWD/skills/$s" ~/.claude/skills/$s; done
```

Run the command from the root of this repository, on `main`.

`sofa` is a plugin, not a single skill. Install it from this repository as a marketplace:

```
$ claude plugin marketplace add ai-ready-future/skills
$ claude plugin install sofa@ai-ready-future-skills
```

If you installed sofa version 5 or older as a skill, remove that copy first. Version 6 has no skill at `skills/sofa/SKILL.md`, and its sub-skills work only inside the plugin:

```
$ npx skills remove sofa
$ rm -f ~/.claude/skills/sofa
```

For development, add your checkout as a folder marketplace (`claude plugin marketplace add "$PWD"`). Claude Code then reads the plugin from the folder, and `/reload-plugins` picks up each change.

## Tests

```
$ bash skills/bg-watch/tests/bg-watch.test.sh
$ bash skills/wrapup/tests/branch-landed.test.sh
$ bash skills/wrapup/tests/self-teardown.test.sh
$ bash skills/sofa/tests/template.test.sh
$ bash skills/sofa/tests/dispatch.test.sh
$ bash skills/sofa/tests/sofa-state.test.sh
$ bash skills/sofa/tests/readiness.test.sh
$ claude plugin test skills/sofa
```
