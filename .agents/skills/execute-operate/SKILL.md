---
name: execute-operate
description: Use when the CEO or a helper is assigned an outcome to implement, verify and land. Covers worktree setup, focused checks, helper return, landing through the gate, authorized publication, and the evidence handoff.
---

# Product delivery

## Trigger

The CEO holds an outcome, or a helper holds an assignment from the CEO.
A helper stops at its return. The CEO integrates.

## Inputs

- The exact assignment: outcome, falsifier, scope, owned paths, base, surfaces and stop boundary.
- [AGENTS](../../../AGENTS.md) for authority and the [operating contract](../../../docs/TASKS.md#ceo) for the roles.
- [STATE](../../../docs/STATE.md) for current facts, the recovery record and surface ownership. [OWNER](../../../docs/OWNER.md) for grants.
- The [harness adapter](../../../adapters/README.md) for native task controls.

## Actions

1. Prepare or reuse an isolated worktree on a named branch from the base. Use the adopter's worker-setup. Read the [PLAYBOOK](../../../docs/PLAYBOOK.md#worktrees-and-setup) procedure.
2. Diagnose the observed failure at its causal boundary. Implement the bounded outcome. Run focused checks.
3. Helper: commit one commit. Return the branch, commit, checks and limits.
4. CEO: consume returns and refill bounded work under [TASKS](../../../docs/TASKS.md#helpers) before long serial QA.
5. CEO: review and freeze the candidate. Use the declared integration procedure. Let its tool run the final gate once and prove remote equality. If integration is withheld, return the gated candidate.
6. Verify each user-visible or runtime claim on the assigned surface against the exact candidate. Do it before or after source integration, as the assignment requires. A claim without proof remains open.
7. Publish only where [OWNER](../../../docs/OWNER.md) grants it, after the required running-build proof. Use the [external transaction](../../../docs/PLAYBOOK.md#external-actions). Then verify the published result as PLAYBOOK requires.

## Verification

- The gate passes on frozen committed bytes.
- The landing proves remote equality.
- Every external action has a closed write-ahead and a readback.

## Recovery

A failed check holds its own claim, not unrelated work.
Before you rerun, read the failing names and the log path in the refusal.
Diagnose a tooling refusal within the assigned repair budget. Return at the boundary. Continue ready independent work.
Never retry an ambiguous or attempted external action. Reconcile its journal first.

## Exit

In quiet mode, return the outcome, the frozen commit, the checks, the original evidence, the limits and the next action.
Update the [recovery record](../../../docs/STATE.md#recovery).
Keep assigned surfaces between outcomes. When ownership changes, stop input and hand the surfaces back.
Report source readiness separately from product acceptance.
