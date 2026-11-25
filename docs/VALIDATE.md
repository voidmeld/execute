# Validate Execute

Run these commands from the Execute source checkout to install the pinned tools and development dependency.

```sh
rokit install
lute setup
lute pkg install --vendor --locked
```

While editing, use `--file` to run one specification or `--tier fast` to run all the fast checks.

```sh
lute run tools/gate.luau --file extensions/luau/scoped-checks.verify.luau
lute run tools/gate.luau --tier fast
```

If you add or remove a specification, run `lute run tools/check-test-manifest.luau --write`.
If you change a public export, update the [API reference](api.md).

Commit your changes, then run `lute run tools/gate.luau` with a clean worktree. The full gate also tests a fresh clone.
If a check fails, read its output under `.lute/tmp/execute-gate/`. Use `--only <producer>`, `--file <spec>`,
or `--name <text>` to rerun the relevant check while fixing the problem. Commit the fix and run the full gate on the new commit.
