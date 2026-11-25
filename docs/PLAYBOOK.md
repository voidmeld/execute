# Playbook

This page owns work procedures. [TASKS](TASKS.md) owns roles and assignments. The project supplies exact
commands, destinations and required proof.

## Daily iteration

Document the short path from an edit to its real consumer. Include focused checks, the changed behavior, result
inspection and repair. Link integration and publication only where needed. Keep first-time setup and failure
recovery outside this path. An ordinary edit must not reinstall dependencies, rebuild unrelated artifacts,
reopen healthy applications or repeat valid calibration. Refresh changed source bindings only. Invalidate
evidence only where its inputs change.

Use existing tools before you add a wrapper. An open or setup command reuses the exact healthy resource when
possible. It refuses ambiguous matches. Before a tool replacement, measure setup, synchronization, startup and
verification separately. Keep the working route until the replacement completes a real task and its relevant
failure and recovery path. Keep commands and recovery instructions in the owning runbook. Link that runbook from
current state. A successor must need no chat history. Put a workflow repair in that runbook, without a second
checklist or private handoff note.

## Evidence

Use the cheapest check that can disprove the claim. A lower step cannot prove a higher step's claim:

1. **Static checks:** source, types, contracts and deterministic builds.
2. **Automated tests:** the behavior that the tests exercise.
3. **Product-level acceptance:** FILL: the exact candidate runs in its real host, with recorded observations.
4. **Owner acceptance:** the Owner judges the result against [TASTE](TASTE.md).

A destination readback proves what arrived. A fake is a diagnostic model. Require it to refuse what the real
host refuses. Do not use a fake to accept an unobserved host claim. For a running-product claim, the assigned
worker or CEO runs the exact candidate in the required host. Record these items:

- the product commit and artifact
- the host and destination version
- relevant configuration and dependencies
- observed output and receipt path
- FILL: other required product evidence

