# Claude Code adapter

## CEO

The CEO is one top-level Claude Code session. Record its model, permission mode and appointment commit in STATE.
Before appointment, check the project settings and the user overlay. A denial holds the action. Do not widen permissions to bypass it.

## Helpers

Helpers are native Agents. The CEO session starts them, each in an isolated worktree, and resumes them with SendMessage.

- Give each helper [the task contract](../../docs/TASKS.md), AGENTS and its exact assignment.
- Give a blind reviewer only the inputs that [TASKS](../../docs/TASKS.md#reviewer) defines.
- Record the identity, the model and effort route, the worktree, the base and the returned HEAD in the [recovery record](../../docs/STATE.md#recovery).
- A helper cannot own `/loop`. The CEO wakes and resumes the helper.
- Display-scope computer use can be available only to the top-level session. Helpers use host APIs instead.
- Track long checks with background tasks. Read their completion notifications.

## Continuation

1. At appointment, run `/loop Operate as CEO indefinitely` in the CEO's own supported session.
2. Read the actual schedule back into STATE.
3. Use the available controls to pace wakeups to actionable events. Record fixed-schedule limits.
4. If a scheduled wakeup does not fire while the session stays busy, keep a background timer command as the heartbeat. Its completion always wakes the CEO.
5. Read back the first wake before you rely on it.

A restarted session re-arms continuation and follows STATE.
A change of CEO identity follows [SUCCESSION](../../docs/SUCCESSION.md).
A cross-harness assignment runs through the destination CLI under the same task limits.
