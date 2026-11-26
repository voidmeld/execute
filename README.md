# Execute

Execute helps a team of agents improve a software project one change at a time. The owner puts requests in priority order.
An agent picks the first ready item in the backlog, makes the change, and checks that it works.
Once the checks pass, someone with permission pushes that commit to `main`.

Each project supplies two commands. One runs a fast check before a push. The other releases a specific revision.

## Start in your project

1. In your project root, copy [AGENTS.template.md](AGENTS.template.md) to `AGENTS.md` and [BACKLOG.template.md](BACKLOG.template.md) to `BACKLOG.md`.
2. In `AGENTS.md`, list the commands, who may run them, and the rules everyone must follow.
3. Put the owner's first request at the top of `BACKLOG.md`. Follow the [operating guide](docs/OPERATING.md) to make and check that change.

Choose a fast check that tests essential user workflows or public interfaces.
The command must return a nonzero exit status if a check fails. Configure the release command to publish
only the specified revision to the specified destination.

| Task | Where to go |
| --- | --- |
| Give part of a change to a helper | [Helper brief](docs/helper-brief.md) and [agent adapters](adapters/README.md) |
| Learn what good work looks like in a domain and apply it in review | [Expertise lane brief and worked example](docs/expertise-lane.md) |
| Check on a session that seems to have stalled | [Stall check](docs/OPERATING.md#stall-check) |
| Use an optional tool or follow instructions for a particular platform | [Extensions](extensions/README.md) and [Luau API](docs/api.md) |
| Upgrade from 0.1 | [Migration note](CHANGELOG.md#020) |
| Change Execute itself | Read `AGENTS.md` in the source checkout. |

## Optional package install

To use the Luau tools, add Execute to the dependencies in your project's `pkg.luau`.
Replace `<commit>` with the exact commit you want to install.

```luau
execute = { sourceKind = "github", source = "https://github.com/voidmeld/execute", rev = "<commit>" },
```

Use Lute `1.0.1-nightly.20261120` or newer. Run `lute pkg install --vendor` and commit `pkg.lock.luau`.
In `.config.luau`, set the `execute` alias to `"./.lpm/execute@<commit>"` using the same commit.
You can then load a module with `require("@execute/extensions/luau/scoped-checks")`.

The package includes a [Markdown link checker](tools/check-links.luau).
To check your project's links, run `lute run .lpm/execute@<commit>/tools/check-links.luau` from your project root.

Execute uses the [MIT license](LICENSE).
