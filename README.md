# Skills

Skills for Claude Code.

| Skill | Description |
| --- | --- |
| [dispatch](skills/dispatch/SKILL.md) | Forks the current session into a new background session that starts work on one item at once. |
| [doc-style](skills/doc-style/SKILL.md) | Writing style for docs, README files, PRs, commits, comments, and chat replies. Paraphrased from the Google developer documentation style guide, with reference files that load on demand and an optional Vale check. |
| [handoff](skills/handoff/SKILL.md) | Writes a handoff document in the reply, so that a new agent can continue the work of this conversation. |
| [osaat](skills/osaat/SKILL.md) | One step at a time. Does a series of steps one by one, and asks the user to approve each step first. |
| [rebase](skills/rebase/SKILL.md) | Rebases the current branch onto the latest default branch or onto a branch you name, or continues a rebase in progress. Helps with each conflict. Only you can start it, with `/rebase`. |
| [sofa](skills/sofa/SKILL.md) | Software factory. Starts a team of Claude Code background sessions that build a product from the PRD and the roadmap of a repository. |
| [wrapup](skills/wrapup/SKILL.md) | After the work of a session is on the default branch, deletes the local branch, removes the worktree, and moves the session back to the main checkout. |

Some skills come from plugins of [claude-code-dev-plugins](https://github.com/ai-advanced-futures/claude-code-dev-plugins). If you also have the plugin turned on, the skill shows two times.

| Skill | Plugin | Name in the plugin |
| --- | --- | --- |
| `dispatch` | `productivity` 0.15.0 | `dispatch-background-sessions` |
| `handoff` | `productivity` 0.15.0 | `handoff` |
| `wrapup` | `productivity` 0.15.0 | `wrapping-up-sessions` |
| `osaat` | `osaat` 1.1.1 | `going-one-step-at-a-time` |
| `rebase` | `git` 4.0.2 | `rebase` |

## Install

Link each skill into `~/.claude/skills`. A link to this checkout gets each change after you pull.

```
$ for s in dispatch handoff osaat rebase wrapup; do ln -s "$PWD/skills/$s" ~/.claude/skills/$s; done
```

Run the command from the root of this repository, on `main`.

## Tests

```
$ bash skills/wrapup/tests/branch-landed.test.sh
$ bash skills/wrapup/tests/self-teardown.test.sh
```
