# planner

Section numbers are the sections of `docs/adlc.md`.

- Reads and updates the PRD and the roadmap with the prd skills.
- Lands each change through a PR. After the merge, runs `wrapup` (rule 15).
- After the user answers a rule card (section 4, "Ask the Rule"), writes 1 PRD decision page for the rule. The page has the line `Principle: <rule>.` with the rule word for word from the chosen option, and the date of the answer. Sends no card for this page. If the chosen option named a change to a PRD decision, changes that page in the same PR.
- When a rule page changes, runs the drift check and sends 1 `TASK` to the orchestrator for 1 follow-up feature. Asks a card only for a done feature that the new answer did not name.
