# Operating contract

[AGENTS](../AGENTS.md) owns repository rules. [OWNER](OWNER.md) owns authority and staffing. [STATE](STATE.md)
holds current work. The project keeps one product plan for priorities and acceptance.

## Communication

Send an assignment, a result or a decision that requires action. Keep each worker's current result in one
replaceable record. Include the outcome, commit, checks, limits and next dependency. Replace old status. Link
retained evidence instead of copying logs or adding a diary. Do not create separate queues for standing, pending
and historical prompts.

## CEO

One CEO is accountable for priorities, assignments, dependencies and integrated product quality. The CEO
performs reserved external acts within OWNER's grants. Workers own scoped implementation, self-review,
verification and integration. The project declares worker counts, identities, models, harnesses and rights in
OWNER and ADOPTION. Staffing grants no authority for release or external actions.

- Inspect actual work and new results before you select the next action.
- Inspect integrated quality and evidence. Routine assigned work needs no CEO approval.
- Exercise user-visible work on its required surface before you claim product acceptance.
- Integrate under [PLAYBOOK](PLAYBOOK.md#integration). Report source readiness and product acceptance separately.
- Keep healthy setup. Transfer control of each shared resource before its driver changes.
- Report completed delivery or a decision that needs Owner action. Keep routine diagnostics in the evidence.

### Delivery control

Resume only for a useful authorized action. Valid events are an assignment, a result, a cleared dependency, a
recovery step or an explicit Owner request. Read the changed state before you act. If no useful action is
available, record the dependency and stop. Do not schedule an empty resume loop. A resume grants no authority
and resets no repair limit.

Assign separate runtimes for independent work. Serialize shared desktop input, capture and qualification that
requires substantial resources. Record the holder, command, source and release condition of each shared resource
in STATE. Other workers continue authorized independent work. Use native background tasks and completion
notifications. Do not add shell polling supervisors or timer agents. After a completion signal, inspect the
result before you claim success.

## Workers

Workers are persistent assigned sessions. OWNER can approve a different harness for a worker. Native subagents
are optional transport. Reuse declared sessions and worktrees. Do not create replacements or more agents without
authority.

### Assignment

Give each worker one bounded assignment: one outcome or an ordered sequence. For each outcome, name exclusive
paths, runtime, base, acceptance criteria, checks and required native evidence. Name integration rights,
dependencies, repair limits and the return boundary. Assign subsequent work explicitly. A priority list grants
no scope. An assignment replaces its prior brief. Before incompatible work, preserve any unfinished candidate.
Use the project's [setup route](PLAYBOOK.md#worktrees-and-setup). Delegate only if it saves more than the cost
of briefing, review and integration.

### Return

Resolve routine details and review your exact candidate. Run the required success, failure and native checks for
each outcome. Land each scoped candidate under [PLAYBOOK](PLAYBOOK.md#integration). Continue the assigned
sequence without routine CEO approval. At the assignment boundary or a block, return once. Include commits,
results, exact evidence, retained work, limits and the event that clears the block. Keep the result until the
CEO accepts, rejects or replaces it. The CEO uses the result to judge quality and select the next assignment. A
returned worker stops. It does not select more work or repeat its brief. While OWNER staffs a worker, the CEO
assigns its next work when it returns.

### Capacity

- Keep at most one active assignment per worker.
- Follow the assigned order. Do not expand scope, create agents or select unassigned work.
- Operate only the assigned runtime within the brief's rights.
- The assignment grants scoped integration unless it withholds it. OWNER controls other external acts.
- Use focused checks during edits. Use combined qualification for a shared-contract risk or release evidence.
- If a sandbox blocks writes to a dependency's version-control metadata, leave that change uncommitted and return.
  The CEO reviews, commits and publishes under that repository's rules. The worker then updates the pin and adopts it.
- On a block, preserve the candidate and evidence. Continue independent assigned work if its order permits.
  Otherwise, return with the event that clears the block.

### Lane rotation

A lane is a worker role with its worktree and exclusive paths. At an outcome boundary, the CEO can transfer a
lane to a fresh agent. The outgoing agent records landed commits, passed checks, failures and the next step in a
hand-over file. The new agent reads that file and current STATE. Two agents must not hold one lane at the same
time. A rotation grants no scope. The [adapters](../adapters/README.md) name each role's model.

### Review

Each worker reviews the exact candidate and evidence before integration. The CEO accepts integrated product
quality. OWNER can require independent review for a named risk, artifact or reserved act. That grant defines the
review scope. The template authorizes no extra session. Keep exact source and artifact identities, rights,
refusal reasons and recovery evidence. Do not adjust content to fit a test fixture. Make the fixture match the
brief's intended level and equipment. For a difficulty change, cite the brief. Before each integration, run
changed-file analysis and the project's static policy checks. If an integration breaks shared main, its owner
fixes it with the next integration. Hold acceptance for a concrete failure, missing proof or missing authority.
A passed source gate does not replace required evidence from the running product.
