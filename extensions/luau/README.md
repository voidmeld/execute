# Luau tools

| Module | When to use it |
| --- | --- |
| [call-scanner](call-scanner.luau) | Find calls, arguments, and member references in source files. |
| [register-limit](register-limit.luau) | Check whether the modules you ship fit within the Luau compiler's register limit. |
| [scoped-checks](scoped-checks.luau) | Choose which checks to run for the paths that changed. |
| [silent-fallbacks](silent-fallbacks.luau) | Find silent fallbacks and compare them with an allowlist. |
| [source-scan](source-scan.luau) | Collect source files and match findings against an allowlist. |
| [worker-setup](worker-setup.luau) | Create or reuse a worktree and prepare the inputs it needs. |

Your code supplies the functions that interact with Git, the filesystem, the clock, and other processes.
The [API reference](../../docs/api.md) describes what each module takes, what it returns, and how it handles failures.

To see how to choose checks for a change, run `lute run examples/scoped-checks.luau` from the Execute source checkout.
