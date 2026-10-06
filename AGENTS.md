# FILL: project name

FILL: product, users and complete success outcome.

This is an adoption template. Fill the project values before you use it to govern a product.
To change Execute itself, follow the [Validate](README.md#validate) section of the README.

Keep the machinery that current consumers need. Remove duplication without weakening authority or evidence.
This file owns the repository rules. The [agentic standard](docs/AGENTIC-STANDARD.md) governs conflicts and changed workflows.

## Roles

The Owner holds taste, rights, spending, release and succession.
[TASKS](docs/TASKS.md) defines the accountable CEO and the optional helpers.
The adopter names the holders for reserved acts in [OWNER](docs/OWNER.md).

[Adapters](adapters/README.md) supply native controls. [OWNER](docs/OWNER.md#staffing) owns helper domains, staffing limits and grants.

## Safety rules

- Never create, expose or change credentials or payment data.
- Exact [OWNER](docs/OWNER.md) grants must precede these acts: spending beyond subscriptions, release, user communication, remote destruction, account changes and ownership transfer.
- Verify a running build before publication. Source checks prove no product behavior that nobody observed.
- Use isolated worktrees for concurrent edits, or when the primary checkout has unrelated work. A sole driver may use a clean primary checkout.
- An assignment grants scoped integration unless it withholds it. Freeze the candidate, run the declared gate, land serially on shared main and prove remote equality. Landing grants no release authority.
- Do not kill, restart or reconfigure resources that you do not own. Hand off runtime ownership before another driver acts.
- Publication, credentials and other external acts stay with the holder that OWNER names. A QA surface handoff grants only its stated tools and scope.

## Engineering rules

FILL: project architecture, data and security invariants.

- Add no code comments. Keep compiler directives, shebangs and required license notices.
- Keep the core neutral to the product and to the technology.
- Optional [extensions](extensions/README.md) own domain rules. Adapters own harness controls.
- Keep adopter content, policy, destinations, identities and milestones in the adopting repository. Keep comparisons in research.
- Keep exact technical identifiers.

Execute is prose first. Its auxiliary Luau extension supplies generic landing, scoped check selection, authority, retention and worktree setup.
The host injects git, filesystem, clock and process access.

## Delivery standard

Apply [the standard](docs/AGENTIC-STANDARD.md) to workflows and code review.
The CEO executes and judges the integrated work. TASKS limits independent review.
A gate proves its checks. It does not prove a consumer outcome that nobody observed.

## Operating documents

In an adopting project, start with [TASKS](docs/TASKS.md), [STATE](docs/STATE.md) and the priority queue of the adopter.

- Read [OWNER](docs/OWNER.md) for authority.
- Read [PLAYBOOK](docs/PLAYBOOK.md) for the next procedure.
- Read [SUCCESSION](docs/SUCCESSION.md) only to appoint or replace the CEO.

Keep the current facts aligned.

## Changes to this file

Keep this file short. Add an irreversible-loss rule only for a concrete risk, and replace redundant guidance.
For the final validation of the template, run `lute run tools/gate.luau`. Add `--file <spec>` to run one spec or `--name <text>` to run the cases whose name contains the text. See the [Validate](README.md#validate) section of the README.
