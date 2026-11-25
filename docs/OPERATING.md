# Operating guide

## Work one backlog item

1. Read the project's `AGENTS.md` and `BACKLOG.md`. Take the first ready request. Decide how to observe its outcome.
2. Make the smallest change that delivers it. If helpers are available, give each one an independent
   [brief](helper-brief.md) and its own worktree.
3. Check the changed behavior as a user would. For a web app that should remember a filter, set the
   filter, reload the page, and verify it remains selected. For a CLI that rejects invalid options, run it with an
   invalid option and check the error and exit status. For a library that fixes a parsing issue, call its public
   parser with the affected input and check the result.
4. Review the combined diff, update the backlog, and commit. Run the project's fast guardrail command on that
   clean commit. A nonzero exit blocks the push. Repair the failure and run it again on the corrected commit.
5. The authorized operator pushes the passing commit to main through the project's allowed route.
   If main has advanced, incorporate the new base and rerun the guardrail on the combined commit.

When a release is due, the authorized operator runs the ship command on the checked main revision for the named
destination. Verify the revision there and try the changed behavior. If shipping is interrupted, check which
revision arrived before retrying. Keep a failed item open with the observation that still needs repair.

Continue with the next ready request. When all work is done or blocked, resume on new work or a cleared dependency.

## Stall check

Set a checkpoint when an item or helper starts (for example, after 30 minutes). Compare the last observation of
the requested outcome with the current one. Inspect main, the assigned worktree and the last check or running job.

```sh
git log -1 --format='%h %cr %s' main
git log -1 --format='%h %cr %s' HEAD
git status --short --branch
```

- If a check is advancing, set the next checkpoint or wait for completion within its deadline.
- If a helper has finished, review its commit.
- If the same failure repeats or nothing has advanced, try one smaller step that can distinguish the cause.
- If the fix needs a decision or access, put that dependency on the item and take the next ready request.
  Leave other sessions' processes alone.
