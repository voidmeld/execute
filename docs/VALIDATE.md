# Validate Execute

Read [AGENTS](../AGENTS.md) and the [agentic standard](AGENTIC-STANDARD.md) before you change Execute. Keep
reusable rules here. Keep product decisions in the adopting project. Update each changed contract and its
callers together.

## Setup

1. Install the pinned tools with `rokit install`.
2. Generate the SDK types with `lute setup`.

The gate installs the pinned Verify dependency in `.lute/dependencies`. The pin is in `dependencies.lock.luau`.
To use a local Verify checkout, set `VERIFY_SOURCE` to its path. An adopter who copies a module does not need
Verify.

## Checks while editing

Run `lute run tools/gate.luau --tier fast`. This command runs all checks except the fresh-clone check.

For one specification, run `lute run tools/gate.luau --file extensions/luau/landing.verify.luau`. For case names
that contain a text, use `--name text`. Other selectors are `--only producer`, `--case id`, `--rerun`,
`--explain id` and `--list`. A selected subset does not replace the gate.

After a specification changes, run `lute run tools/check-test-manifest.luau --write`. Run the
[example](../examples/scoped-checks.luau) with `lute run examples/scoped-checks.luau`. It prints the selected
groups, specifications, commands and paths without an owner.

## Final gate and integration

1. Commit the candidate.
2. Run `lute run tools/gate.luau` on the clean HEAD.
3. Submit a pull request to `main`.
4. Squash-merge only after the required `Gate` check passes.

Do not change verified bytes before integration. Do not push directly to `main`. Do not bypass a failed check.
GitHub Actions runs the gate with the pinned tools and SDK types.

The [Verify](https://github.com/voidmeld/verify) gate checks:

- the license and relative Markdown links and anchors
- source comments, format and lint
- strict types under both Luau solvers
- executable module contracts
- the test manifest and Verify consumer rules
- compact specification style through `Checks.specStyle`
- host boundaries, dependency source and product data
- the [public API](api.md) against the exported tables
- a fresh clone of HEAD that runs the fast gate

Every maintained Luau file must start with `--!strict`. Explicit `any`, `--!nonstrict` and `--!nocheck` fail.
Use concrete types and correlated generics. Validate `unknown` values at external boundaries. The gate ignores
diagnostics in the SDK implementation outside this repository.

Run `lute run tools/check-comments.luau` to check maintained Luau and Lua source comments. Compiler directives
and required license notices stay. Code review covers other languages.

Run `lute run tools/check-spec-style.luau` to check specification style. Specifications use `Bdd.create` and
bind `local describe, it, expect = ...` once. `tools/checks-config.luau` selects tracked and untracked
specifications. It can exclude tests of Verify's raw harness API.

A gate proves only its checks. It does not prove the behavior of an adopting product.
