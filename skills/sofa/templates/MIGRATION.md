# Migration of docs/adlc.md

The `sofa` skill reads this file when `docs/adlc.md` has a lower `sofa-template-version` than `templates/ADLC.md`. Apply each step from the version of the file to the current version, in order. Keep each value and each repository rule of the file. Ask the user only for the values that a step marks `ask`.

## 5 → 6

1. Section 1:
   - Add the rows `Risk appetite` (ask), `Domain model` (`docs/domain` if the `ddd` brain exists, else `none`), `Proofs folder` (`docs/proofs`), `Environments` (ask), `Healthy window` (`24h`), `Slack` (`none`; `/sofa:setup` adds it later).
   - Add the table "Tools per role". Take `tracker` from the old `Board tool` value (GitHub Projects → `gh`). Ask the others, or set `built-in` and `none`.
   - `System design`: keep the value.
2. Section 2: replace the 15 rules with the new short section. The old rules 1–10 and 12–15 are now in the `sofa:station` skill. The old rule 11 (story `ready`) is the new rule 1. Add the new rules 2 (states, `released`) and 3 (who writes which file). Keep each repository-specific rule that the retro added: move it to section 1, "Repository rules".
3. Section 3: replace the roles table with the template table. For each row of the old table whose model, effort, colour or count differs from the v5 template, keep the old value (it is a choice of this repository). Add the columns `Tier` and `Output style`. Add the rows `requests`, `decision-judge`, `scribe`, `plan-auditor`, `merger`, `monitoring`, `scheduler`, `designer`, `business-domain`, `security`, `code-quality`, `troubleshooter`, `operator`, `feedback`, `ux-quality`, `updater`. Add the table "Who writes which file".
4. Skill names in the table and in `docs/adlc/roles/*.md`: `prd:` → `product:`, `adr:` → `architecture:`, `adr:scaffolding-adr-corpora` → `architecture:setup`, `pr-flow:reviewing-prs` → `code-review:reviewing-prs`, `ui-judge:*` → `playwright`.
5. The architect no longer owns the system design: if `docs/adlc/roles/architect.md` has lines about the system design, move them to `docs/adlc/roles/designer.md`.
6. Section 4: replace with the template section 4 (flows, release flow, decision flow, decision tables). Keep any repository change of the old "Ask the Rule" text.
7. Section 5: add the types `PAUSE` and `RESUME`.
8. Section 8: replace with the template section 8 (dispatch script, new start prompt).
9. Section 9: add the row `Migrated to sofa template version 6`.
10. Set `<!-- sofa-template-version: 6 -->`.
11. Machine: `.sofa.state.json` → the state store. If `.sofa.state.json` exists in the main folder, run `sofa-state init`, copy its sessions and items with `sofa-state session upsert` and `sofa-state item set`, then delete the JSON file. Replace the `.sofa.state.json` line of `.git/info/exclude` with `.sofa/`.
12. Machine: run `/sofa:setup` for the new items (scheduler cron line, tools per role, human team).
