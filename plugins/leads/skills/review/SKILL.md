---
name: review
description: Use after a sales call with a lead, when the user gives a call transcript or a meeting link to review, score with MEDDPICC, or turn into a follow-up email. Triggers on "review the call with", "score this call", "MEDDPICC", "follow-up email after the call".
argument-hint: "<company> [transcript link or file]"
---

# Review mode

Read [../../shared/common.md](../../shared/common.md) first. It tells you where the leads folder is and the rules for all leads skills.

Use after a call. Output: a MEDDPICC score with quotes, a blunt review, a follow-up email draft, an updated deal file, and an updated habits file.

## Steps

1. **Get the inputs.**
   - The transcript. If the user gives a link to a meeting notes tool, fetch it with that tool and get the full transcript, not only the summary. If they give a file, read it. Save the text as `<company>/call-<date>-transcript.md`.
   - The deal file. See "Open or make a deal" in common.md. Ask the user for the names and roles of the people on the call if the "People" table does not have them.
   - The call guide, `<company>/call-<date>-guide.md`, if it exists.
   - The "Offer" and "Limits" sections of `_seller/profile.md`.

2. **Score with a separate reviewer.** Start a new subagent with the Agent tool (type `general-purpose`, never a fork of this session). Its prompt is the text of [reviewer-prompt.md](reviewer-prompt.md) below the line, with the paths filled in (`{MEDDPICC}` is the absolute path of `shared/meddpicc.md` in this plugin) and the "Offer" and "Limits" sections pasted in place of `{OFFER}`. Do not give it the habits file, earlier reviews, or your own opinion of the call. Do not change `deal.md` before step 6, so that the reviewer reads it as it was before the call.

3. **Check the reviewer's output.** Put each quote on its own line in a temporary file, and list the ones that are not in the transcript with one command: `while IFS= read -r q; do grep -qF -- "$q" <transcript> || echo "$q"; done < quotes.txt`. A quote can cross a line break in the transcript, so check each listed quote by eye. Remove each quote that is really not there, and each credit that the reviewer gives for words the seller said. Tell the user what you removed.

4. **Write the review** to `<company>/call-<date>-review.md` from the reviewer's output. Use this order:
   1. One paragraph: the result of the call, and what moved the deal.
   2. The MEDDPICC table, with changes since the last call.
   3. What went wrong. Most costly first. For each: the quote (or, for a question that was not asked, the moment in the call where it should have come), why it cost something, and a "Say instead" line.
   4. What went right. Each with a quote.
   5. Three habits for the next call.

5. **Draft the follow-up email** to `<company>/call-<date>-email.md`. If a skill for formal emails is available, use it.
   - Open with a short summary of what the buyer said, in the buyer's words, so they can correct it.
   - Ask the open questions that this buyer can answer. Keep technical questions for the next technical call.
   - Put the "must say" facts from the profile that were not said on the call.
   - End with the next step and a date.
   - Sign with the "Email signature" from the profile. Do not add a company name or title that the profile does not give.

6. **Update the deal file.** New facts with sources, the new MEDDPICC table, a row in the call log, and the next step with a date and an owner. In `leads.md`, set the stage and the next step with its date.

7. **Update the habits file.** For each "went wrong" item that matches a habit, add 1 to its count and add the date and the quote. If the habit's "Seen" list already has this call (same date and company), do not count it again. For a new mistake, add a new habit with a count of 1. See [../../shared/templates/habits.md](../../shared/templates/habits.md) for the format.

8. **Tell the user** the paths, the three habits, and the next step. Show the review and the email with the `mark` skill.
