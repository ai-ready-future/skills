---
name: sofa
description: 'Start a software factory: a team of Claude Code background sessions (orchestrator, hitl, retro, planner, tracker, architect, specifier, implementers, reviewers, verifiers, tester, chores) that build a product from the PRD and roadmap in a repo. Use when the user says "sofa", "start the team", "spawn the team" or "software factory".'
disable-model-invocation: true
---

# sofa — software factory

This session is the launcher. It checks the repository, makes sure that `docs/adlc.md` meets the current template, and starts the orchestrator as a background session. The orchestrator starts all the other roles. The orchestrator is a separate session because it runs with the model and the effort of its row in the roles table.

## Files

- `templates/ADLC.md` — the current team definition: setup values, rules, roles table, flow, messages and start commands. Each repository has its own copy in `docs/adlc.md`.
- `references/roles/<role>.md` — the work of each role. Sessions read these files from the installed skill, so a fix here reaches each repository.
- `hooks/register.tsx` — the mod. When a session starts with the name `<prefix>-<role>[-n]` in a folder with `docs/adlc.md`, it sets the session colour of that role from the roles table. `tests/` has its tests.
- `<repo>/docs/adlc.md` — the team definition for one repository, and the source of truth after setup. The retro session changes it.
- `<repo>/docs/adlc/roles/<role>.md` — changes to 1 role for one repository. Where it differs from the skill role file, it wins. The retro session writes it.

A change that all repositories need goes to `ai-ready-future/skills` as an issue, which the retro offers. Leave the installed skill files as they are, because the next install replaces them.

## Requirements

Check these before step 2. If one is missing, tell the user the exact install step and stop.

- Claude Code with `claude --bg`, `SendMessage`, `ListAgents` and `/loop`.
- `gh` CLI, logged in to an account with write access to the repository.
- Node, so that `npx ctx7@latest` runs (context7).
- Plugins: `prd`, `adr`, `relay`, `pr-flow`, `productivity`, `ui-judge` (marketplace `claude-code-dev-plugins`), and `superpowers` (marketplace `claude-plugins-official`).
- Skill: `verify` (used by the verifier role). It comes with Claude Code as `/verify`.

The session colours need the mod. Claude Code loads it by itself when this skill folder is in `~/.claude/skills/sofa` or in the `.claude/skills/sofa` folder of the project. Some Claude Code builds (for example 2.1.257) do not load mods. Then tell the user that the team has no role colours, and continue, because the colours do not change the work.

## Step 1 — Check the repository

Find the machine values of this start. Each machine has different values, so they go only in the start prompts, never in `docs/adlc.md`:

- Main folder: `git rev-parse --show-toplevel` in the main checkout, not in a worktree.
- Skill folder: the absolute path of the folder of this file.
- GitHub account: the active account of `gh auth status`. Also record the token scopes.
- Launcher name: your session name, on the first line of `ListAgents`.

Then find the PRD, the roadmap, the system design and the ADR folder, the build, check and test command (for example in `package.json`, `Makefile`, `CLAUDE.md`), and how a user runs the product. If no PRD or roadmap exists, stop and tell the user to make them first with the prd plugin, because the team builds from them. If the ADR folder has no `README.md` index, record it: the architect makes the index first.

If the `CLAUDE.md` of the repository names a different process or harness for product work, ask the user which one wins before step 2.

## Step 2 — Make `docs/adlc.md` meet the current template

The result: `docs/adlc.md` and `docs/adlc/roles/` on `main` meet the current `templates/ADLC.md` and role files, and hold the values and the choices of this repository.

If `docs/adlc.md` does not exist, ask the user these questions with `AskUserQuestion`. Skip a question that the request already answers.

- Board tool (GitHub Projects, Linear, Jira, none).
- Team prefix for session names.
- Changes to the roles, models, efforts, colours or counts in the template.
- Extra context files that every session must read.
- Repository rules (secrets, private data, who approves destructive actions).

Then copy `templates/ADLC.md` to `docs/adlc.md`. Fill section 1, the repository rules and the first row of section 9 from the answers and step 1, with no machine value and no `<...>` placeholder left. The orchestrator name is `<prefix>-orchestrator`, not the launcher name. Apply the role changes: a value goes in the roles table, and a change to the work of a role goes in `docs/adlc/roles/<role>.md` (see the retro role file, "Where a change goes").

If `docs/adlc.md` exists and does not meet the current template (for example, its `sofa-template-version` is lower than the one of the template), migrate it and `docs/adlc/roles/` to the current definitions. The file already holds the answers of the setup questions, so do not ask them again. To find how an older file maps to the current template, start a subagent with the model `haiku` (Agent tool, `model: haiku`). It reads the git history of `skills/sofa` in `ai-ready-future/skills`: the commits and their PRs, from the version of this `docs/adlc.md` to now. It returns each change to the template and the role files, and what each change means for an older `docs/adlc.md`. Before you land the migration, tell the user what it changes, and continue only after the user agrees, because each machine that runs the team shares this file.

Land the files on `main` with a worktree, a PR and a squash merge. If live sessions of an older team exist (`ListAgents`), stop them before step 3, because they work from the old definitions.

If `docs/adlc.md` meets the current template, go to step 3.

## Step 3 — Start the orchestrator

1. Pull `main` in the main folder, so that `docs/adlc.md` on disk is the one on `main` (the mod reads it there). Then read it.
2. If `ListAgents` shows a live session with the orchestrator name, tell the user that the team runs, and how to open it (step 3.5). Stop, because a second orchestrator starts a second team.
3. Start the orchestrator with the command in section 8, from the main folder, with the orchestrator name and the model and the effort of the orchestrator row. Use this start prompt, with the machine values of step 1:

   ```
   You are the orchestrator of the <prefix> team. Read docs/adlc.md on main.
   Then read your role files (section 3, "Role files"): <skill folder>/references/roles/orchestrator.md,
   and docs/adlc/roles/orchestrator.md if it exists. Where they differ, the repository file wins.
   Do the role "orchestrator" as written there. Start with "At start".
   Machine values: main folder <main folder>, skill folder <skill folder>, GitHub account <gh account>.
   The launcher is <launcher name>. Send it a DONE message when all sessions of the team are ready.
   ```

4. Wait for the `DONE` message from the orchestrator.
5. Tell the user how to work with the team: run `claude agents --cwd <main folder>` (in the main folder: `claude agents --cwd $(pwd)`). It shows only the sessions of this repository, in their role colours. Open the orchestrator, hitl or retro from there, or with `claude attach <name>`. Then this session has no more work.
