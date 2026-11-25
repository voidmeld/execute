# Operating guide

<a name="work-one-backlog-item"></a>

## Work on one backlog item

1. Read the project's `AGENTS.md` and `BACKLOG.md`. Pick the first request that's ready to start.
   Decide how you'll tell whether the change works.
2. Make the smallest change that fulfills the request. If helpers are available, give each one its own
   worktree and a [brief](helper-brief.md) for a part it can complete independently.
3. Try the change as a user would. If a web app should remember a filter, select one, reload the page, and
   check that it's still selected. If a command should reject an invalid option, run it with that option
   and check both the error message and the exit status. For a parser fix, pass the input that caused the
   problem to the library's public parser and check the result.
4. Review the whole diff, including any helpers' changes. Update the backlog and commit. With the worktree
   clean, run the project's fast check on that commit. If the command exits with a nonzero status, stop
   before pushing. Fix the problem, commit the fix, and rerun the check on the corrected commit.
5. If you're authorized to push, send the commit that passed to `main` through the project's approved route.
   If `main` has moved ahead, include its changes and rerun the fast check on the combined commit before pushing.

When a release is due, someone with release permission runs the project's release command from the checked
revision on `main` for the named destination. Verify the revision at that destination and try the change there.
If the release is interrupted, check which revision arrived before retrying. If the change fails, keep the
item open and record what happened so the next person knows what to fix.

Continue with the next ready request. Once every item is done or blocked, resume when a new request
arrives or a blocked item is ready to start again.

## Stall check

When you start an item or assign a helper, pick a time to check progress, such as 30 minutes from now.
Compare what you can observe about the requested change with what you saw at the last check.
Inspect `main`, the assigned worktree, and the latest check or running job.

```sh
git log -1 --format='%h %cr %s' main
git log -1 --format='%h %cr %s' HEAD
git status --short --branch
```

- If a check is making progress, choose the next time to check on it or wait for it to finish within its deadline.
- If a helper has finished, review its commit.
- If the same failure keeps happening or nothing has moved forward, try one smaller step that helps narrow down the cause.
- If you need a decision or access to fix the problem, record what you need on the backlog item and pick the next ready request. Leave other sessions' processes alone.
