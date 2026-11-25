# Changelog

Execute follows [semantic versioning](https://semver.org). While the version is `0.x`, a minor
release may change a public contract.

## 0.1.4

- The operating skill routes assignments, returns and landing through the adopter's grants. The playbook covers
  interrupted landings, original evidence, receipt closure and external transactions. Succession records custody transfers.
- The Roblox extension documents Quick Sign-in recovery for Studio automation and Windows profile requirements.

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
