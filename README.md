# Execute

Execute helps a team of agents keep improving a game. The owner orders the backlog.
An agent takes one playable outcome, checks it, and pushes the passing commit to main.
The project supplies one fast guardrail command and one ship command.

## Start in your project

1. Copy [AGENTS.template.md](AGENTS.template.md) to `AGENTS.md` and [BACKLOG.template.md](BACKLOG.template.md) to `BACKLOG.md` in your project root.
2. Fill in the commands, who may run them, and the hard rules that protect your game.
3. Put the owner's first request at the top of the backlog. Follow the [operating guide](docs/OPERATING.md) for one change.

Choose a guardrail command that exercises your essential player journeys and exits nonzero if any breaks.
Keep the ship command bound to the revision and destination it will release.

| Task | Where to go |
| --- | --- |
| Assign a helper | [Helper brief](docs/helper-brief.md) and [agent adapters](adapters/README.md) |
| Diagnose a quiet session | [Stall check](docs/OPERATING.md#stall-check) |
| Use an optional tool or platform procedure | [Extensions](extensions/README.md) and [Luau API](docs/api.md) |
| Upgrade from 0.1 | [Migration note](CHANGELOG.md#020) |
| Change Execute itself | Read `AGENTS.md` in the source checkout |

## Optional package install

For the Luau tools, add an exact Execute commit to your project's `pkg.luau` dependencies.

```luau
execute = { sourceKind = "github", source = "https://github.com/voidmeld/execute", rev = "<commit>" },
```

Use Lute `1.0.1-nightly.20261120` or newer. Run `lute pkg install --vendor` and commit `pkg.lock.luau`.
Set the `execute` alias in `.config.luau` to `"./.lpm/execute@<commit>"`.
For example, load a module with `require("@execute/extensions/luau/scoped-checks")`.
The package also ships the [Markdown link checker](tools/check-links.luau). Run it from your project root
with `lute run .lpm/execute@<commit>/tools/check-links.luau`.

Execute is [MIT licensed](LICENSE).
