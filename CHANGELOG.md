# Changelog

Execute follows [semantic versioning](https://semver.org). While the version is `0.x`, a minor release
may change a public contract.

## 0.2.2

- Clearer documentation.

## 0.2.1

- The operating guide and project templates explain how to pick a request from a software project's backlog,
  check the change before pushing, and release it. Each backlog item describes what a user should be able to
  see or do. The guide gives examples for a web app, a command-line tool, and a library.
- The optional [platform extension](extensions/roblox/README.md) now uses the platform's own terms for what
  developers build and the people who use it. The wording applies to the guides for the editor, live clients, and assets.

## 0.2.0

**Migrating from 0.1.x.** Move current permissions, hard rules, and the commands for checking and releasing
changes into your project's `AGENTS.md`. Move open requests into the [backlog](BACKLOG.template.md) in the
owner's words. Before you retire the old operating documents, save any information you still need about an
unresolved release, rollback, or rights question. Follow the [operating guide](docs/OPERATING.md) for new
work and helper assignments.

Before you update the commit your project uses, remove calls to `landing`, `retention`, `guarded-surface`,
and `commit-policy`. Push the commit that passed the checks through the route your project allows.
Keep any required policies for access, commits, and retention in your project. For instructions on taking
captures, see the [platform operations guide](extensions/roblox/docs/ROBLOX.md#captures).

## 0.1.4

- The operating skill uses the project's permissions to determine who may assign work, return a change, or
  integrate it. The playbook explains how to resume an interrupted integration, preserve original evidence,
  complete the record of what was integrated, and track transactions with external services. The handover
  procedure records who takes responsibility when a role changes hands.
- The [platform extension](extensions/roblox/README.md) now explains how to recover when sign-in is required
  and which user profile to use.

## 0.1.3

- Both operating skills and the adapters read the project's root `AGENTS.md` to find its permissions, current
  work, and commands. If a helper doesn't have permission to integrate a change, it checks the change and returns it.
- The gate checks relative links against the list of files in the package. The documentation identifies
  examples and specifications that are available only in the source checkout.

## 0.1.2

- The package includes `tools/check-links.luau`, which checks links and anchors in Markdown files that Git tracks.
  From your project root, run `lute run .lpm/execute@<commit>/tools/check-links.luau` to check your own files
  with the installed copy. The checker requires `git`. You can find the command under `metadata.commands` in `pkg.luau`.

## 0.1.1

- Execute now uses version 0.1.1 of its development dependency, Verify.

## 0.1.0

- This is the first versioned release of Execute. The `pkg.luau` file declares the `lute pkg` package and its
  development dependency. Install it with `lute pkg install --vendor`.
- Execute requires Lute `1.0.1-nightly.20261120` or newer.
