# Current operation

Keep current facts and ready work here. Put useful lessons in the rule or procedure that they change.

- CEO identity, harness, settings and appointment commit: FILL
- Current accepted product, build and evidence: FILL
- Verification commands and destination: FILL
- Current action, outcome, acceptance check and falsifier: FILL
- Surface driver, instance or PID, build, tools, scope, lifecycle and release condition: FILL
- Dependencies, blocking event or clearing event: FILL
- Next ready outcome and its user value: FILL

Link architecture and system-specific procedures at their actual source.
Record a current incident only while its failure and recovery decision affect the next action.
Exact Owner grants belong in [OWNER](OWNER.md).

## Recovery

A successor reads this section first and needs no chat history.
Keep it current at every handoff and before you yield. Delete a line when its work lands or is disposed.

- Helpers: for each declared session, its identity, worktree, branch, base, current assignment and state (running, returned or blocked). Link its one replaceable result record. FILL
- Background tasks: for each task, the exact command, worktree, start time, output location and what its completion unblocks. FILL
- Unlanded branches and worktrees: path, branch, head commit, what remains and whether it is safe to discard. FILL
- Integration in progress: branch, candidate commit, last refusal and its log path, or none. FILL
- Next action: the single next step and its exact command. FILL
- Native/heavy slot: current holder, command, source, completion notification and release condition, or free. FILL

Keep one current product plan in the adopting project. Replace superseded state; do not replay old briefs or keep a second prompt queue.

### Resume

1. Read the records above.
2. Verify them against the machine: run `git worktree list`, check each branch head and check whether each listed task still runs.
3. If the machine and the record differ, trust the machine and correct the record.
4. Reuse a listed worktree through worker-setup. Do not recreate it. Run its freshness check to learn what is stale.

A tool that stops during a run leaves its state in git, not in the tool. Look for these:

- a worktree in the middle of a rebase (`git status` shows it)
- a worktree and branch that the landing tool created for a train (several branches landed together)
- a candidate that you did not push

Inspect with git. Finish or abort the rebase. Remove a train worktree whose members are intact. Run the tool again.
Landing is idempotent until the push.
Never start a second integration while a live integration holds main.
