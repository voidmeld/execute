# Quickstart

Select checks for changed files before connecting any host operations.
The fixture does no filesystem, process or remote work.

## Prepare the tools

1. Run `rokit install` from the repository root.
2. Run `lute setup` to install the SDK types.
3. Run the [complete example](../examples/scoped-checks.luau):

```console
lute run examples/scoped-checks.luau
```

The example prints the selected groups, specifications, commands and unowned paths.
It demonstrates selection only. It runs none of the selected commands.

## Select a scope

This fragment uses the public module directly:

```luau
local ScopedChecks = require(path.to.execute["scoped-checks"])
local groups: { ScopedChecks.Group } = {
    { name = "records", paths = { "^src/records/" }, specs = { "^tests/records" }, checks = {} },
}
local changed = { "src/records/read.luau", "README.md" }
local selection = ScopedChecks.select(changed, groups, { "tests/records.verify.luau" })
assert(selection.groups[1].name == "records")
assert(ScopedChecks.unowned(changed, groups)[1] == "README.md")
```

Handle unowned paths explicitly. An empty selection does not prove that a change needs no checks.
See [the API](api.md#scoped-checks) for ordering, deduplication and failure behavior.

Run the success and unmatched-path cases:

```console
lute run tools/gate.luau --file extensions/luau/scoped-checks.verify.luau
```

## Adopt the operating documents

1. Copy `AGENTS.template.md` to the adopter's `AGENTS.md`.
2. Copy the core documents listed in the [README](../README.md#documentation).
3. Select one [adapter](../adapters/README.md) and only the required [extensions](../extensions/README.md).
4. Fill the project values and authority grants before using the documents.
5. Record the exact source commit and tree in the adopter's `docs/ADOPTION.md`.

Copy only the Luau modules that a current tool needs.
The consumer supplies every host operation. Copying a module grants no integration or release authority.
