---
name: setup
description: 'Configure a repository for a sofa team, 1 item at a time: runs sofa:readiness, then fixes each missing item with the user. Idempotent: run it any time, for example to add Slack or a scanner later. Use when the user says "sofa setup", "set up sofa", "configure sofa", "add slack to sofa".'
disable-model-invocation: true
metadata:
  internal: true
---

# setup — make the repository ready for sofa

Run it any time. It only fixes what `sofa:readiness` reports as `missing` or `wrong`, so a second run on a ready repository changes nothing.

## Step 1 — Check

Run the `sofa:readiness` skill. Keep its table. If all items are `ok`, tell the user and stop.

## Step 2 — Fix 1 item at a time

Use the `osaat` way: for each item that is not `ok`, in the order of the table (blocking items first), show the item, the fix, and what the fix changes. Do the fix only after the user agrees. After each fix, run the check of that item again, and show the new status. The user can skip an item.

There are 3 kinds of fix:

- **The skill does it** (a script or a file change): add `.sofa/` to `.git/info/exclude`; `scripts/sofa-state init`; `knowledge.py registry add <name> --path <path>` for a brain folder that exists but is not registered; install the scheduler cron line (step 4); write `docs/adlc.md` (step 3).
- **The user runs a command** (built-in commands and `disable-model-invocation` skills that you cannot run): show the command with the `$ ` prefix on its own line, wait for the user to say it is done, then check again. Examples: `/init`, `/config` (autocompact, advisor, project instructions), `/auto-mode-setup`, `/knowledge:setup`, `/architecture:setup`, `/system-design:setup`, `/business-domain:setup`, `/product:setup`, `gh auth login`, `claude plugin install <plugin>@<marketplace>`.
- **A change in the repository** (a router `CLAUDE.md`, a `.gitignore` line, a project `verify` skill): make it in a worktree, open a PR, and tell the user. On a repository with a running team, send it to the orchestrator as a `TASK` for the designer instead.

Missing skills: install them with `npx skills add <owner>/<repo> -a claude-code` into the repository (no `-g`), so the team of every machine has the same skills. Missing plugins: show `claude plugin install` commands.

## Step 3 — The setup questions (only when `docs/adlc.md` is missing or a value is a `<...>` placeholder)

Ask with `AskUserQuestion`, at most 4 questions at a time. Skip a question that the repository already answers.

1. Team prefix for session names.
2. Risk appetite: `mvp` (pre-release, move fast), `early customers`, `established` (many customers).
3. Board tool: GitHub Projects, Linear, Jira, files, none.
4. Environments: for each one (dev, staging, prod), how to reach it, how to deploy, where the logs and metrics are. `none` is a valid answer.
5. Tools per role: security (`built-in`, semgrep, snyk, ...), code quality (`built-in`, sonarqube, ...), monitoring, feedback source, ux tool (`none`, sentry, posthog).
6. Healthy window (default `24h`).
7. Slack: a channel, or `none` (step 5).
8. Changes to the roles, models, efforts, output styles or counts in the template.
9. Repository rules: secrets, private data, who approves destructive actions.

Copy `<skill folder>/templates/ADLC.md` to `docs/adlc.md`, fill section 1 and the first row of section 9 from the answers. No machine value and no `<...>` placeholder stays. Land it on `main` with a worktree, a PR and a squash merge.

## Step 4 — The scheduler

Show the cron line of `references/roles/scheduler.md` with the machine values filled in (that file lists them). Make sure that Claude Code trusts the main folder and that `bg-watch` is installed; if not, tell the user the step. After the user agrees, add it with `(crontab -l 2>/dev/null; echo "<line>") | crontab -`, only if `crontab -l` has no `bg-watch check` line yet.

## Step 5 — Slack (optional, any time)

1. The user installs the Slack plugin (`$ claude plugin install slack@claude-plugins-official`) and makes a Slack app with a bot token (`slack:create-slack-app` helps). Scopes: `chat:write`, `channels:history`, `channels:read`, `reactions:read`, `users:read`.
2. The token goes in the environment (`SLACK_BOT_TOKEN`) or in `~/.claude/settings.json` under `env`. Never in the repository. Never print it.
3. Write the channel into section 1 (`Slack`) through a PR.
4. Send a test message to the channel and ask the user to react with ✅. Check the reaction.

## Step 6 — The human team

Interview the user: each person of the human team, their role, the decisions they own, who they escalate to, and their Slack handle. Ask 1 person at a time. Write each person as a page `people/<name>` of the `knowledge` brain with `knowledge:learn` (or, on a running team, send it to the orchestrator as a `TASK` for scribe). Later, `requests` adds each new person it meets.

## Step 7 — Report

Run `sofa:readiness` again and show the table. List the items the user skipped.
