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
| [wrapup](skills/wrapup/SKILL.md) | After the work of a session is on the default branch, deletes the local branch, removes the worktree, and moves the session back to the main checkout. |

## Install

Link each skill into `~/.claude/skills`. A link to this checkout gets each change after you pull.

```
$ for s in bg-watch dispatch handoff osaat rebase wrapup; do ln -s "$PWD/skills/$s" ~/.claude/skills/$s; done
```

Run the command from the root of this repository, on `main`.

## Plugins moved

This repository has no plugin marketplace. Its plugins moved:

- `sofa` is in the [cc-plugins-library](https://github.com/ai-advanced-futures/cc-plugins-library) marketplace. The skills of this repository are also in its `skills/` folder.
- `leads` is in the [claude-code-dev-plugins](https://github.com/ai-advanced-futures/claude-code-dev-plugins) marketplace.

If you installed them from this repository, or sofa as a skill, remove the old copies, then install them from the new marketplaces:

```
$ claude plugin uninstall sofa@ai-ready-future-skills
$ claude plugin uninstall leads@ai-ready-future-skills
$ claude plugin marketplace remove ai-ready-future-skills
$ npx skills remove sofa
$ rm -f ~/.claude/skills/sofa
$ claude plugin marketplace add ai-advanced-futures/cc-plugins-library
$ claude plugin install sofa@cc-plugins-library
$ claude plugin marketplace add ai-advanced-futures/claude-code-dev-plugins
$ claude plugin install leads@claude-code-dev-plugins
```

The `sofa` plugin uses the `bg-watch`, `rebase` and `wrapup` skills. Install them from this repository with the command above, or from cc-plugins-library:

```
$ npx skills add ai-advanced-futures/cc-plugins-library --skill bg-watch --skill rebase --skill wrapup
```

## Tests

```
$ bash skills/bg-watch/tests/bg-watch.test.sh
$ bash skills/wrapup/tests/branch-landed.test.sh
$ bash skills/wrapup/tests/self-teardown.test.sh
```
