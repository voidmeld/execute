# Execute

Execute is an agentic orchestration template. You adopt its documents to define who owns work, what agents may do,
how they verify and integrate results, and how work continues across sessions.
The agent harness supplies execution and communication. Execute adds no manager daemon and no task system.

Execute is a set of documents with optional Luau modules.

## Terms

- **Adopter:** the project that adopts the template.
- **Owner:** the human who holds authority.
- **CEO:** the one accountable agent. It leads the work.
- **Helper:** a native subagent of the CEO.
- **Reviewer:** an independent agent that judges exact candidate bytes when [TASKS](docs/TASKS.md#reviewer) requires it.
- **Appointment:** the Owner's act that names the CEO. [SUCCESSION](docs/SUCCESSION.md) owns it.
- **Gate:** the command that checks a change.

## Use cases

- Name a human Owner and one accountable CEO, with optional helpers and exact grants.
- Set the safety rules, the required proof and the destinations for a project.
- Run work in isolated worktrees, with a gate, serial integration and recorded evidence.
- Keep current work, identities and the next action in one state document so a new session can resume.
- Map the operating contract to a harness (Codex or Claude Code) with an adapter.
- Add domain rules with an extension: interactive QA, Roblox operating rules, or Luau modules for landing, check selection, authority, retention and worktree setup.

The template defines a human Owner and one accountable CEO. [TASKS](docs/TASKS.md#helpers) defines the optional helpers and the reviewer.
The adopter appoints agents and grants authority in [OWNER](docs/OWNER.md). Copying the template grants neither.

## Getting started

1. Install the pinned tools: `rokit install`. Generate the Lute typings: `lute setup`.
2. Copy the core documents, one [harness adapter](adapters/README.md) and only the [extensions](extensions/README.md) the product needs. Replace this README with the product README.
3. Fill the placeholders in AGENTS, STATE, OWNER, TASTE and ADOPTION. Declare the product purpose, the CEO, the helper limit, the commands, the destinations, the required proof and the exact grants. Keep technical architecture beside its implementation.
4. Record the exact Execute commit and tree, the selected files and the intentional differences in [ADOPTION](docs/ADOPTION.md). Adopt upstream updates deliberately and validate them in the consumer.
5. For an Owner-authorized appointment, follow [SUCCESSION](docs/SUCCESSION.md). An existing operation resumes from STATE without another appointment.

To use an optional Luau module, require it and pass the data it needs. This is the complete file
[examples/scoped-checks.luau](examples/scoped-checks.luau). It selects the checks that own the changed paths:

```luau
--!strict

local ScopedChecks = require("../extensions/luau/scoped-checks")

local groups: { ScopedChecks.Group } = {
	{
		name = "docs",
		paths = { "^docs/", "%.md$" },
		specs = {},
		checks = { { "tools/gate.luau" } },
	},
	{
		name = "tools",
		paths = { "^tools/" },
		specs = { "^tools/.*%.spec%.luau$" },
		checks = { { "tools/check-no-any.luau" } },
	},
}

local changed = { "tools/check-comments.luau", "docs/STATE.md", "notes.txt" }
local candidates = { "tools/check-comments.spec.luau", "tools/other.spec.luau" }

local selection = ScopedChecks.select(changed, groups, candidates, nil)
for _, group in selection.groups do
	print("group:", group.name)
end
for _, spec in selection.specs do
	print("spec:", spec)
end
for _, check in selection.checks do
	print("check:", table.concat(check, " "))
end
for _, path in ScopedChecks.unowned(changed, groups) do
	print("unowned:", path)
end
```

Run it with `lute run examples/scoped-checks.luau`. The command prints the touched groups, the selected specs and checks, and the unowned paths.

## Documentation

| Document | Owns |
| --- | --- |
| [AGENTS](AGENTS.md) | Repository rules and authority boundaries. It also owns the adopter startup route. |
| [OWNER](docs/OWNER.md) | Current grants, directions and reserved decisions. |
| [TASKS](docs/TASKS.md) | CEO, helpers, review and communication. |
| [STATE](docs/STATE.md) | Current work, recovery record, identities, resources and next action. |
| [PLAYBOOK](docs/PLAYBOOK.md) | Iteration, worktrees, evidence, integration and external-action procedures. |
| [TASTE](docs/TASTE.md) | Product quality criteria. |
| [ADOPTION](docs/ADOPTION.md) | The upstream relationship and the intentional differences. |
| [SUCCESSION](docs/SUCCESSION.md) | Appointment and replacement. |
| [Agentic standard](docs/AGENTIC-STANDARD.md) | Documentation, workflow and code-review practice. |
| [Adapters](adapters/README.md) | Native harness controls. |
| [Extensions](extensions/README.md) | The [Luau extension](extensions/luau/README.md) (injected tooling primitives), the [interactive QA extension](extensions/interactive-qa/README.md) (evidence rules for operated products) and the [Roblox extension](extensions/roblox/README.md) (platform operating rules). None contains a product identity, credentials or destinations. |

## Validate

To change Execute itself, read this section and [the agentic standard](docs/AGENTIC-STANDARD.md).
The role, staffing and authority placeholders govern adopting projects after appointment.
Keep reusable rules in Execute and product decisions in the adopter. Update each owning document and its callers together.

Run `lute run tools/gate.luau` on final bytes. It is one declared [Verify](https://github.com/voidmeld/verify) gate. It checks these items:

- the license and the Markdown links and anchors
- source comments, formatting and lint
- strict types across all Luau tools, examples and extension specifications
- the executable extension contracts

The specs use the Verify testing library. An adopter who copies a module does not need it.
The gate pins Verify in `dependencies.lock.luau` and materializes it into the ignored `.lute/dependencies` directory. Set `VERIFY_SOURCE` to a local Verify checkout to avoid the network.

Run one spec with `lute run tools/gate.luau --file extensions/luau/landing.spec.luau`.
Run the cases whose name contains a text with `--name text`.
Other options are `--only producer`, `--case id`, `--rerun`, `--explain id` and `--list`. A narrowed run is not the gate.

Analysis uses the exported types of the installed SDK. The gate ignores diagnostics in the SDK's own implementation outside the repository.
The gate does not verify an adopter's product behavior.

Every maintained Luau file must start with `--!strict`. The gate parses types and compiler directives.
Explicit `any`, `--!nonstrict` and `--!nocheck` fail. Use concrete types, correlated generics and validated `unknown` at external boundaries.

Run `lute run tools/check-comments.luau [base-ref]` to check added Luau comments against `origin/main` by default.
Tool directives and required license notices stay. Code review covers other languages.

## License

[MIT License](LICENSE). Preserve the copyright and permission notice in copies or substantial portions.
