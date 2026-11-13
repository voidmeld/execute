# Luau extension

These optional modules supply common operations for project tools. The host supplies Git, file, clock and
process operations. The modules do not access those services directly. Execute's operating rules remain in
Markdown. Copy only the modules that a current consumer needs. Keep product values and rules in that consumer.

The [API reference](../../docs/api.md) owns public signatures, configuration, returns and failures. The
[example](../../examples/scoped-checks.luau) selects checks for changed paths.

| Module | Operation |
| --- | --- |
| [landing](landing.luau) | Integrates one branch or several branches as a train. |
| [scoped-checks](scoped-checks.luau) | Selects specifications and checks from supplied path patterns. |
| [worker-setup](worker-setup.luau) | Creates or reuses a worktree and prepares its inputs. |
| [commit-policy](commit-policy.luau) | Checks authors, committers and trailers against supplied rules. |
| [guarded-surface](guarded-surface.luau) | Checks path and section rules against supplied authority. |
| [call-scanner](call-scanner.luau) | Finds calls, arguments and member references in Luau source. |
| [retention](retention.luau) | Plans or applies deletion for supplied record families. |
| [silent-fallbacks](silent-fallbacks.luau) | Finds silent fallbacks in source against a supplied allowlist. |
| [register-limit](register-limit.luau) | Compiles supplied modules at the engine register limit. |
| [source-scan](source-scan.luau) | Lists source files and reconciles findings with an allowlist. |

## Verification and adoption

Each module has an adjacent `*.verify.luau` specification. `worktree.lute.verify.luau` tests setup and landing
with temporary Git repositories. Its case context removes those repositories. Follow
[Validation](../../docs/VALIDATE.md) for setup and checks.

1. Copy the selected modules.
2. Bind the project's host operations.
3. Record the exact source in [ADOPTION](../../docs/ADOPTION.md).
4. After an update, validate the project's actual consumer.
