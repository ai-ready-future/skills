---
name: sofa
description: 'Start a software factory: a team of Claude Code background sessions (orchestrator, hitl, retro, planner, projecter, architect, specifier, implementers, reviewers, verifiers, tester, chores) that build a product from the PRD and roadmap in a repo. Use when the user says "sofa", "start the team", "spawn the team" or "software factory".'
disable-model-invocation: true
---

# sofa — software factory

This skill is only the entry point. The team is defined in `ADLC.md` and in the role files.
This session is the launcher. It does the checks and the setup, and starts the orchestrator as a background session. The orchestrator starts all the other roles. This session does not become the orchestrator.

## Files

- `templates/ADLC.md` — the template team definition (version 3): setup values, rules, roles table, flow, messages and start commands. Do not change it here for one repository.
- `references/roles/<role>.md` — the work of each role. Sessions read these files from the installed skill. Do not copy them to the repository.
- `hooks/register.tsx` — the mod. When a session starts with the name `<prefix>-<role>[-n]` in a folder with `docs/adlc.md`, it sets the session colour of that role from the roles table. `tests/` has its tests.
- `templates/ADLC.v1.md` — the old version 1. Only for reference.
- `<repo>/docs/adlc.md` — the team definition for one repository. This copy is the source of truth after setup. The retro session changes it.
- `<repo>/docs/adlc/roles/<role>.md` — changes to 1 role for one repository. Where it differs from the skill role file, it wins. The retro session writes it.

The retro session offers to open an issue in `ai-ready-future/skills` for a change that all repositories need. Do not change the skill files yourself.

## Requirements

Check these before step 2. If one is missing, tell the user the exact install step and stop.

- Claude Code with `claude --bg`, `SendMessage`, `ListAgents` and `/loop`.
- `gh` CLI, logged in to an account with write access to the repository.
- Node, so that `npx ctx7@latest` runs (context7).
- Plugins: `prd`, `adr`, `relay`, `pr-flow`, `productivity`, `ui-judge` (marketplace `claude-code-dev-plugins`), and `superpowers` (marketplace `claude-plugins-official`).
- Skill: `verify` (used by the verifier role). It comes with Claude Code as `/verify`.

The session colours need the mod. Claude Code loads it by itself when this skill folder is in `~/.claude/skills/sofa` or in the `.claude/skills/sofa` folder of the project. Some Claude Code versions (for example 2.1.257) do not load mods. Then the team works, but with no role colours. Do not stop for this. Tell the user.

## Step 1 — Check the repository

1. Find the main folder: `git rev-parse --show-toplevel` in the main checkout (not in a worktree).
2. Find your session name (the launcher name) with `ListAgents`. The first line shows it.
3. Find the skill folder: the absolute path of the folder of this file.
4. Run `gh auth status`. Record the account and the token scopes.
5. Find the PRD, the roadmap, the system design and the ADR folder. If no PRD or roadmap exists, stop and tell the user to make them first (prd plugin). If the ADR folder has no `README.md` index, record it: the architect makes the index first.
6. Find the build, check and test command (for example in `package.json`, `Makefile`, `CLAUDE.md`), and how a user runs the product.
7. Read the `CLAUDE.md` of the repository. If it names a different process or harness for product work, tell the user and ask which one wins before step 2.
8. If `docs/adlc.md` does not exist, go to step 2.
9. If `docs/adlc.md` exists, read its version (`sofa-template-version`). If the version is lower than 3, or if a section 1 value does not agree with this list, go to step 2b:
   - The orchestrator name is `<prefix>-orchestrator`.
   - The skill folder is the folder of step 1.3.

   Else go to step 3. Do not ask the setup questions again.

## Step 2 — Setup (first run only)

1. Ask the user these questions with `AskUserQuestion`. Do not ask a question that the user already answered in the request.
   - Board tool (GitHub Projects, Linear, Jira, none).
   - GitHub account.
   - Team prefix for session names.
   - Changes to the roles, models, efforts, colours or counts in the template.
   - Extra context files that every session must read.
   - Repository rules (secrets, private data, who approves destructive actions).
   - Commit identity check (rule 12), or none.
2. Copy `templates/ADLC.md` to `docs/adlc.md`. Fill every row of section 1 and the repository rules with the answers and the facts of step 1. The orchestrator name is `<prefix>-orchestrator`, not the launcher name. No `<...>` placeholder must stay. Apply the changes to the roles table. Write a change to the work of a role in `docs/adlc/roles/<role>.md` (see the retro role file, "Where a change goes"). Fill the first line of section 9.
3. Land `docs/adlc.md` and `docs/adlc/roles/` on `main` with a worktree, a PR and a squash merge.

## Step 2b — Upgrade an older `docs/adlc.md`

1. Tell the user which values or which version is old, and what the upgrade changes. Continue only after the user agrees.
2. Make a new `docs/adlc.md` from `templates/ADLC.md`. Keep the section 1 values, the repository rules, the values of the roles table and the rows of section 9 of the old file. Set the orchestrator name and the skill folder as in step 1.9. If the old roles table has no Colour column, use the colours of the template.
3. For each role, compare the role details of the old file with the skill role file. Write each difference in `docs/adlc/roles/<role>.md`. Keep the changes to the shared sections (rules, flow, messages, card) in the new `docs/adlc.md`.
4. Add a line to section 9: the upgrade to version 3.
5. Land the files on `main` with a worktree, a PR and a squash merge.
6. If live sessions of the old team exist (`ListAgents`), stop them before step 3.

## Step 3 — Start the orchestrator

1. Pull `main` in the main folder, so that `docs/adlc.md` on disk is the one on `main` (the mod reads it there). Then read it.
2. If `ListAgents` shows a live session with the orchestrator name, do not start a second one. Tell the user that the team runs, and how to open it (step 3.5). Stop.
3. Start the orchestrator with the command in section 8. Use the orchestrator name, and the model and the effort of the orchestrator row. Use the absolute main folder. Use this start prompt:

   ```
   You are the orchestrator of the <prefix> team. Read docs/adlc.md on main.
   Then read your role files (section 3, "Role files"): <skill folder>/references/roles/orchestrator.md,
   and docs/adlc/roles/orchestrator.md if it exists. Where they differ, the repository file wins.
   Do the role "orchestrator" as written there. Start with "At start".
   The launcher is <launcher name>. Send it a DONE message when all sessions of the team are ready.
   ```

4. Wait for the `DONE` message from the orchestrator.
5. Tell the user how to open the orchestrator, hitl and retro: `claude agents`, then `claude attach <name>`. Then this session has no more work.
