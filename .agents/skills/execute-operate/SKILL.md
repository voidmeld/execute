---
name: execute-operate
description: Use when the CEO or a worker is assigned an outcome to implement, verify and land. Covers worktree setup, focused checks, worker return, landing through the gate, authorized publication, and the evidence handoff.
---

# Product delivery

## Trigger

The CEO holds an outcome, or a worker holds an assignment from the CEO.
A worker self-reviews, verifies and lands its assigned outcomes. The CEO accepts integrated product quality.

## Inputs

- The exact assignment: ordered outcomes, falsifiers, exclusive paths and runtime, base, required proof, integration rights and return boundary.
- [AGENTS](../../../AGENTS.md) for authority and the [operating contract](../../../docs/TASKS.md#ceo) for the roles.
- [STATE](../../../docs/STATE.md) for current facts, the recovery record and surface ownership. [OWNER](../../../docs/OWNER.md) for grants.
- The [harness adapter](../../../adapters/README.md) for native task controls.

## Actions

1. Prepare or reuse an isolated worktree on a named branch from the base. Use the adopter's worker-setup. Read the [PLAYBOOK](../../../docs/PLAYBOOK.md#worktrees-and-setup) procedure.
2. Diagnose the observed failure at its causal boundary. Implement the bounded outcome. Run focused checks.
3. Verify each user-visible or runtime claim on the assigned native surface against the exact candidate. Inspect original evidence before landing.
4. Self-review and complete any OWNER-required review. Commit the scoped candidate. Follow [integration](../../../docs/PLAYBOOK.md#integration) for final proof, the gate, serial landing and exact remote equality. If integration is withheld, return the gated candidate.
5. Continue explicitly assigned follow-on outcomes under [TASKS](../../../docs/TASKS.md#workers). Respect shared resources without serializing independent runtimes. Return at the assignment boundary or a genuine block.
6. CEO: inspect the integrated product and returned evidence. Remove dependencies and choose the next assignment.
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

Return once with the outcomes, commits, checks, original evidence, retained work, limits and the next dependency.
Update the [recovery record](../../../docs/STATE.md#recovery).
Replace the worker's current result instead of appending a history. Stop until a useful new assignment or dependency event arrives.
Keep assigned surfaces between outcomes. When ownership changes, stop input and hand the surfaces back.
Report source readiness separately from product acceptance.
