# Harness adapters

Adapters map Execute's operating contract to available controls. They do not grant authority or define staffing.
[TASKS](../docs/TASKS.md) owns assignments and results. OWNER chooses the sessions; ADOPTION records the harness and model routes.

- [Codex](codex/README.md): tasks and background completion.
- [Claude](claude/README.md): sessions and background completion.

## Shared procedure

Record observed identity and settings in STATE. Mark unavailable controls `not exposed`.
Use the harness's message, resume and completion controls for the declared sessions.
Resume only with the useful event and bounded assignment that TASKS requires.
Do not install a heartbeat, timer command, prompt watcher or polling supervisor to keep an idle session awake.
If a required completion control is unavailable, record that limit and stop at the dependency.

A cross-harness worker uses its declared native transport and the same assignment and result contract.
A full transfer follows [SUCCESSION](../docs/SUCCESSION.md). Keep healthy setup and preserved work;
replace or retain sessions only as OWNER directs. Never overlap drivers on a shared surface.
