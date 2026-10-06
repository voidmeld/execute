# Interactive QA extension

Adopt this extension if a person operates your product through an interface: an app, a tool or a game.
It adds the evidence rules for running clients. The core ladder in [PLAYBOOK](../../docs/PLAYBOOK.md#evidence) stays generic.

- [Interactive QA](docs/INTERACTIVE-QA.md): the evidence record, captures, scenarios, input and release of a running client.

## Adopt the extension

1. Copy `extensions/interactive-qa`.
2. In PLAYBOOK, fill the product-level acceptance step of the evidence ladder with a link to [Interactive QA](docs/INTERACTIVE-QA.md).
3. Declare the exact commands, hosts, devices and input classes in your project layer. They do not belong here.
4. Record the source commit in [ADOPTION](../../docs/ADOPTION.md).
5. Delete the guidance that your product does not need.

An extension that targets one platform links here for the shared rules. See the [Roblox extension](../roblox/README.md).
