# Validate Execute

From the source checkout, install the pinned tools and development dependency.

```sh
rokit install
lute setup
lute pkg install --vendor --locked
```

Run one specification while editing, or select all fast checks.

```sh
lute run tools/gate.luau --file extensions/luau/scoped-checks.verify.luau
lute run tools/gate.luau --tier fast
```

When specifications are added or removed, run `lute run tools/check-test-manifest.luau --write`.
Update the [API reference](api.md) when a public export changes.

Commit the candidate and run `lute run tools/gate.luau` from the clean worktree. This also checks a fresh clone.
If a check fails, inspect its output under `.lute/tmp/execute-gate/`. Use `--only <producer>`,
`--file <spec>` or `--name <text>` to check the repair. Commit the fix and run the full gate on the new HEAD.
