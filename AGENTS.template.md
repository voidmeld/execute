# [Project name]

[Describe what users should be able to do with the product.]

## Work

Pick the first ready item in `BACKLOG.md`. Keep the owner's wording and priority order.
Set a time to check progress while the work is underway. Try the change as a user would,
and mark the item done when you can see the result it calls for. If you're blocked, record
what you need to continue and move on to the next ready item.

## Domain expertise

If the project keeps a reference shelf, read the relevant entry in [shelf path]
before choosing an approach. Every review and QA lane reads its section of
[reviewer's-eye checklist path] by default. The owner's recorded taste and feedback
in [location] take precedence over the shelf and checklist.

## Hard rules

- Before every push to `main`, run `<fast guardrail command>` on the commit you plan to push, with a clean worktree. If it fails, fix the problem and rerun the check on the new commit.
- Only [name or role] may push to [main destination], and only through [allowed route].
- Only [name or role] may release the software. Run `<ship command>` from the checked commit on `main` for [allowed destination]. Confirm the version there and check that the change works.
- Never expose credentials. Only [name or role] may [spend money, upload files, make destructive changes, or take other restricted actions].
- Use separate worktrees for concurrent edits. Use only the sessions and resources assigned to you, and preserve unfinished work.
- [Add the project's hard rules here.]

If the owner hasn't filled in the permission for an action, wait before taking it.
