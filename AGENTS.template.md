# [Project name]

[What users should be able to do with the product.]

## Work

Take the first ready item in `BACKLOG.md`. Keep the owner's wording and order.
Set a checkpoint for active work. Exercise the changed behavior as a user would.
Mark the item done when its stated outcome is met.
If it is blocked, record what would unblock it and continue with the next ready item.

## Hard rules

- Run `<fast guardrail command>` on the clean commit before every push to main. Fix any failure and check the new commit.
- Only [push operator] may push to [main destination] through [allowed route].
- Only [ship operator] may ship. From the checked main commit, run `<ship command>` for [allowed destination]. Confirm the version and verify the outcome at that destination.
- Never expose credentials. Reserve [spending, uploads, destructive actions and other restricted operations] for [holder].
- Use separate worktrees for concurrent edits. Use only assigned sessions and resources. Preserve unfinished work.
- [Add the project's hard rules here.]

Hold an action until the owner fills its grant.
