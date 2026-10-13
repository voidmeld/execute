# Codex adapter

## CEO

Record the top-level task identity and observed model, reasoning, service tier, approval policy and sandbox in STATE.
Mark an unavailable control `not exposed`. Never widen permissions after a denial.

## Workers

Use the persistent worker sessions declared by OWNER under [TASKS](../../docs/TASKS.md#workers).
Give each session AGENTS, its current bounded assignment, worktree and one result location.
Native subagents are optional. Cross-harness sessions use their own declared transport.
Record each session identity, branch, base and current result in the [recovery record](../../docs/STATE.md#recovery).
Do not create a second writer for an app-owned thread or replace a declared session silently.

Continue the assigned ordered sequence through self-review, required native verification and scoped landing without routine CEO approval.
Use only the assigned runtime. Shared desktop input and capture still require exclusive ownership.

## Completion and resume

Run a long check through a native background task and consume its completion notification.
Respect the [shared resource rules](../../docs/TASKS.md#delivery-control).
A completed task releases its shared resource only after its owned processes and surface are reconciled.

Resume for a new assignment, a result, a cleared dependency or an explicit Owner request.
Send only that event and its next useful action; read current state instead of replaying history.
Do not create a scheduled heartbeat or perpetual goal just to keep the CEO or a returned worker active.
If no useful action remains, record the dependency and stop.

The same task resumes from STATE. A changed CEO identity follows [SUCCESSION](../../docs/SUCCESSION.md).
