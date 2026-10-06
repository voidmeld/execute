# Codex adapter

## CEO

The CEO is one top-level Codex task. At appointment, record its identity in STATE.
Also record the observed model, reasoning, service tier, approval policy, sandbox and overlays.
Mark each unavailable control `not exposed`. Never infer settings. Never widen permissions after a denial.

## Helpers

Helpers are native subagents with isolated editing worktrees under [TASKS](../../docs/TASKS.md#helpers). Reuse them across assignments.

- Give each helper AGENTS and its exact assignment.
- Give a reviewer only the inputs in the [Reviewer contract](../../docs/TASKS.md#reviewer).
- Record the identity, the worktree, the base and the returned HEAD in the [recovery record](../../docs/STATE.md#recovery).
- Follow TASKS for model routing and quiet communication.
- Address helpers by task path.
- If helpers are app threads on the shared local daemon, use the available app messaging and completion tools. Otherwise use `codex queue --thread <name>` and its `task_complete` return.
- Never run `codex exec resume` on an app thread, because the app holds its writer.
- Threads rely on automatic compaction.

## Continuation

1. At appointment, create a heartbeat on the CEO's thread. Its prompt is `Operate as CEO indefinitely`. Read it back.
2. Keep the current Owner continuation conditions in STATE. Apply them at each wake.
3. Use the heartbeat. Do not use a native goal.
4. If the controls permit, schedule the next actionable event. Otherwise use the Owner's cadence, or 30 minutes if the Owner specifies none. Record the cadence.
5. At each invocation, apply [delivery control](../../docs/TASKS.md#delivery-control) once. Act on the completion events that arrive.

Do not imply instantaneous wakeups if the harness has not demonstrated them.
The heartbeat grants no release authority. It cannot wake a stopped app.

The same task resumes from STATE. A changed CEO identity follows [SUCCESSION](../../docs/SUCCESSION.md).
Cross-harness work follows the [shared adapter contract](../README.md).
