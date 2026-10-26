# Execute

Execute is a template for work that agents do in a project. Its documents define roles, authority, checks,
integration and recovery. The agent harness runs the work and sends messages. Execute has no manager process or
task system. Optional Luau modules supply common tool operations.

## Getting started

First, select the documents and one [harness adapter](adapters/README.md) for your project.

1. Copy the core documents in the map below.
2. Copy one adapter.
3. Select only the [extensions](extensions/README.md) that your project needs.
4. Fill the placeholders in AGENTS, STATE, OWNER, TASTE and ADOPTION.
5. Record the exact source commit and tree in [ADOPTION](docs/ADOPTION.md).
6. If the Owner authorizes a CEO appointment, follow [SUCCESSION](docs/SUCCESSION.md).
7. Replace this README with the product README.

Copying files grants no authority. For an existing operation, resume from STATE. The project chooses its workers
and any required independent review in OWNER.

## Terms

- **Adopter:** the project that uses this template.
- **Owner:** the human who holds authority.
- **CEO:** the one agent accountable for the work.
- **Worker:** a persistent session with a bounded assignment from the CEO.
- **Reviewer:** a reviewer of exact candidate bytes, when OWNER requires independent review.
- **Appointment:** the Owner's act that names the CEO.
- **Gate:** the command that checks a change.

## Documentation

Each page owns the subject in this map. Read the procedure or reference only when the task needs it.

| Page | Subject |
| --- | --- |
| [AGENTS](AGENTS.md) | Repository rules and startup route. |
| [OWNER](docs/OWNER.md) | Grants, staffing and reserved decisions. |
| [TASKS](docs/TASKS.md) | Roles, assignments, results and review. |
| [STATE](docs/STATE.md) | Current facts and recovery. |
| [PLAYBOOK](docs/PLAYBOOK.md) | Work procedures and evidence. |
| [TASTE](docs/TASTE.md) | Product quality criteria. |
| [ADOPTION](docs/ADOPTION.md) | Source identity and local differences. |
| [SUCCESSION](docs/SUCCESSION.md) | CEO appointment and replacement. |
| [Agentic standard](docs/AGENTIC-STANDARD.md) | Writing, execution and review rules. |
| [Validation](docs/VALIDATE.md) | Setup and checks for changes to Execute. |
| [Luau API](docs/api.md) | Exported module members. |
| [Adapters](adapters/README.md) | Harness selection and shared controls. |
| [Codex adapter](adapters/codex/README.md) | Codex task controls. |
| [Claude adapter](adapters/claude/README.md) | Claude session controls. |
| [Extensions](extensions/README.md) | Extension selection and adoption. |
| [Luau extension](extensions/luau/README.md) | Module configuration. |
| [Interactive QA extension](extensions/interactive-qa/README.md) | Adoption for products with an interface. |
| [Interactive QA](extensions/interactive-qa/docs/INTERACTIVE-QA.md) | Captures, scenarios and input. |
| [Roblox extension](extensions/roblox/README.md) | Roblox rules and references. |
| [Roblox adoption](extensions/roblox/INTEGRATION.md) | Required project values. |
| [Roblox operations](extensions/roblox/docs/ROBLOX.md) | Accounts, Studio, persistence and assets. |
| [Generative assets](extensions/roblox/docs/ROBLOX-GENERATIVE-ASSETS.md) | Asset generation and acceptance. |
| [Operating skill](.agents/skills/execute-operate/SKILL.md) | The delivery procedure for an assigned outcome. |
| [Claude entry](CLAUDE.md) | Claude instruction discovery. |
| [Claude skill entry](.claude/skills/execute-operate/SKILL.md) | The route to the operating skill. |

## Validate

To change Execute, follow [Validation](docs/VALIDATE.md). The placeholders in the template govern an adopting
project after appointment.


## License

[MIT License](LICENSE). Keep the copyright and permission notice in copies or substantial portions.
