# Playbook

This page owns the procedures for iteration, worktree setup, evidence, runtime handoff, integration and external actions.
[TASKS](TASKS.md) owns roles and assignments. The adopter supplies the exact commands, destinations and required proof.

## Daily iteration

Document one short path from an authored change to its real consumer: edit, run focused checks, exercise the changed behavior, inspect the result and repair.
Link integration and publication only where needed.

Keep first-time setup and failure recovery apart from this path. An ordinary edit must not:

- reinstall dependencies
- rebuild unrelated artifacts
- reopen healthy applications
- repeat valid calibration

Refresh only the changed source bindings. Invalidate evidence only where its inputs changed.

Use existing tools before you add a wrapper.

- An open or setup command reuses the exact healthy resource when possible. It refuses ambiguous matches.
- Before you replace a tool, measure setup, synchronization, runtime startup and verification separately.
- Keep the current working route until the replacement completes a real task and its relevant failure and recovery path.

Keep commands and recovery instructions in their owning runbook, and link them from current state.
A successor must be able to run them without chat history.
When you discover a workflow repair, put it in that runbook. Do not put it in a second checklist or a private handoff note.

## Evidence

Use the cheapest check that can disprove the claim.

Climb this ladder. Evidence from a lower step never proves a claim of a higher step.

1. **Static checks:** source, types, contracts and deterministic builds.
2. **Automated tests:** the behavior that the tests exercise.
3. **Product-level acceptance:** FILL: the exact candidate runs in its real host and its observed behavior is recorded.
4. **Owner acceptance:** the Owner judges the result against [TASTE](TASTE.md).

A destination readback proves what arrived. A fake is a diagnostic model. Require it to refuse what the real host refuses.
Never use a fake to close a host claim that nobody observed.

For a claim about the running product, the assigned helper or the CEO runs the exact candidate in the required host. Record:

- the product commit and artifact
- the host and the destination version
- the relevant configuration and dependencies
- the observed output
- the receipt path
- FILL: other items that the product requires

Bind the evidence to the product commit that ran, not to a later receipt commit.
Helpers execute checks and repair their assigned outcomes. The CEO evaluates the returned evidence against the fixed criteria.
If the declared material or asset risk requires independent review, use the [Reviewer contract](TASKS.md#reviewer).
State the coverage and the limits. A passing gate does not prove the whole product.
Turn each defect that the Owner finds into a regression at the boundary that can detect it.
Do not present a build until its required acceptance checks pass.

A product that a person operates through an interface adds the [interactive QA extension](../extensions/interactive-qa/README.md).

## Runtime ownership

Give each runtime one driver.

- Reuse standing authority and healthy owned surfaces.
- In STATE, keep only what recovery needs: the exact instance or PID, the document or build, the driver and the release condition.
- Add special restrictions when they apply. Do not repeat unchanged grants for each run.
- Hand off control before another driver acts.
- When the run ends, release the resource.
- Terminate only an exact owned disposable process.
- If measured capacity permits, run independent surfaces in parallel.

A runtime assignment grants no credentials, publication, spending or permission changes.

Treat an environment failure separately from a product failure.
Change one named environmental condition only when the change distinguishes the cause.
A busy host alone proves neither an environment failure nor a product failure.

## Worktrees and setup

A sole driver may edit a clean primary checkout. Use an isolated worktree for concurrent edits or unrelated local work.
The adopter's worker-setup command does the whole preparation in one step. It is safe to run again:

1. Create the worktree on the branch from the base. If the path already holds that branch, reuse it.
2. Hydrate LFS pointer files.
3. If the lock changed since the last sync, sync dependencies.
4. Materialize each declared generated or git-ignored input. Reuse it while no source is newer. Otherwise copy it from a reference checkout whose sources are byte-identical. Otherwise regenerate it.
5. Delete generated manifests that the current sources do not declare.

Run its freshness check before long work and before landing. The check changes nothing.
It names each stale item with its fix: base branch moved, lock changed, LFS pointer, missing or older-than-source input, or undeclared manifest.
Never copy ignored files between worktrees by hand.
The adopter declares the inputs, sources, commands and manifest patterns in its own worker-setup configuration.

A helper's branch starts from the base branch, not from a moving candidate, and ends as one commit.

- If the base moves, run `git rebase <base>`.
- If a candidate was squashed, run `git rebase --onto <base> <old candidate tip>`.

## Integration

The outcome assignment grants the CEO scoped integration unless it explicitly withholds it.

Select checks by changed file. The adopter declares groups of path patterns with their specs and checks.
The landing tool runs only the groups that the candidate touches, plus any explicit selection.
If no group owns a path, use an explicit selection or the adopter's full-gate flag. No tool silently runs everything.

For direct solo integration:

1. Review and commit the candidate.
2. Run its declared checks on those bytes.
3. Push and verify remote equality.

No temporary branch or worktree is required.

For a helper branch, use the optional landing tool. Land a candidate that is a single commit on a branch checked out in a worktree.
Without that worktree, the landing tool refuses before it runs any check. The refusal names the `git worktree add <path> <branch>` remedy.

1. Review and freeze the combined candidate.
2. The tool rebases it and runs the declared gate once on the final committed bytes.
3. The tool fast-forwards, pushes and proves remote equality.

A failing step refuses with the failing check names, a bounded output tail and the path of the complete log.
Diagnose from that log, not from a second run.

- Serialize shared main.
- Refuse a failed gate, a moved base or candidate, an unrelated diff or missing authority.
- Record the commit, the gate result, the review, the clean status and the evidence paths.
- Source landing needs no product acceptance and does not authorize publication.
- Retire the worktree only after its commits land, its remaining work is preserved or disposed, and no live task owns it.

## External actions

Before an external action, record these items:

- the exact authority and the operator
- the source or artifact identity
- the destination
- the rollback or recovery plan
- the acceptance readback

If any required binding is absent, refuse. Perform one authorized attempt and read the destination back.
A warning, a rejection or an ambiguity holds the affected action. Keep its journal.
Reconcile its original transaction before you decide whether a retry is authorized.

Record the write-ahead in the existing operation journal before the first request. Close it after the readback.
Keep the active transaction discoverable from STATE:

- open: `- Write-ahead: publishing <channel> <targets> at <sha> by <command>; one attempt per target.`
- close: `- Write-ahead: none. <Channel> <sha> live (<versions and outcome>).`, or
  `- Write-ahead: none. <act> held before any request (<reason>).` when nothing was attempted.

Keep one current transaction line in STATE. Keep closed transactions and original journals in their evidence packets.
Link unresolved consequences from STATE. Do not copy the closed history.

Never run a mutating tool only to learn what it does.
Keep the source identities, rights and notices, original evidence and recovery records that you need to verify the current delivery and to reconcile unresolved actions.

Ask the Owner one reserved decision at a time, with a recommended default. Do not make the Owner the routine tester.
