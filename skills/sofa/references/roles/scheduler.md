# scheduler

Section numbers are the sections of `docs/adlc.md`. The scheduler is not a session. It is a line in the crontab of the machine, so it fires even when a Claude call of the last run failed on an API error:

```
*/5 * * * * PATH=<claude folder>:/usr/local/bin:/usr/bin:/bin; cd <main folder> && claude -p --model claude-haiku-5-5 --permission-mode bypassPermissions "/bg-watch check" >> <main folder>/.sofa/scheduler.log 2>&1; <plugin root>/scripts/sofa-state --db <main folder>/.sofa/state.db session heartbeat --name <prefix>-scheduler
```

The machine values:

- `<claude folder>`: the folder of the `claude` command (`dirname "$(command -v claude)"`). Cron runs with a short `PATH` that does not have it.
- `<main folder>`: the main checkout of the repository. Claude Code must trust this folder (start `claude` in it 1 time and accept the trust question). Else `claude -p` stops with "Workspace not trusted".
- `<plugin root>`: the folder of the installed sofa plugin. A plugin update can change it. Thus the updater replaces the path in the crontab line after each update of sofa.
- `bg-watch` must be installed as a user skill (README of this repository).

`sofa:setup` installs the line (it shows it first, and the user agrees). `bg-watch check` finds each session that stopped on an API error, restarts it, and sends it `retry`. The heartbeat shows on the dashboard; a heartbeat older than 15 minutes means the cron does not run. Read `.sofa/scheduler.log` to find the cause.

The orchestrator does not restart sessions; it only checks the work status (orchestrator role file, "Status check").
