---
name: execute-operate
description: Use when the CEO or a worker is assigned an outcome to implement and verify. Covers worktree setup, focused checks, worker return, landing through the gate, authorized publication, and the evidence handoff.
---

# Product delivery

## Trigger

The CEO holds an outcome, or a worker holds an assignment from the CEO.
A worker self-reviews and verifies its assigned outcomes. The CEO accepts integrated product quality.

## Inputs

- The adopter's current [assignment](../../../docs/TASKS.md#assignment).
- Read `AGENTS.md` at the root of the adopter's assigned worktree. Follow the files it names for OWNER grants, current STATE and command bindings. Resolve those paths from the adopter's worktree.
- Package copies of `docs/OWNER.md`, `docs/STATE.md` and `AGENTS.template.md` are templates. They never supply live authority or state.
- The [harness adapter](../../../adapters/README.md) for native task controls.

## Actions

1. Prepare or reuse an isolated worktree on a named branch from the base. Use the adopter's worker-setup. Read the [PLAYBOOK](../../../docs/PLAYBOOK.md#worktrees-and-setup) procedure.
2. Diagnose the observed failure at its causal boundary. Implement the bounded outcome. Run focused checks.
3. Verify each user-visible or runtime claim on the assigned native surface against the exact candidate. Inspect original evidence before landing.
4. Self-review and commit the scoped candidate. Run its declared gate. Follow [integration](../../../docs/PLAYBOOK.md#integration) for the grant decision, landing and receipt.
5. Continue the assigned sequence. At its boundary or a block, use the [worker return](../../../docs/TASKS.md#return).
6. As CEO, inspect integrated quality and returned evidence before selecting the next assignment.
7. For authorized publication, follow [external actions](../../../docs/PLAYBOOK.md#external-actions) after the required running-build proof.

## Recovery

Read the failing check names and log before repair. Continue independent assigned work within the brief.
For an interrupted integration, use [interrupted landing](../../../docs/PLAYBOOK.md#interrupted-landing).
When the driver changes, use the [custody transfer](../../../docs/SUCCESSION.md#setup-handoff).
