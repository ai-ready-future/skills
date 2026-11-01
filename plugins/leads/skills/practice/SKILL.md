---
name: practice
description: Use when the user wants to rehearse a sales call with a lead before it happens, or asks for a practice game or a role play for a call. Triggers on "practice the call", "rehearse my call with", "call game".
argument-hint: "<company>"
---

# Practice mode

Read [../../shared/common.md](../../shared/common.md) first. It tells you where the leads folder is and the rules for all leads skills.

Use the day before a call. Output: a practice game in one HTML file, which passes its self-test.

## Steps

1. **Read the inputs.** The call guide for the next call, `<company>/deal.md`, `<company>/research.md`, the last review if one exists, `_seller/habits.md`, and `_seller/profile.md`.

2. **Copy the engine.** Copy [../../shared/templates/call-game.html](../../shared/templates/call-game.html) to `<company>/call-<date>-game.html` (see "Copy a template" in common.md). Change only the `GAME` object. Do not change the engine.

3. **Write the scenes** in the order of the call:
   - One scene for each must-ask question in the guide. The buyer says something that gives the seller a chance to ask it.
   - One scene for the intro, one for the price, one for each likely objection (for example the price, the timing, "can you do all of it?", a competitor), and one for the close.
   - One extra scene for each of the top 3 habits in the habits file. Make the habit's mistake one of the options, with its real quote as the `real` line if one exists.
   - To mark a new part of the call (for example "Objections"), you can add a chapter scene: `{ chapter: "Title", text: "One line." }`. It has no options and no points.
   - Write the buyer's lines from the deal file and the research, in the buyer's voice. Do not make up facts about the buyer. Use the facts that you have, or a general line.

4. **Write the options.** Each scene has exactly 4 options:
   - One best option with `p: 10`. Its text is also the scene's `best` line.
   - One costly option with `p` of 0 or 1, so that the worst path stays under 20%. It is a real mistake: a hedge on the price, a pitch before questions, a label in place of proof, a promise you cannot keep.
   - Two options in the middle (`p` from 2 to 7), each with a different flaw.
   - Each option has `why` (the lesson in one sentence) and `r` (the buyer's reply). No empty text. No em dashes or en dashes.
   - Use `set` and functions of `f` when a good early answer changes a later scene. For example, if the seller learned the target, the later price scene can refer to it.

5. **Set the text.** `title`, `intro` (who the buyer is, the call length, and the seller's limits), and `start`.

6. **Run the self-test.** The script is in the plugin, two folders up from this skill's folder:

   ```
   node <this skill's folder>/../../shared/scripts/game-selftest.mjs <path to the game>
   ```

   If the script does not print `PASS`, it lists what failed. Fix the scenes and run it again. Do not give the game to the user before it passes.

7. **Tell the user** the path and the self-test result. They open the file in a browser. Keys: 1 to 4 to answer, Enter to continue.
