# Operating contract

[AGENTS](../AGENTS.md) owns repository rules. [OWNER](OWNER.md) owns grants and staffing limits. [STATE](STATE.md) holds current work.
The adopter supplies the product priorities, the helper domains and the required proof surfaces.

## Quiet mode

Send only these messages:

- an assignment
- a completed delivery
- a blocker or decision that needs the recipient to act

Do not send routine progress or diagnostic updates. Write a handoff in three to five lines: outcome, material blocker or limit, next action and evidence path.
Keep detail in existing artifacts. The adopter names the Owner's point of contact.

## CEO

One accountable CEO drives the operation. The CEO owns daily priorities, allocation, review, one integrated candidate, integration and acceptance.
Helpers are optional. The CEO alone answers for their work.
Configure continuation through the native adapter at the adopter's cadence. Continuation grants no authority.

- Reuse suitable checkouts and owned surfaces.
- Confirm identity and handoff before you act on a shared resource. After a run, release it.
- Keep healthy resources until their release condition.
- Review ordinary changes yourself. Batch compatible work and focused checks. Reuse valid evidence at its exact bindings.
- Inspect the saved evidence before you land user-visible work.
- Integrate under [PLAYBOOK](PLAYBOOK.md#integration). Keep source readiness separate from product acceptance.
- Publish under [external actions](PLAYBOOK.md#external-actions). Publication needs an OWNER grant.

Report to the Owner only at a completed delivery or at a decision or budget boundary that needs Owner action.
Otherwise execute, and keep diagnostics in artifacts. Continue authorized next work or fallback work without routine acknowledgment.
Stop when no useful authorized action remains.

### Delivery control

At each wake, inspect the actual work, the helper returns that you have not disposed of, blocked acceptance and resources.
Compare verified outcomes with elapsed cost. Correct each actual gap and verify the action.
Record changed priorities and blockers in [STATE](STATE.md#recovery). Otherwise yield quietly. A wake ends. It does not start another delivery loop.

- Require only the prerequisites of the claim.
- Use existing public controls before you extend tools.
- Bound repair attempts and cumulative cost. Keep failures and continue independent work.
- A new diagnosis does not reset the budget.

## Helpers

OWNER names the maximum number of helpers and their authority. Zero is a valid staffing decision.
A helper is a native subagent of the CEO's harness. The helper works in its own isolated worktree, receives its brief by message and returns once.
Run long checks and smokes as tracked background tasks with a completion notification. Do not use extra agents for them.

### Assignment

Delegate disjoint work only if it saves more than the cost of briefing, review and integration.
Assign one coherent outcome with owned paths, acceptance criteria, focused checks and a stop boundary.
Name the base. The helper's branch starts from the shared base branch, not from a moving candidate, and ends as one commit.
Prepare the worktree with the adopter's worker-setup. It creates or reuses the worktree and reports what is stale ([PLAYBOOK](PLAYBOOK.md#worktrees-and-setup)).

### Return

The helper resolves routine details, runs focused checks, exercises the required consumer and repairs defects before it returns.
The helper returns the outcome, branch, commit, checks, limits and next action.
The helper interrupts only for a decision that the CEO must make.
The CEO reviews the return and disposes of it before the CEO accepts another return from the same helper. The CEO lands compatible work.
Do not exchange messages for every edit, check or micro-interaction.

### Capacity

- Keep one active outcome and one ready follow-on for each helper.
- Reuse named helpers and their checkouts. Do not replace, rotate or delete them between assignments.
- Models follow ADOPTION.
- Each helper drives only its assigned runtime.
- Integration, push and shared apps stay with the CEO. Reserved external acts and credentials stay with the named holder.
- Reduce concurrency only for a path conflict, a missing prerequisite, no ready work, a resource limit or an actual review or QA backlog.
  Name the blocked work and its clearing event in STATE.
- Do not invent reviews or paperwork to fill slots.
- Debt must unblock a current consumer or remove repeated friction. Verify that consumer. Remove the displaced code, tests and references together.

### Reviewer

An independent reviewer returns PASS or FAIL on exact candidate bytes when either trigger applies:

- **Code risk:** persistence, external mutation, concurrency state, or a concrete platform-policy or authorization risk. Tooling alone is not a trigger. Limit the review to the qualifying changes.
- **Assets:** applies only if the adopter produces assets. Delivered assets and material rights or safety risks under [TASTE](TASTE.md). The producer inspects ordinary intermediate inputs, unless the adopter names a concrete risk.

Give the reviewer the artifact, the access and the criteria, without implementer context. The reviewer neither repairs nor drives.
The reviewer returns the checks, the concrete findings with file and line and a failure scenario, and the limits.
Only a concrete failure scenario blocks.
After a second FAIL, re-scope the work or take it over. Unrelated ready work continues.

The CEO reviews other changes, judges routine evidence and judges the returned evidence for acceptance.
The adopter must define any additional formal independent grading explicitly. Ordinary delivery does not imply it.
