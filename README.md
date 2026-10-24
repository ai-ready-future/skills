# Skills

Skills for Claude Code.

| Skill | Description |
| --- | --- |
| [dispatch](skills/dispatch/SKILL.md) | Forks the current session into a new background session that starts work on one item at once. |
| [doc-style](skills/doc-style/SKILL.md) | Writing style for docs, README files, PRs, commits, comments, and chat replies. Paraphrased from the Google developer documentation style guide, with reference files that load on demand and an optional Vale check. |
| [handoff](skills/handoff/SKILL.md) | Writes a handoff document in the reply, so that a new agent can continue the work of this conversation. |
| [sofa](skills/sofa/SKILL.md) | Software factory. Starts a team of Claude Code background sessions that build a product from the PRD and the roadmap of a repository. |
| [wrapup](skills/wrapup/SKILL.md) | After the work of a session is on the default branch, deletes the local branch, removes the worktree, and moves the session back to the main checkout. |

`dispatch`, `handoff` and `wrapup` come from the `productivity` plugin (version 0.15.0), where they have the names `dispatch-background-sessions`, `handoff` and `wrapping-up-sessions`. If you also have the plugin turned on, each skill shows two times.

## Install

Link each skill into `~/.claude/skills`. A link to this checkout gets each change after you pull.

```
$ for s in dispatch handoff wrapup; do ln -s "$PWD/skills/$s" ~/.claude/skills/$s; done
```

Run the command from the root of this repository, on `main`.

## Tests

```
$ bash skills/wrapup/tests/branch-landed.test.sh
$ bash skills/wrapup/tests/self-teardown.test.sh
```
