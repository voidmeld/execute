# Luau extension

These optional modules supply common operations for project tools. The host supplies Git, file, clock and
process operations. The modules do not access those services directly. Execute's operating rules remain in
Markdown. Copy only the modules that a current consumer needs. Keep product values and rules in that consumer.

The [API reference](../../docs/api.md) describes each exported runtime member. The
[example](../../examples/scoped-checks.luau) selects checks for changed paths.

| Module | Operation |
| --- | --- |
| [landing](landing.luau) | Integrates one branch or several branches as a train. |
| [scoped-checks](scoped-checks.luau) | Selects specifications and checks from supplied path patterns. |
| [worker-setup](worker-setup.luau) | Creates or reuses a worktree and prepares its inputs. |
| [commit-policy](commit-policy.luau) | Checks authors, committers and trailers against supplied rules. |
| [guarded-surface](guarded-surface.luau) | Checks path and section rules against supplied authority. |
| [retention](retention.luau) | Plans or applies deletion for supplied record families. |

## Landing

Run landing from the primary checkout. Each candidate branch must have a worktree. If a worktree is absent, the
refusal gives a `git worktree add` command. The module rebases candidates in their worktrees. It resolves
registered conflicts and runs the host's preparation, guard and verification steps. It fast-forwards the
destination and proves remote equality before cleanup. If a train aborts, it resets the members.

After a passed gate, a base move on disjoint paths does not require another gate run. `runStep` runs one
command. On failure, it reports failing lines, an output tail and a log path.

## Worker-setup configuration

The host builds a `Config` and a `Host`. `Config` has these fields:

- `base`: the shared base ref for the check for base movement.
- `directories`: directories to create if absent.
- `lfs`: whether to fetch LFS file content.
- `lock`: the lock path, marker path and sync command.
- `inputs`: generated inputs, with `outputs`, tracked `sources` and a `regenerate` command.
- `manifests`: a Git pathspec and the file names that current sources declare.

The lock marker records the lock's blob hash after a sync. Setup deletes ignored manifests that match the
pathspec but have no declaration. `prepareCheckout` runs the appended steps after preparation. Step results are
PASS, SKIP, WARN or FAIL. `freshness` reports stale items without file changes.

An input is fresh if each output exists and no source is newer. If an input is absent or stale, setup regenerates it. Freshness uses file modification
times. Touching a source can cause one regeneration without a content change.

## Retention

For `newest-per-group`, the module keeps the newest record in each group. For `retained-terminal`, a superseded
reason takes priority over a nonterminal reason. Both reasons keep the row's group and detail. Only `apply`
calls the host's remove function.

## Verification and adoption

Each module has an adjacent `*.verify.luau` specification. `worktree.lute.verify.luau` tests setup and landing
with temporary Git repositories. Its case context removes those repositories. Follow
[Validation](../../docs/VALIDATE.md) for setup and checks.

1. Copy the selected modules.
2. Bind the project's host operations.
3. Record the exact source in [ADOPTION](../../docs/ADOPTION.md).
4. After an update, validate the project's actual consumer.
