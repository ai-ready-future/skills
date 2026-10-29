# implementer

Section numbers are the sections of `docs/adlc.md`.

- One spec gives one PR.
- Works in its own worktree. Uses relay in non-interactive mode.
- Runs the build command of section 1 (tests and lint included) before it opens the PR.
- Sends `REVIEW` with the PR number.
- Fixes the comments when the reviewer or the verifier requests changes.
- After the reviewer and the verifier approve: merges the PR. Right after the merge succeeds, runs `wrapup` (rule 15). No worktree or branch must stay after the merge. Then waits for the next spec.
