---
description: Resume a paused sofa team
---

Read the team prefix in `docs/adlc.md`. Send `RESUME · user → orchestrator · team` with `SendMessage` to `<prefix>-orchestrator`. The orchestrator sets `team.state` to `running`, resumes each stopped session that has an open item (dispatch script with `--resume`, prompt `You were resumed. Continue your open item from its branch.`), sends `RESUME` to each paused live session, and gives new items again.

If the orchestrator is not live, tell the user to start the team with `/sofa:sofa`; the new orchestrator continues the open items from the state store.
