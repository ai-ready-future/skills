---
name: setup
description: Use when the user starts using the leads plugin, has no leads folder yet, or wants to change the offer, the price, the ICPs (ideal customer profiles), or the lead list. Triggers on "set up leads", "leads setup", "update my ICP", "add a lead".
argument-hint: "[part to update]"
---

# Setup mode

Read [../../shared/common.md](../../shared/common.md) first. It tells you where the leads folder is and the rules for all leads skills.

Use the first time, and again when the offer or the ICPs change. Output: a leads folder with the seller profile, the habits file, and the lead list, and a config file that points to that folder.

Ask one topic at a time. Use the AskUserQuestion tool for choices. Ask in chat for free text. After each topic, show what you will write and ask the user to confirm or change it.

## Steps

1. **Find or make the leads folder.**
   - If a leads root exists (see "Find the leads root" in common.md), tell the user its path and ask: update it, or start a new folder?
   - Else ask where to keep it. Suggest `~/leads`. Show the absolute path and ask the user to confirm it. Then make the folder.
   - Write the absolute path, on one line, to `${XDG_CONFIG_HOME:-$HOME/.config}/leads/root`. Make the folder if it does not exist.
   - Make `_seller/` and the empty files from the templates: [../../shared/templates/profile.md](../../shared/templates/profile.md) to `_seller/profile.md`, [../../shared/templates/habits.md](../../shared/templates/habits.md) to `_seller/habits.md` (keep the title and the line that says what the file is for; drop the example habit), and [../../shared/templates/leads.md](../../shared/templates/leads.md) to `leads.md`. Do not overwrite a file that exists.
   - Suggest `git init` in the folder, so the user can see changes over time. Do not run it unless the user says yes.

2. **The seller and the offer.** Ask: the seller's name and email signature, what you sell (one sentence), the price and its unit, the usual deal size, and a small deal limit (a deal size under which a short score is enough). Write the "Offer" section.

3. **Limits.** Ask what the seller cannot change on a call: availability or supply, dates, and terms. Each item is optional. Write the "Limits" section.

4. **Must say.** Ask which facts every buyer must hear from the seller. Suggest the limits from step 3. Write the "Must say" section.

5. **Proof points.** Ask for 1 to 3 specific results. See the proof point rule in common.md. If the user gives a label, ask for the result behind it. Write the result as the proof point. If the label is a fact a buyer needs (for example a compliance status), ask if it goes in "Must say". Write the "Proof points" section.

6. **Conflicts.** Ask if a client list, an agreement, or a non-solicit clause limits who the seller can sell to, with end dates. Write the list, or "None".

7. **ICPs.** An ICP (ideal customer profile) is a type of company that buys from the seller.
   - If deal files exist (`*/deal.md`), read them first. Group the deals by company type, and write a draft ICP for each group. If a deal is for a different offer than the one in step 2, say so, and ask if that type of buyer is still in scope. Show the drafts, with the deals that each one comes from, and ask the user to confirm, change, or delete each one. Write "not checked" for each field that the deals do not show.
   - Then ask if there is another type of buyer to add. Repeat until the user says no.
   - For each ICP, get: a short name (no number), the company (size, industry), the usual buyer titles, the usual signer, the pains, the proof point to lead with, and the usual paper process (the steps from "yes" to a signed contract, and how long).
   - Ask which ICPs are out of scope for this skill (for example, deals so small that MEDDPICC is too heavy). Mark them "out of scope".
   - Write the "ICPs" section.

8. **The lead list.** For each folder with a `deal.md`, add a row to `leads.md`: the company, the ICP from the deal file (or the best match from step 7, marked "assumed"), the stage, the next step, its date, and the link to the deal file (see "Open or make a deal" in common.md). Ask the user to confirm the rows. Then ask if there are other leads to add now. For each new lead, open or make the deal (see common.md) with the facts the user gives and the seller's name from step 2.

9. **Finish.** Show the paths of the files. Show the profile with the `mark` skill if it is available. Tell the user the next command, for example `/leads:prep <company>`.

## Run setup again

When the root exists, ask which part to update: offer, limits, must say, proof points, conflicts, ICPs, or the lead list. Do only that part. Keep the other sections as they are.
