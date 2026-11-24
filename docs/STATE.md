# Current operation

Keep current facts and ready work here. Put useful lessons in the rule or procedure that they change.

- CEO identity, harness, settings and appointment commit: FILL
- Current accepted product, build and evidence: FILL
- Verification commands and destination: FILL
- Current action, outcome, acceptance check and condition that disproves success: FILL
- Surface driver, instance or PID, build, tools, scope, lifecycle and release condition: FILL
- Dependencies and events that block or clear them: FILL
- Next ready outcome and user value: FILL

Link architecture and system procedures at their actual source. Keep an incident here only while its failure or
recovery decision affects the next action. Exact Owner grants belong in [OWNER](OWNER.md).

## Recovery

A successor reads this section first and needs no chat history. Before a handoff or return, update these
records. When work lands or is disposed, delete its line.

- Workers: identity, worktree, branch, base, ordered assignment, current outcome, exclusive paths and runtime, return boundary and state. FILL
  Use running, returned or blocked. Link the one replaceable result record.
- Background tasks: exact command, worktree, start time, output path and the work that completion permits. FILL
- Unlanded branches and worktrees: path, branch, head commit, remaining work and whether disposal is safe. FILL
- Integration in progress: branch, candidate commit, last refusal and log path, or none. FILL
- Next action: one step and its exact command. FILL
- Shared resources: holder, command, source, completion notification and release condition, or free. FILL
  Include shared desktop input, capture and qualification resources.

Keep one current product plan in the project. Replace old state. Do not repeat old briefs or keep a second
prompt queue.

### Resume

1. Read the records above.
2. Run `git worktree list`.
3. Check each branch head.
4. Check whether each listed task still runs.
5. If the machine differs from the record, correct the record to match the machine.
6. Reuse each listed worktree through worker-setup.
7. Run its freshness check to identify stale inputs.

If a tool stops during a run, inspect Git state. `git status` identifies a rebase in progress. Also check for a
train branch and worktree, or a candidate that you did not push. Finish or abort the rebase. Remove a train
worktree only if its members are intact. Run the tool again. Landing is idempotent until the push. Do not start
a second integration while a live integration holds main.
