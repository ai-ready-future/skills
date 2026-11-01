---
name: verify
description: How to verify changes in this repository at runtime. Read by the /verify skill.
---

# Verify this repository

## plugins/leads

1. **Load the plugin in Claude Code.** In an empty temp folder:

   ```
   echo "List the exact names of the skills from the plugin named leads." | claude -p --plugin-dir <repo>/plugins/leads
   ```

   Expect `leads:setup`, `leads:prep`, `leads:practice`, `leads:review`.

2. **Drive a skill with no data.** Set `LEADS_ROOT` to an empty temp folder and `XDG_CONFIG_HOME` to another temp folder, so `~/.config` is not touched:

   ```
   echo "/leads:prep acme" | LEADS_ROOT=$tmp/root XDG_CONFIG_HOME=$tmp/xdg claude -p --plugin-dir <repo>/plugins/leads --allowedTools "Read" "Bash(ls:*)" "Skill"
   ```

   Expect: it tells you to run `/leads:setup` first, and it writes no files. Pass the prompt on stdin: `--allowedTools` takes the next arguments as tool names.

3. **Drive the HTML templates in a browser.** Chrome does not open `file://` pages through the extension. Serve the folder with `python3 -I -m http.server 8765 --bind 127.0.0.1`, then open the page.
   - Game: put a real `GAME` block between `GAME_DATA_START` and `GAME_DATA_END` of `shared/templates/call-game.html`. Keys: Enter to start, then `1` and Enter for each scene. Open `#selftest` from a different page; a hash change on the same page does not reload it.
   - Deck: put slides between `SLIDES_START` and `SLIDES_END` of `shared/templates/call-slides.html`. Arrow keys move, `t` starts the timer, `o` opens the slide list.
