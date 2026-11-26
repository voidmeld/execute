# Expertise lane brief

Use this brief to learn what good work looks like in a domain or to answer a gap
in an existing shelf. Copy the [shelf](../REFERENCE-SHELF.template.md) and
[reviewer's eye](../REVIEWERS-EYE.template.md) templates into your project if needed.
Fill in their paths and the location of the owner's feedback in the project's `AGENTS.md`.

- **Assignment.** Study [domain] for [users and task]. Answer [question that affects
  the current work]. Use [assigned worktree and branch]. Edit [shelf and checklist
  paths]. Follow the project's permissions for sources and tools. Check in by [time].
- **Research.** Read the existing entries. Choose reference works that excel at the
  task, explain why, and compare how they handle it. Inspect the works or first-hand
  accounts where possible. Record each finding in the shelf template. If you cannot
  verify a claim, record what you tried and what evidence is missing.
- **Apply.** Turn a finding that transfers into a question for a named review or QA
  lane. Read the owner's recorded decisions and feedback. Adjust the question to
  reflect them while keeping the observation about the reference accurate.
- **Check and return.** Try the question on a sample change. Record what you saw
  and trace the question back to its shelf entry and source. Return the checked
  change, the result, and any gap that still matters to the assignment.

## Worked example

A command-line tool needs to help someone recover from a mistyped option. These
two original sample diagnostics serve as the reference works for this exercise.

| Specimen | Diagnostic |
| --- | --- |
| A | `Unknown option.` |
| B | `Unknown option --ouptut. See --help for valid options.` |

- **Shelf entry — option errors.** The command interface maintainer owns this
  mechanism. **Primary** — B identifies the rejected option and gives a next step.
  A fits on a short line but gives no next step. The source is the pair of specimens
  above. **Hypothesis** — pointing to help makes recovery easier. **Unknown** —
  neither specimen shows whether a new user can find the right option in help.
- **Transfer.** The recovery hint fits this task. Repeating user input conflicts
  with the owner's recorded preference to keep submitted text out of diagnostics.
- **Interface review.** After a rejected option, can the user find a valid option
  from the hint? See the shelf entry on option errors.
- **Failure-path QA.** Pass a made-up option. Check that the diagnostic points to
  help and omits the submitted text. B fails the second check. A revision reading
  `Unknown option. See --help for valid options.` passes both diagnostic checks.
  Try following the hint with a new user to answer the open question.
