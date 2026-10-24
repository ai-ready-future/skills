---
name: osaat
description: Execute any series of steps one at a time with explicit confirmation between each step. Use when the user mentions "one at a time", "one by one", "step-by-step", "review one by one", or wants to review and approve each step individually before proceeding.
---

# OSAAT (One Step At A Time)

Execute any series of steps one at a time with explicit confirmation between each step.

## How It Works

1. Break the task into discrete, atomic steps.
2. Present the first step and ask for confirmation.
3. Execute the step after you receive confirmation.
4. Show the result and present the next step.
5. Repeat until all steps are complete.

The user can stop, change, or skip any step.

## Core Directives

- Always present a summary of the step.
- Always use the AskUserQuestion tool when you ask the user.
- Write each question as the rules in "How to Write a Question" tell you.

## How to Write a Question

The AskUserQuestion tool can hide the text that you write before the call. The user sees only the question body and the options. Thus, the question body must hold all of the context.

### Rule 1: Put all of the context in the question body

1. In the `question` field, write all of the facts that the user needs to answer. Include:
   - The step number and the total number of steps, for example "Step 2/5".
   - What the step does, and why it is necessary.
   - The result of the last step, if it changes this decision.
   - The files, commands, or values that the step touches.
2. Do not refer to text outside the question, for example "as shown above". The user possibly cannot see that text.
3. Write the question itself as the last line of the body. Make it end with a question mark.

### Rule 2: Show the alternatives with pros and cons

When you give the user 2 or more alternatives, write each alternative in the question body in this format. Put the list of alternatives after the context and before the last line, which is the question.

```markdown
- **<Name of the alternative>:** <What it does, in 1 or 2 sentences.> [recommended]
  - **Pros:** ✅
    - <One pro>
    - <One more pro>
  - **Cons:** ❌
    - <One con>
```

Example:

```markdown
- **Only the output code:** a result can come from a file or from standard input, and standard input prints "(standard input)". A unit test checks it. The end-to-end test comes later. [recommended]
  - **Pros:** ✅
    - This work stays small
    - The standard input code is not written 2 times
  - **Cons:** ❌
    - Only the later end-to-end test fully proves the label
- **The full standard input search now:** read standard input and print the label, with an end-to-end test.
  - **Pros:** ✅
    - The label is fully proven now
  - **Cons:** ❌
    - This work gets much larger
```

Obey these rules for the format:

- Put "[recommended]" at the end of the sentence of 1 alternative only. Put that alternative first.
- Give each alternative 1 pro and 1 con at minimum. Write each pro and each con as 1 short line.
- Make the `label` of each option a short form of the bold name in the body, 5 words maximum. Add "(Recommended)" to the label of the recommended option.
- In the `description` of each option, write 1 short sentence. The pros and cons stay in the body.
- If a step has only 1 action, ask "Do this step?" with the options "Yes (Recommended)", "Skip this step", and "Stop". Do not add pros and cons. The user can select "Other" to change the step.
