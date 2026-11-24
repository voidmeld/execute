# Harness adapters

Adapters connect Execute's operating rules to native harness controls. They grant no authority and define no
staffing. [TASKS](../docs/TASKS.md) owns assignments and results. OWNER chooses sessions. ADOPTION records
harnesses and models.

- [Codex](codex/README.md): task controls.
- [Claude](claude/README.md): session controls.

## Shared procedure

1. Record observed identity and settings in STATE.
2. Mark unavailable controls `not exposed`.
3. Use native message, resume and completion controls for declared sessions.
4. Continue the assigned sequence through self-review, native verification and scoped integration.
5. Use only the assigned runtime.
6. Follow [delivery control](../docs/TASKS.md#delivery-control) for shared input, capture and other shared resources.
7. Run long commands as native background tasks.
8. After completion, inspect results and reconcile owned processes before resource release.

A denial holds the action. Do not widen permissions to bypass it. Resume only for the useful events that TASKS
defines. Do not install heartbeats, timers, prompt replay or polling supervisors for idle sessions. If a
required completion control is unavailable, record the limit and stop at the dependency. If no useful action
remains, record the dependency and stop. A restarted session reads current STATE. A changed CEO follows
[SUCCESSION](../docs/SUCCESSION.md). Keep healthy setup and retained work. Change staffing only as OWNER
directs. Do not permit overlapping drivers on a shared surface. A worker on another harness uses its declared
native transport and the same assignment and result contract.
