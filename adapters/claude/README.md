# Claude adapter

## CEO

Record the top-level session identity, observed model, permissions and appointment in STATE.
Check the active settings and user overlay. A denial holds the action; do not widen permissions to bypass it.

## Helpers

Use OWNER's declared persistent sessions under [TASKS](../../docs/TASKS.md#helpers).
Native Agents and approved cross-harness sessions follow the same bounded assignment contract.
Give each helper AGENTS, its worktree and one replaceable result location.
Record observed identities and the current assignment in [STATE](../../docs/STATE.md#recovery).
Display-scope tools may be limited to the CEO. That limitation does not grant another session access.

## Completion and resume

Use native background tasks and their completion notifications for long commands.
Respect the [shared heavy/native slot](../../docs/TASKS.md#delivery-control).
Inspect the actual result and reconcile owned processes before releasing the slot.

Resume a session only with a new useful assignment, a result, a cleared dependency or an explicit Owner request.
Do not install `/loop`, a timer command, a standing prompt replay or a polling supervisor for an idle session.
If no useful action remains, record the dependency and stop.

A restarted session reads current STATE. A changed CEO follows [SUCCESSION](../../docs/SUCCESSION.md).
