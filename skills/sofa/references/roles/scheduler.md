# scheduler

Section numbers are the sections of `docs/adlc.md`. The scheduler is not a session. It is a line in the crontab of the machine, so it fires even when a Claude call of the last run failed on an API error:

```
*/5 * * * * cd <main folder> && claude -p --model claude-haiku-5-5 --permission-mode bypassPermissions "/bg-watch check" >> <main folder>/.sofa/scheduler.log 2>&1; <skill folder>/scripts/sofa-state --db <main folder>/.sofa/state.db session heartbeat --name <prefix>-scheduler
```

`sofa:setup` installs the line (it shows it first, and the user agrees). `bg-watch check` finds each session that stopped on an API error, restarts it, and sends it `retry`. The heartbeat shows on the dashboard; a heartbeat older than 15 minutes means the cron does not run.

The orchestrator does not restart sessions; it only checks the work status (orchestrator role file, "Status check").
