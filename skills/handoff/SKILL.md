---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Optionally send it to a named Claude session.
argument-hint: "[@session-name] What will the next session be used for?"
---

Render a handoff document in your reply that summarises this conversation closely enough for a fresh agent to continue the work. Write no file, because the rendered text is the deliverable the user carries into the next session. To send the document to a session instead, see "Send to a session".

Include a "suggested skills" section that names the skills the next agent should invoke.

Reference existing artifacts (PRDs, plans, ADRs, issues, commits, diffs) by path or URL rather than restating them, because a copy goes stale as soon as the artifact changes.

Redact API keys, passwords, and personally identifiable information.

An argument, when the user passes one, names what the next session will focus on. Tailor the document to it.

## Send to a session

When the argument starts with `@<session-name>`, that word names the session that gets the work. The text after it is the focus.

1. Load the tools in one call: ToolSearch `select:ListAgents,SendMessage`.
2. Find the session in `ListAgents`. If no session has that name, render the document in the reply, tell the user that the session was not found, and stop. If two sessions have the name, ask the user which ref to use.
3. Send the document with `SendMessage` to the session. Start the message with one line: "Handoff from session `<this session name>`. Continue this work."
4. In the reply, tell the user which session got the document, and how to open it: `claude attach <session-name>`. Do not render the full document again, because the session already has it.
