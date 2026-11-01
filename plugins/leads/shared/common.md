# Leads: rules for all skills

Read this file before you do the steps of a `leads` skill. The skills are `/leads:setup`, `/leads:prep`, `/leads:practice`, and `/leads:review`. In these files, `setup`, `prep`, `practice`, and `review` mean those skills.

The goal: each call moves the deal one clear step, and each review makes the next call better.

## Find the leads root

All deal data stays in the user's private leads folder, never in this plugin. Find the folder in this order:

1. `LEADS_ROOT`, if it is set.
2. The path in `${XDG_CONFIG_HOME:-$HOME/.config}/leads/root`, if the file exists.
3. The first folder that contains `_seller/profile.md`: the current folder, then each parent folder up to the home folder.

If you find no root, or the profile has no "Offer" section, tell the user to run `/leads:setup` first, and stop. `setup` itself does not stop here.

## Files under the root

| File | What it holds | Who writes it |
|---|---|---|
| `_seller/profile.md` | The seller: offer, price, limits, proof points, ideal customer profiles (ICPs), conflict list, "must say" facts | `setup` |
| `_seller/habits.md` | Mistakes that repeat from call to call, each with a better line and a count | `review` |
| `leads.md` | The lead list: one row for each lead, with the stage and the next step | `setup`, `prep`, `review` |
| `<company>/deal.md` | People, facts, the MEDDPICC table, the call log, the next step | All skills |
| `<company>/research.md` | Account research with sources | `prep` |
| `<company>/call-<date>-<kind>` | One file for each call and kind: `guide.md`, `slides.html` (`prep`), `game.html` (`practice`), `transcript.md`, `review.md`, `email.md` (`review`) | See the kind |

`<company>` is a slug: lowercase letters, numbers, and hyphens, for example `northwind-clinics`. `<date>` is the call date as `YYYY-MM-DD`.

The templates are in [templates/](templates/). Read [meddpicc.md](meddpicc.md) before you write or change a MEDDPICC table.

## Open or make a deal

1. If `<company>/deal.md` exists, read it.
2. Else copy [templates/deal.md](templates/deal.md) to it, and fill in the facts that you have, each with its source. Pick the best ICP from the profile, and mark it "assumed" unless the user names it.
3. If the lead has no row in `leads.md`, add one: company, ICP, stage, next step, date (or "no date", sorted last), and a link to the deal file.

Stages, in `leads.md` and in the deal file's "Status": new, first call booked, after call N, proposal sent, signed, lost, parked.

## Copy a template

Copy an HTML template with `cp`. Then read and edit only the part between its markers (`SLIDES_START` and `SLIDES_END`, or `GAME_DATA_START` and `GAME_DATA_END`). Do not read or rewrite the rest of the file.

## Rules

- Cite a source for each fact: a link, a file, or "user said". A blank cell means "not checked". Do not fill it with a guess. Mark a guess "assumed".
- Credit the buyer only for what the buyer said. Words that the seller said are not buyer evidence.
- Never write the seller's private data (prices, clients, agreements) into a file outside the leads root.
- Do not scrape social networks. The user pastes profile text by hand.
- A proof point is a specific result: who (a type of company and a place), what, a number, and when. A label or a title ("certified", "award winner") is not a proof point.
- Write for the user in short, plain sentences. At the end of a skill, show the files that its last step names with the `mark` skill, if it is available.
- Do not commit to git unless the user asks.

## Methods

MEDDPICC for qualification. Alan Weiss: agree on objectives, measures, and value before a proposal, and find the person who signs. Chris Voss: silence after the number. Rob Fitzpatrick, *The Mom Test*: ask about the past, not opinions about the future.
