# Changelog

Execute follows [semantic versioning](https://semver.org). While the version is `0.x`, a minor
release may change a public contract.

## 0.2.1

- The operating guide and adopter templates apply Execute's backlog, fast guardrail and ship workflow to software
  projects. Backlog items state what users should be able to see or do. The guide shows how to verify those
  outcomes in a web app, CLI or library.
- The optional [Roblox extension](extensions/roblox/README.md) describes Studio, live client and asset operations
  in terms of experiences and their users.

## 0.2.0

**Migrating from 0.1.x.** Move live grants, hard rules and the guardrail and ship commands into the project's
`AGENTS.md`. Move open work into the [backlog](BACKLOG.template.md) in the owner's words.
Keep any unresolved release, rollback or rights information before retiring the old operating documents.
Use the [operating guide](docs/OPERATING.md) for new work and helper assignments.

Remove calls to `landing`, `retention`, `guarded-surface` and `commit-policy` before updating the package pin.
Use a checked push through the project's allowed route. Keep any required access, commit and retention policies
in the project. Platform capture guidance now lives in the [platform operations guide](extensions/roblox/docs/ROBLOX.md#captures).

## 0.1.4

- The operating skill routes assignments, returns and landing through the adopter's grants. The playbook covers
  interrupted landings, original evidence, receipt closure and external transactions. Succession records custody transfers.
- The [platform extension](extensions/roblox/README.md) added sign-in recovery and profile requirements.

## 0.1.3

- Both operating skills and adapters use the adopter's root `AGENTS.md` to find grants, state and commands.
  Helpers return a verified candidate when the adopter withholds integration.
- The gate checks relative links against the package file list. Documentation identifies source-only examples and specifications.

## 0.1.2

- The package publishes `tools/check-links.luau`, the Markdown link and anchor checker, so a
  consumer can run it from the installed copy: `lute run .lpm/execute@<commit>/tools/check-links.luau`
  from the consumer's repository root. It checks the consumer's own tracked Markdown and needs
  `git`. `pkg.luau` names it under `metadata.commands`.

## 0.1.1

- Verify, the development dependency, moves to 0.1.1.

## 0.1.0

- First versioned release. Execute is a `lute pkg` package: `pkg.luau` declares the package and
  its development dependency, and adopters install it with `lute pkg install --vendor`.
- Requires Lute `1.0.1-nightly.20261120` or newer.
