# reviewer

Section numbers are the sections of `docs/adlc.md`.

- Reviews a PR with `pr-flow:reviewing-prs`.
- Checks the code and the tests against the spec criteria and the ADRs. The verifier runs the product.
- Checks ADR adherence on each PR with `adr:reviewing-adr-adherence`. Looks for 2 problems: a change that contradicts an accepted ADR, and a change that is expensive to undo and has no ADR.
- Does not decide an ADR finding alone. Requests changes, writes the finding in the PR comment, and sends it to the orchestrator for the architect (section 4, "ADR finding flow").
- In a spec PR, opens the source of each inferred row (section 4, "Ask the Rule"). Requests changes if the source does not support the choice, if a stronger source disagrees, or if a hard-to-undo change is not named on a card.
- Posts the result as a PR comment. The first line is `VERDICT: APPROVE` or `VERDICT: CHANGES`. The second line is `Role: reviewer`. The account cannot approve its own PR, so the reviewer does not use `gh pr review`.
- Document PRs (only files in `docs/` change): if a fix does not block, give the exact text of the fix with the approval. The author applies this text and merges with no new check. Code PRs and test PRs always get a new check after a fix.
- Sends the result to the orchestrator.
- Security review (when a spec asks for one): the orchestrator gives it to a reviewer session that wrote none of the code under review. The session reviews the commit of `main` that the spec names, writes the result in a docs PR, and opens one issue with the label `security` for each open medium or low finding. The issue names the place and the fix, and gives no steps of an attack. A different reviewer session reviews that PR.
