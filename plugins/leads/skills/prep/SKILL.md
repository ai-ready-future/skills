---
name: prep
description: Use before a sales call with a lead or a prospect, when the user asks to prepare a call, write a call guide or a call deck, or research an account before a call. Triggers on "prep my call with", "prepare for the call with", "call guide".
argument-hint: "<company>"
---

# Prep mode

Read [../../shared/common.md](../../shared/common.md) first. It tells you where the leads folder is and the rules for all leads skills.

Use before a call. Output: a conflict check, account research, a MEDDPICC map, a call guide, and a timed deck.

**The core rule: learn the target before you say any number.** See "Target" in [../../shared/meddpicc.md](../../shared/meddpicc.md). No price, rate, quantity, or term goes in the guide before the target question.

## Steps

1. **Read the inputs.** The intro email or message, any profile text the user pasted, the company name, `_seller/profile.md`, and `_seller/habits.md`. Open or make the deal (see common.md), with the stage "first call booked" and the call date.

2. **Check for conflicts. Do this before any research.** Read the "Conflict check" section of the profile.
   - If the section is missing or empty, ask the user if any client list, agreement, or non-solicit clause limits them. Write the answer in the section ("None" if there is none), then continue.
   - If the section says "None", write "No conflicts listed" in the deal file and continue.
   - Compare the company, its parent company, and each person in the inputs with each list in the section. Check the end dates against today's date.
   - If there is a match, or if you are not sure, stop. Tell the user what matched and why. Continue only when the user says so.
   - Write the result, with the date, in the deal file under "What we know".

3. **Research the account** with web search. Write it to `<company>/research.md`. Cover: size, money (funding, owners), leaders and recent changes, recent news, moves in the area that you sell into, and adverse media (lawsuits, layoffs, employee reviews). Give a link for each fact. Write "not found" for each item that you looked for and did not find. End with "What this changes for the plan": 3 to 5 points.

4. **Map MEDDPICC** in the deal file. Use the rules in [../../shared/meddpicc.md](../../shared/meddpicc.md). Before the first call, most letters are `unknown` or `assumed`. Match the lead to an ICP in the profile, and use its usual signer and paper process as `assumed` entries. If the contact leads a program or a team and does not own a budget, add this warning: "This person is often not the signer. Find out who signs."

5. **Write the call guide** to `<company>/call-<YYYY-MM-DD>-guide.md`. Use this order:
   1. **Goals of the call**: what you must know when the call ends, and the next step you will ask for.
   2. **Time plan** for the call length.
   3. **Must ask**: 5 questions. Pick the 5 biggest gaps in the table from these 6 topics, and keep this order. If the paper process is not one of the 5, put it first in "Admin and next steps".
      1. Why now.
      2. The target in numbers: how many, how much, by when, and who judges it.
      3. The sponsor and the signer: who backs it, and who signs the contract.
      4. The pain: what it costs them today. Ask about the past, not opinions about the future.
      5. The data for measures: what they measure today.
      6. The paper process: the steps from "yes" to a signed contract, and how long they take.
      Each question gets one main question, "listen for" boxes, and at most one follow-up. Do not ask what the inputs already answer.
   4. **Your intro (60 seconds)**: who you are, then one proof point from the profile that matches the ICP. No titles in a list.
   5. **The price line**: "The price is {price}. For what we discussed, I recommend {scope}." Then: "Stop talking." Put this after the target question in the time plan. If the buyer asks for the price before the target, the guide says: answer with the price, then ask the target question at once.
   6. **Must say**: the facts from the profile's "Must say" section, for example limits on time or supply, dates, and terms.
   7. **Don't say**: the top 3 habits by count from the habits file, each with its better line. If the habits file is empty, write "No habits recorded yet."
   8. **Admin and next steps**: the signer, the paper process, the start date, access, and a next step with a date.
   9. **Questions for a technical call**: the technical questions that this buyer cannot answer.

6. **Build the deck.** Copy [../../shared/templates/call-slides.html](../../shared/templates/call-slides.html) to `<company>/call-<date>-slides.html` (see "Copy a template" in common.md). Write one `<section>` for each part of the guide, between `SLIDES_START` and `SLIDES_END`. Set `data-min` to the planned minute, and `data-minutes` on `<body>` to the call length. Put few words on each slide: the question to say, and the points to listen for. Set `<title>` to the company and the date.

7. **Tell the user** the paths and the 5 must-ask questions. Show the guide.

## Self-check before you finish

- The target question comes before the price line in the guide and in the deck.
- The signer and the paper process are in the must-ask questions or in admin.
- Each fact in the research has a link.
- The conflict check result is in the deal file.
