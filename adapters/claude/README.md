# Claude adapter

Follow the [shared procedure](../README.md#shared-procedure).

## CEO

Record the top-level session identity, observed model, permissions and appointment in STATE. Check active
settings and the user overlay.

## Workers

Use the persistent sessions that OWNER declares under [TASKS](../../docs/TASKS.md#workers). Native Agents and
approved sessions on another harness follow the same bounded assignment contract. Give each worker AGENTS, its
worktree and one replaceable result location. Record observed identities and assignments in
[STATE](../../docs/STATE.md#recovery). Run the CEO on `claude-fable-5-1` and workers on `claude-sonnet-5-5` with
bypass permissions. Use `claude-opus-5-5` for one blocked outcome at a time. For a lane rotation, start a fresh
native agent that reads the hand-over file. Before work starts, verify its observed model and permissions.
Display tools can be limited to the CEO. That limit grants no access to another session.

## Completion and resume

Use native background tasks and completion notifications. Do not install `/loop` to keep an idle session active.
