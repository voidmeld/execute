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

An assignment grants scoped integration unless it withholds it. Complete self-review and any OWNER-required
review before integration. Routine source integration needs no CEO product acceptance.

Select checks by changed file. The project declares path groups with their specifications and checks. The
landing tool runs the groups the candidate touches, plus explicit selections. If no group owns a path, use an
explicit selection or the project's full-gate flag. No tool silently runs everything. Use focused checks during
edits. Qualify the combined candidate once for a shared-contract change or release claim. Repeat only for a
relevant change or unresolved failure.

For direct solo integration:

1. Review and commit the candidate.
2. Run its declared checks on those bytes.
3. Push and verify remote equality.

This route requires no temporary branch or worktree. For a worker branch, follow these steps directly or use the
optional landing tool. The candidate must be one commit on a branch in a worktree. Without that worktree, the
tool refuses before checks. It gives the remedy: `git worktree add <path> <branch>`.

1. Acquire exclusive integration control.
2. Confirm shared main is clean and equal to its remote.
3. Review and freeze the scoped candidate.
4. If the base moved, rebase onto current main.
5. Inspect the final diff.
6. Refresh native proof where the rebase changes behavior or evidence bindings.
7. Run the declared gate on final committed bytes.
8. Fast-forward main.
9. Push and prove exact remote equality.
10. Release integration control.

A failed tool step reports failing check names, a bounded output tail and the complete log path. Diagnose from
that log before another run.

- Serialize shared main.
- Refuse a failed gate, moved base or candidate, unrelated diff, missing proof or missing authority.
- If candidates conflict, stack them before a combined integration.
  Rebase each onto the previous candidate. Resolve conflicts in its own worktree. Analyze the stacked result.
- If main moves, rebase and recheck affected changes before another attempt.
  After a passed gate, disjoint path changes on main need no gate rerun in the landing tool.
- If a push is rejected or ambiguous, reconcile local and remote commits before another attempt.
  Keep unresolved integration in STATE.
- Record the commit, gate result, review, clean status and evidence paths.
- Source integration requires the assigned native proof. It grants no publication authority.
- Remove a worktree only after its commits land, remaining work is preserved or disposed, and no live task owns it.

## Worker hygiene

Run each check batch, test, render or integration as one background command. Use the host's bounded-run
mechanism with a hard deadline. After launch, end the turn. Completion resumes the worker. Use no sleep loops or
turns that only report status. Keep worker files under its worktree or primary checkout. Host tool installation
needs CEO approval. A runner that can disturb shared sessions runs only at a gate the CEO calls. Transfer a lane
only at an outcome boundary under [lane rotation](TASKS.md#lane-rotation).

## Upload route

Beside each file to upload, the CEO records its digest, reviewer, verdict and personal inspection. Land that
record before upload. The CEO runs the project's upload command from the primary checkout at main equal to its
remote. The receipt contains the resulting IDs. The worker records them in the manifest with receipt paths,
content hash and source history.

## External actions

Before an external action, record authority, operator, source or artifact identity, destination, recovery plan
and acceptance readback. If a required binding is absent, refuse the action. Perform one authorized attempt.
Read the destination back. A warning, rejection or ambiguity holds the affected action. Keep its journal.
Reconcile the original transaction before a decision to retry.

Before the first request, record the write-ahead in the existing operation journal. Close it after readback.
Keep one current transaction line in STATE:

- Open: `- Write-ahead: publishing <channel> <targets> at <sha> by <command>; one attempt per target.`
- Closed: `- Write-ahead: none. <Channel> <sha> live (<versions and outcome>).`
- No attempt: `- Write-ahead: none. <act> held before any request (<reason>).`

Keep closed transactions and original journals in their evidence packets. Link unresolved consequences from
STATE. Do not copy closed history. Do not run a mutating tool only to learn its behavior. Keep source
identities, rights, notices, original evidence and recovery records needed for current delivery or unresolved
actions. Ask the Owner one reserved decision at a time, with a recommended default. Do not make the Owner the
routine tester.
