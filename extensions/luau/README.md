# Luau tools

| Module | Use |
| --- | --- |
| [call-scanner](call-scanner.luau) | Find calls, arguments and member references in source. |
| [register-limit](register-limit.luau) | Compile shipped modules at the engine register limit. |
| [scoped-checks](scoped-checks.luau) | Select focused checks for changed paths. |
| [silent-fallbacks](silent-fallbacks.luau) | Compare silent fallbacks with an allowlist. |
| [source-scan](source-scan.luau) | Collect source files and reconcile findings with an allowlist. |
| [worker-setup](worker-setup.luau) | Create or reuse a worktree and prepare its inputs. |

The caller supplies Git, filesystem, clock and process operations. The [API reference](../../docs/api.md)
describes the inputs, results and failure behavior. Run `lute run examples/scoped-checks.luau` in the Execute source checkout to try check selection.
