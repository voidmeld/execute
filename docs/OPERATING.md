# Operating guide

## Work one backlog item

1. Read the project's `AGENTS.md` and `BACKLOG.md`. Take the first ready request. Decide how to observe its outcome.
2. Make the smallest change that delivers it. If helpers are available, give each one an independent
   [brief](helper-brief.md) and its own worktree.
3. Check the change where a player would encounter it. For example, if the map should remember the selected room,
   select a room, close the map, and reopen it. Verify the same room is selected.
4. Review the combined diff, update the backlog, and commit. Run the project's fast guardrail command on that
   clean commit. A nonzero exit blocks the push. Repair the failure and run it again on the corrected commit.
5. The authorized operator pushes the passing commit to main through the project's allowed route.
   If main has advanced, incorporate the new base and rerun the guardrail on the combined commit.

When a release is due, the authorized operator runs the ship command on the checked main revision for the named
destination. Verify the running revision and try the changed behavior there. If shipping is interrupted, check
which revision arrived before retrying. Keep a failed item open with the observation that still needs repair.

Continue with the next ready request. When all work is done or blocked, resume on new work or a cleared dependency.

## Stall check

Set a checkpoint when an item or helper starts (for example, after 30 minutes). Compare the last observed player
outcome with the current one. Inspect main, the assigned worktree and the last check or running job.

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
