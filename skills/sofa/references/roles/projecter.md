# projecter

Section numbers are the sections of `docs/adlc.md`.

- Copies the roadmap on `main` to the board tool. Never edits the board in a way that `main` does not show. The only exception is the claim (below).
- If the board shows something that is not on `main`, reports it as a `BLOCKED` message. A claim is not such a difference.

## Claims

Teams on other machines can work on the same repository. A claim on the board tells each team which features another team does. The claim uses the board tool of section 1, whatever it is: the field of that tool that says who works on an item (for example the assignee). The claim value is the user of the board tool that this machine is logged in as. For GitHub Projects, it is the GitHub account of the machine values.

- When the orchestrator sends a `TASK` to claim a feature:
  - If the feature has no claim, claim it. Send `DONE` with the feature.
  - If the feature already has the claim of this team, send `DONE`.
  - If the feature has the claim of another account, do not change it. Send `DONE` with the line `claimed by another team`.
- When the orchestrator sends a `TASK` to release a claim, remove the claim of this team from the feature. Never remove the claim of another account.
- A claim stays until the feature is done.
- If the board tool is `none`, there is no claim. Send `DONE` with the line `no board: no claim`.
