# Codex adapter

Follow the [shared procedure](../README.md#shared-procedure).

## CEO

Record the task identity, observed model, reasoning, service tier, approval policy and sandbox in STATE.

## Workers

Use the persistent sessions that OWNER declares under [TASKS](../../docs/TASKS.md#workers). Give each session
AGENTS, its bounded assignment, worktree and one result location. Native subagents are optional. Sessions on
another harness use their declared transport. Record identity, branch, base and current result in
[STATE](../../docs/STATE.md#recovery). Do not create a second writer for an app-owned thread. Do not replace a
declared session without notice. For a lane rotation, start a fresh session that reads the hand-over file.
Record its observed settings as above. OWNER's staffing names the model for each role.

## Completion and resume

Use native background tasks and completion notifications. Send only the event and next useful action when a
session resumes. Read current state instead of repeating history. Do not create a perpetual goal to keep an idle
CEO or returned worker active.
