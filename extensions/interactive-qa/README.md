# Interactive QA extension

Use this extension for a product that a person operates through an interface. It adds evidence rules for running
clients. The core [evidence ladder](../../docs/PLAYBOOK.md#evidence) remains generic. [Interactive
QA](docs/INTERACTIVE-QA.md) owns captures, scenarios, input and release.

## Adopt the extension

1. Copy `extensions/interactive-qa`.
2. In PLAYBOOK, link the product-level acceptance step to [Interactive QA](docs/INTERACTIVE-QA.md).
3. Declare exact commands, hosts, devices and input classes in the project.
4. Record the source commit in [ADOPTION](../../docs/ADOPTION.md).
5. Delete unused guidance.

Platform extensions link here for shared rules. The [Roblox extension](../roblox/README.md) uses these rules.
