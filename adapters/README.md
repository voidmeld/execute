# Harness adapters

Adapters map the operating contract of Execute to native agent controls.
They do not redefine roles, permissions or review requirements.
[TASKS](../docs/TASKS.md) owns those decisions. STATE records live identities and assignments. ADOPTION records model and harness choices.

- [Codex](codex/README.md): tasks, native subagents and continuation.
- [Claude Code](claude/README.md): sessions, native Agents and continuation.

## Shared procedure

- Record the observed identity, route and settings in STATE. Mark each unavailable control `not exposed`.
- Use native completion notifications or bounded waits. Do not build a manager daemon, a polling loop or a parallel task system.
- At appointment, arm and read back continuation as the selected adapter requires.
- At each wake, perform [delivery control](../docs/TASKS.md#delivery-control) once. Reload only the changed state, act on new results or decisions, then yield quietly.
- A continuation control grants no authority.

A bounded assignment to another harness uses the CLI of that harness under the same task limits.
A full transfer follows [SUCCESSION](../docs/SUCCESSION.md). Keep setup and work. Replace the outgoing drivers unless the Owner explicitly retains them.

## Agent graph

The default relationship in the template is:

```text
Owner → CEO → optional helpers
         └→ independent Reviewer when required
```

[TASKS](../docs/TASKS.md) owns the work, QA, integration and review boundaries of each role.
The adopter may specialize this structure. A template graph never authorizes extra agents.

[TASKS](../docs/TASKS.md#helpers) owns helper assignments, reuse and returns.
ADOPTION owns model routes. STATE records observed identities and [background tasks](../docs/STATE.md#recovery).
