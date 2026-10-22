---
name: sofa
description: 'Start a software factory: a team of Claude Code background sessions (orchestrator, hitl, retro, planner, projecter, architect, specifier, implementers, reviewers, verifiers, tester, chores) that build a product from the PRD and roadmap in a repo. Use when the user says "sofa", "start the team", "spawn the team" or "software factory".'
disable-model-invocation: true
---

# sofa — software factory

This skill is only the entry point. The team is defined in `ADLC.md`.
This session becomes the orchestrator.

## Files

- `templates/ADLC.md` — the template team definition (version 2). Do not change it here for one repository.
- `templates/ADLC.v1.md` — the old version 1. Only for reference.
- `<repo>/docs/adlc.md` — the team definition for one repository. This copy is the source of truth after setup. The retro session changes it.

The user copies good changes from `docs/adlc.md` back to the template. Do not do this yourself.

## Requirements

Check these before step 2. If one is missing, tell the user the exact install step and stop.

- Claude Code with `claude --bg`, `SendMessage`, `ListAgents` and `/loop`.
- `gh` CLI, logged in to an account with write access to the repository.
- Node, so that `npx ctx7@latest` runs (context7).
- Plugins: `prd`, `adr`, `relay`, `pr-flow`, `productivity`, `ui-judge` (marketplace `claude-code-dev-plugins`), and `superpowers` (marketplace `claude-plugins-official`).
- Skill: `verify` (used by the verifier role). It comes with Claude Code as `/verify`.

## Step 1 — Check the repository

1. Find the main folder: `git rev-parse --show-toplevel` in the main checkout (not in a worktree).
2. Find your session name with `ListAgents`. The first line shows it.
3. Run `gh auth status`. Record the account and the token scopes.
4. Find the PRD, the roadmap, the system design and the ADR folder. If no PRD or roadmap exists, stop and tell the user to make them first (prd plugin). If the ADR folder has no `README.md` index, record it: the architect makes the index first.
5. Find the build, check and test command (for example in `package.json`, `Makefile`, `CLAUDE.md`), and how a user runs the product.
6. Read the `CLAUDE.md` of the repository. If it names a different process or harness for product work, tell the user and ask which one wins before step 2.
7. If `docs/adlc.md` exists, go to step 3. Do not ask the setup questions again.

## Step 2 — Setup (first run only)

1. Ask the user these questions with `AskUserQuestion`. Do not ask a question that the user already answered in the request.
   - Board tool (GitHub Projects, Linear, Jira, none).
   - GitHub account.
   - Team prefix for session names.
   - Changes to the roles, models, efforts or counts in the template.
   - Extra context files that every session must read.
   - Repository rules (secrets, private data, who approves destructive actions).
   - Commit identity check (rule 12), or none.
2. Copy `templates/ADLC.md` to `docs/adlc.md`. Fill every row of section 1 and the repository rules with the answers and the facts of step 1. No `<...>` placeholder must stay. Apply the changes. Fill the first line of section 9.
3. Land `docs/adlc.md` on `main` with a worktree, a PR and a squash merge.

## Step 3 — Start the team

1. Read `docs/adlc.md` from `main`.
2. Check the board tool access. If a user step is necessary (for example a token scope), start chores first.
3. For each role in section 3 (not orchestrator), start 1 session with the 2 steps in section 8. Use the colour, the model and the effort from the roles table. If the roles table has no Colour column (a `docs/adlc.md` from before the colours), use the colour of the role in `templates/ADLC.md`. Use the absolute main folder.
4. Wait for a `DONE` message from each session. Use `ListAgents` to see which sessions are live.
5. Start the status check: `/loop 10m` (orchestrator details in section 3).
6. Tell the user how to open hitl and retro: `claude agents`, then `claude attach <id>`.
7. You cannot run `/color` in this session. Tell the user to type `/color <orchestrator colour>` here (`/color purple` in the template), so that the orchestrator has its role colour.

## Step 4 — Run the team

Do the orchestrator role as written in section 3 of `docs/adlc.md`, with the feature flow in section 4.

Messages arrive by themselves. Do not poll `ListAgents` in a loop.