Bind evidence to the product commit that ran. Workers run checks and repair assigned outcomes. The CEO judges
the returned evidence against fixed criteria. If OWNER requires independent review, follow its scope under
[TASKS](TASKS.md#review). State coverage and limits. A passed gate does not prove the whole product. Add a
regression for each defect the Owner finds at a boundary that can detect it. Present a build only after its
required acceptance checks pass. For a product with an interface, add the [interactive QA
extension](../extensions/interactive-qa/README.md).

## Runtime ownership

Give each runtime one driver.

- Reuse standing authority and healthy resources that you own.
- In STATE, record the exact instance or PID, document or build, driver and release condition.
- Add applicable restrictions. Do not repeat unchanged grants for each run.
- Transfer control before another driver acts.
- When the run ends, release the resource.
- Terminate only an exact disposable process that you own.
- Run independent owned runtimes concurrently. Follow [delivery control](TASKS.md#delivery-control) for shared resources.

A runtime assignment grants no publication, credential access, account changes, spending, permissions or rights.
Separate environment failure from product failure. Change one named environment condition only if it helps
distinguish the cause. A busy host alone proves neither kind of failure.

## Worktrees and setup

A sole driver can edit a clean primary checkout. For concurrent edits or unrelated local work, use an isolated
worktree. The project's worker-setup command prepares the checkout in one step. It is safe to run again:

1. Create the worktree on the branch from the base.
   If the path holds that branch, reuse it.
2. Fetch LFS file content.
3. If the lock changed since the last sync, sync dependencies.
4. Prepare each declared generated or Git-ignored input.
   If no source is newer, reuse the input.
   Otherwise, regenerate it.
5. Delete generated manifests that current sources do not declare.

Before long work and integration, run the freshness check. It changes no files. It names each stale item and its
remedy. It checks base movement, locks, LFS pointers, absent or old inputs and undeclared manifests. Do not copy
ignored files between worktrees by hand. Declare inputs, sources, commands and manifest patterns in the
project's worker-setup configuration. Each worker outcome starts from the base branch and ends as one scoped
commit. If the base moves, run `git rebase <base>`. If a candidate was squashed, run `git rebase --onto <base>
<old candidate tip>`.

## Integration

Check the live OWNER grant and the brief before touching shared main. If either withholds worker landing,
return the frozen candidate and its gate evidence to the CEO. The authorized CEO uses the same procedure
as a delegated worker. If nobody holds the grant, keep the candidate pending. Complete self-review and any
required independent review before landing. Use the adopter's required integration route.

Select checks by changed file. The project declares path groups with their specifications and checks. The
landing tool runs the groups the candidate touches, plus explicit selections. If no group owns a path, use an
explicit selection or the project's full-gate flag. No tool silently runs everything. Use focused checks during
edits. Qualify the combined candidate once for a shared-contract change or release claim. Repeat only for a
relevant change or unresolved failure.

Use the following steps for the authorized operator. For a direct solo integration, the adopter must permit
that route. The optional landing tool requires one commit per candidate branch and a registered worktree.
If the worktree is absent, use `git worktree add <path> <branch>`. Before invoking automatic cleanup,
check [preserved originals](#preserved-originals) for every worktree its callbacks can remove.

1. Acquire exclusive integration control.
2. Confirm the shared base is clean and current. For a direct solo commit, verify its parent against the remote base.
3. Review and freeze the scoped candidate.
4. If the base moved, rebase onto current main.
5. Inspect the final diff.
6. Refresh native proof where the rebase changes behavior or evidence bindings.
7. Run the declared gate on final committed bytes.
8. Integrate through the adopter's route. For a fast-forward, advance main to the verified candidate.
   For a protected branch, wait for the required checks and authorized merge.
9. Push only if the route requires and permits it. Fetch the destination and verify the integrated commit.
10. Close the [landing receipt](#landing-receipt) and release integration control.

A failed tool step reports failing check names, a bounded output tail and the complete log path. Diagnose from
that log before another run.

- Serialize shared main.
- Refuse a failed gate, moved base or candidate, unrelated diff, missing proof or missing authority.
- If candidates conflict, stack them before a combined integration.
  Rebase each onto the previous candidate. Resolve conflicts in its own worktree. Analyze the stacked result.
- If main moves, rebase and recheck affected changes before another attempt.
  After a passed gate, disjoint path changes on main need no gate rerun in the landing tool.
- Source integration requires the assigned native proof. It grants no publication authority.

### Interrupted landing

1. Check the integration holder and live process before taking control. Wait for release by any live holder.
2. Inspect the last log, worktree list, status, train members and candidate refs. Fetch the current remote base.
3. If a rebase stopped, preserve both sides. Finish or abort it in its owning worktree within the brief's rights.
4. Compare the intended commit, local main and fetched remote. If the remote already has the intended result,
   verify its identity and finish the receipt or pending cleanup. Do not repeat the push.
5. If only local main advanced, verify the gated bytes and the unchanged remote base before resuming the authorized push.
   If the remote moved, use the base-movement rule above. If the result is ambiguous, retain the refs and log in STATE.
6. Remove a temporary train only after verifying every member and its originals. Resume at the first unfinished step.

### Preserved originals

Before retiring or reusing a checkout, inspect tracked, untracked and ignored files, stashes and active readers.
Account for each outstanding change as landed, equivalent after squash, superseded or rejected with a reason.
Keep unresolved work with its holder. Identify original captures, source assets, rights records and journals
required by current decisions or retention rules. If an original must move, record its path and digest.
Read back the retained bytes at the destination before removing the source. Keep shared objects and live bindings intact.

Use the adopter's retention policy with the [retention planner](api.md#retention) for eligible records.
Inspect its planned paths before authorizing deletion. Release or transfer each reader first.
Remove only the reviewed worktree and ref. Verify remaining refs, worktrees and retained paths after cleanup.

### Landing receipt

Record the candidate, integrated commit, destination, fetched remote commit, clean status, reviews, gate scope
and original evidence paths. If the adopter squash-merges, bind the accepted candidate to the merged change.
If cleanup fails after verified integration, record the landing as complete and keep cleanup open with its holder.
Close the active STATE entry when all obligations have a verified result or an explicit transfer to a named holder.
Keep the receipt with its evidence. Record any outstanding product acceptance separately.

## Worker hygiene

Run each check batch, test, render or integration as one background command. Use the host's bounded-run
mechanism with a hard deadline. After launch, end the turn. Completion resumes the worker. Use no sleep loops or
turns that only report status. Keep worker files under its worktree or primary checkout. Host tool installation
needs CEO approval. A runner that can disturb shared sessions runs only at a gate the CEO calls. Transfer a lane
only at an outcome boundary under [lane rotation](TASKS.md#lane-rotation).

## Upload route

Under the adopter's upload grant, record each artifact digest, reviewer, verdict and required inspection.
Land the review record before upload. Use [external actions](#external-actions) for the request.
Bind returned identifiers and the receipt to the source history in the adopter's manifest.

## External actions

Before an external action, record authority, operator, source or artifact identity, destination, recovery plan
and acceptance readback. If a required binding is absent, refuse the action. Perform one authorized attempt.
Read the destination back. A warning, rejection or ambiguity holds the affected action. Keep its journal.
Reconcile the original transaction before a decision to retry.

Before the first request, record the write-ahead in the existing operation journal. Record each target's request status, returned identifier and observed outcome.
After interruption, compare the original journal with the destination before any further request.
Keep ambiguous targets open with a holder and the readback that can resolve them.
Close each target only after confirming its disposition. Retain the original response and readback with the receipt.
Keep one current transaction line in STATE:

- Open: `- Write-ahead: publishing <channel> <targets> at <sha> by <command>; one attempt per target.`
- Closed: `- Write-ahead: none. <Channel> <sha> live (<versions and outcome>).`
- No attempt: `- Write-ahead: none. <act> held before any request (<reason>).`

Keep closed transactions and original journals in their evidence packets. Link unresolved consequences from
STATE. Do not copy closed history. Do not run a mutating tool only to learn its behavior. Keep source
identities, rights, notices, original evidence and recovery records needed for current delivery or unresolved
actions. Ask the Owner one reserved decision at a time, with a recommended default. Do not make the Owner the
routine tester.
