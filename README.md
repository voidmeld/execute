# Execute

Reusable project instructions and Luau workflow tools for coding agents.

Execute helps development teams, including Roblox developers, give coding agents clear
assignments, permissions, review steps and recovery procedures. It provides Markdown
templates for running a project and optional Luau modules for selecting checks, preparing
worktrees, checking commit rules and integrating verified branches. Your project supplies
its decisions and the Git, filesystem and process operations. Execute does not run agents
or schedule their work; your agent application does that.

First, run one fixture with the [quickstart](docs/quickstart.md).

## What is inside

| Family | Tools | Entry |
| --- | --- | --- |
| Check selection | Select specifications and commands by changed paths; report paths without a matching rule | [`scoped-checks`](docs/api.md#scoped-checks) |
| Commit rules | Parse Git logs and check author, committer and trailer requirements | [`commit-policy`](docs/api.md#commit-policy) |
| Edit permissions | Check which identities may change particular paths or document sections | [`guarded-surface`](docs/api.md#guarded-surface) |
| Integration | Run verification steps, classify conflicts and integrate one branch or a batch | [`landing`](docs/api.md#landing) |
| Record cleanup | Plan which records to keep and apply requested deletions | [`retention`](docs/api.md#retention) |
| Checkout preparation | Create or reuse worktrees, prepare dependencies and generated inputs, report stale inputs | [`worker-setup`](docs/api.md#worker-setup) |
| Source rules | Scan Luau source for calls and silent fallbacks, compile at the register limit, reconcile findings with a supplied allowlist | [`source-scan`](docs/api.md#source-scan), [`call-scanner`](docs/api.md#call-scanner), [`silent-fallbacks`](docs/api.md#silent-fallbacks), [`register-limit`](docs/api.md#register-limit) |

The project templates cover assignments, permissions, current status, quality criteria,
integration and recovery. Adapters describe the controls available in Codex and Claude;
optional extensions add Luau tooling, interface testing and Roblox procedures. The
[documentation table](#documentation) links to each template and guide.

## Example

Select checks for a changed module and identify a path that needs a separate rule:

```luau
local ScopedChecks = require("@execute/extensions/luau/scoped-checks")

local groups: { ScopedChecks.Group } = {
    { name = "records", paths = { "^src/records/" }, specs = { "^tests/records" }, checks = {} },
}
local changed = { "src/records/read.luau", "README.md" }
local selection = ScopedChecks.select(changed, groups, { "tests/records.verify.luau" })

assert(selection.groups[1].name == "records")
assert(ScopedChecks.unowned(changed, groups)[1] == "README.md")
```

Selection returns data without running commands. Handle unmatched paths before deciding
which checks to run. The [API reference](docs/api.md) covers each module's inputs,
results and failures. In this example, `@execute` is the alias of the installed package.

## How it fits together

| Surface | Purpose |
| --- | --- |
| `AGENTS.template.md`, `docs` | Project instructions and templates for permissions, assignments, status and procedures. |
| `adapters` | Agent application controls for Codex and Claude. |
| `extensions/luau` | Optional workflow modules with supplied Git, filesystem, clock and process functions. |
| `extensions/interactive-qa` | Procedures for testing interfaces with captures and input. |
| `extensions/roblox` | Roblox development and asset procedures. |
| `examples` | Runnable fixtures that demonstrate the Luau API. |

Copy only the templates and modules your project needs. Fill project values and permissions
before using the instructions. This repository's `AGENTS.md` governs maintenance;
`AGENTS.template.md` is the starting point for your project's instructions.

## Install

Execute installs with Lute's package manager, `lute pkg`, and needs Lute
`1.0.1-nightly.20261120` or newer. Add it to your `pkg.luau`, pinned to an exact commit:

```luau
return {
	package = {
		dependencies = {
			execute = { sourceKind = "github", source = "https://github.com/voidmeld/execute", rev = "<commit>" },
		},
	},
}
```

Run `lute pkg install --vendor`, commit `pkg.lock.luau` and ignore `.lpm/`. Alias the vendored
copy in `.config.luau` with `execute = "./.lpm/execute@<commit>"`, then
`require("@execute/extensions/luau/scoped-checks")`. The package ships the templates, `docs`,
`adapters`, `extensions`, the agent skills and the link checker, without specifications; the operating skill installs at
`.lpm/execute@<commit>/.agents/skills/execute-operate/SKILL.md` (and `.claude/skills/execute-operate`).
To check a repository's Markdown links and anchors, run
`lute run .lpm/execute@<commit>/tools/check-links.luau` from its root; it reads the files that
`git` tracks and exits non-zero on the first broken link. Record the commit in your
[adoption record](docs/ADOPTION.md); the
[quickstart](docs/quickstart.md#adopt-the-operating-documents) lists the remaining steps. After a
pin change, review local template changes and run checks for any tools that use the updated modules.

## Documentation

| Task | Document |
| --- | --- |
| Run the first fixture and adopt the templates | [Quickstart](docs/quickstart.md) |
| Find public calls, returns and failures | [API reference](docs/api.md) |
| Start a project's agent instructions | [Adopter template](AGENTS.template.md) |
| Define permissions and staffing | [OWNER](docs/OWNER.md) |
| Assign work and review results | [TASKS](docs/TASKS.md) |
| Record current status and recovery facts | [STATE](docs/STATE.md) |
| Follow work and integration procedures | [PLAYBOOK](docs/PLAYBOOK.md) |
| Define quality criteria | [TASTE](docs/TASTE.md) |
| Record the source pin and local changes | [ADOPTION](docs/ADOPTION.md) |
| Appoint or replace the lead agent | [SUCCESSION](docs/SUCCESSION.md) |
| Apply writing and execution rules | [Agentic standard](docs/AGENTIC-STANDARD.md) |
| Choose agent application controls | [Adapters](adapters/README.md), [Codex](adapters/codex/README.md), [Claude](adapters/claude/README.md) |
| Select optional procedures and tools | [Extensions](extensions/README.md) |
| Connect Git, filesystem and process functions | [Luau extension](extensions/luau/README.md) |
| Test interfaces | [Interactive QA extension](extensions/interactive-qa/README.md) |
| Adopt Roblox procedures | [Roblox extension](extensions/roblox/README.md), [integration](extensions/roblox/INTEGRATION.md) |
| Set up tools or diagnose checks | [Validation](docs/VALIDATE.md) |
| Change this repository | [Maintainer guide](AGENTS.md) |

## Compatibility

The supported unit is an exact commit. The package version in `pkg.luau` follows
[semantic versioning](https://semver.org) at `0.x`, so a minor release may change a contract;
[CHANGELOG.md](CHANGELOG.md) records releases. Execute supports Lute `1.0.1-nightly.20261120`.
Public module exports, configuration records and documented failure behavior are
contracts. Update affected tools with a contract change. Project templates require local
values and permissions; copying or updating them grants no authority. Internal helpers and
verification fixtures are not public APIs.

## License

Execute is [MIT licensed](LICENSE). Its development dependency, Verify, is declared in
[pkg.luau](pkg.luau) and locked in [pkg.lock.luau](pkg.lock.luau).
