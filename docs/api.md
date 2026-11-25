# API reference

This page owns public signatures, return values and failure behavior.
The public-surface check requires an entry here for every exported member and type.

| Task | Reference |
| --- | --- |
| Scan Luau source for calls, arguments and member references | [Call scanner](#call-scanner) |
| Select checks for changed files | [Scoped checks](#scoped-checks) |
| Compile shipped modules at the engine register limit | [Register limit](#register-limit) |
| Find silent fallbacks against a reviewed allowlist | [Silent fallbacks](#silent-fallbacks) |
| List source files and reconcile findings with an allowlist | [Source scan](#source-scan) |
| Prepare an isolated checkout | [Worker setup](#worker-setup) |

## Shared setup

The examples use the `execute` alias from the [package install instructions](../README.md#optional-package-install).

```luau
local CallScanner = require("@execute/extensions/luau/call-scanner")
local ScopedChecks = require("@execute/extensions/luau/scoped-checks")
local RegisterLimit = require("@execute/extensions/luau/register-limit")
local SilentFallbacks = require("@execute/extensions/luau/silent-fallbacks")
local SourceScan = require("@execute/extensions/luau/source-scan")
local WorkerSetup = require("@execute/extensions/luau/worker-setup")
```

The caller supplies the configuration and any Git, filesystem, clock or process operations.
Check the project's grants before invoking those operations.
Types in each signature belong to that module. `CommandResult` has `exitcode`, `stdout` and `stderr`.
Callers must inspect the returned verdict or outcome before continuing.
Host exceptions propagate unless a call explicitly catches them below.
Malformed Luau patterns can raise. Selection does not execute a check.

Run `lute run examples/scoped-checks.luau` in the Execute source checkout for a complete example.
Each module has an adjacent specification in the source checkout.

## Call scanner

The scanner reads Luau source as text and skips quoted text, long brackets and comments. It does not parse the
language. A position is a one-based byte offset. `findCalls` takes a needle such as `:Mark(`: a leading `:` or `.`,
a name and a closing parenthesis. It returns each call with its `start`, its `stop` and its top-level argument
texts, and skips a function declaration of that name. `findReferences` returns the positions of `.name` that are
neither a declaration nor the operand of a type query. `wholeCall` returns the arguments only when one call spans
the entire expression. The consumer owns the rules that judge what the scanner finds.

```luau
for _, call in CallScanner.findCalls(source, ":Mark(") do
	local line = CallScanner.lineOf(source, call.start)
end
```

See the executable contract in the Execute source checkout (`extensions/luau/call-scanner.verify.luau`).

Exported types: `CallScanner.Call`.

### `CallScanner.skipQuoted`

`skipQuoted(source: string, index: number) -> number`

Returns the position after the quoted text that begins at `index`, or past the end if it never closes.

### `CallScanner.skipLong`

`skipLong(source: string, index: number) -> number?`

Returns the position after the long bracket that begins at `index`, or `nil` if none begins there.

### `CallScanner.skipComment`

`skipComment(source: string, index: number) -> number`

Returns the position after the line or block comment that begins at `index`.

### `CallScanner.literalBytes`

`literalBytes(body: string) -> number`

Counts the bytes that a quoted literal body produces, resolving escapes.

### `CallScanner.splitTop`

`splitTop(text: string) -> { string }`

Splits argument text at commas outside quotes and brackets.

### `CallScanner.topLevel`

`topLevel(expression: string) -> string`

Reduces an expression to its top-level operators, with nested text removed and each quoted string as `S`.

### `CallScanner.wholeCall`

`wholeCall(expression: string, prefix: string) -> { string }?`

Returns the argument texts when the expression is exactly one call that starts with the prefix.

### `CallScanner.functionDefinitions`

`functionDefinitions(source: string) -> { [number]: boolean }`

Marks the positions of the `.` or `:` in each function declaration name.

### `CallScanner.findCalls`

`findCalls(source: string, needle: string) -> { Call }`

Finds the calls that match the needle outside strings and comments.

### `CallScanner.findReferences`

`findReferences(source: string, member: string) -> { number }`

Finds the positions of `.member` outside strings and comments that are not declarations or type queries.

### `CallScanner.lineOf`

`lineOf(source: string, position: number) -> number`

Returns the line number of a position.

## Register limit

A `Config` has a report `label`, the `roots` to walk, `include` and `exclude` Luau patterns for file names, and an
injected `compile(source)` that raises if the engine refuses the source. The module prefixes each source with
`UNOPTIMIZED`, so the compiler cannot fold away the registers a module needs.
`check` compiles every listed file, reports each refusal and returns zero only if none was refused.
It keeps checking after a refusal. The consumer owns the roots, the patterns and the compiler binding.

```luau
local files = RegisterLimit.shipped(config, host)
local code = RegisterLimit.check(files, host.read, config, print)
```

See the executable contract in the Execute source checkout (`extensions/luau/register-limit.verify.luau`).

Exported types: `RegisterLimit.Config`.

### `RegisterLimit.UNOPTIMIZED`

The source prefix that disables compiler optimization.

### `RegisterLimit.shipped`

`shipped(config: Config, host: SourceScan.Host) -> { string }`

Lists the files under the roots that match `include` and not `exclude`, sorted by path. Absent roots add nothing.

### `RegisterLimit.check`

`check(files: { string }, read: (string) -> string, config: Config, report: (string) -> ()) -> number`

Compiles each file through `config.compile`. Reports `<label>: FAIL <path>: <first line>` for a refusal and a
summary line. Returns 1 if any file was refused.

## Scoped checks

A `Group` has `name`, `paths`, `specs` and `checks`. Path and specification selectors are Luau patterns.
A `Selection` has the touched `groups`, sorted `specs` and selected command arrays in `checks`.
Groups retain declaration order. Unowned paths retain input order. No match returns an empty list.
`select` keeps matching specifications from touched groups, subject to optional `keep`.
Commands deduplicate by their first element, so use distinct first elements for distinct check identities.
No function here runs commands or refuses an uncovered path. Check `unowned` separately.

```luau
local selected = ScopedChecks.select(changedPaths, groups, candidateSpecs)
assert(#ScopedChecks.unowned(changedPaths, groups) == 0)
```

Run the complete example in the Execute source checkout (`examples/scoped-checks.luau`).
See the executable contract in the Execute source checkout (`extensions/luau/scoped-checks.verify.luau`).

Exported types: `ScopedChecks.Group`, `ScopedChecks.Selection`.

### `ScopedChecks.matches`

`matches(path: string, patterns: { string }) -> boolean`

Checks a value against supplied Luau patterns.

### `ScopedChecks.touched`

`touched(paths: { string }, groups: { Group }) -> { Group }`

Finds the groups that own changed paths.

### `ScopedChecks.unowned`

`unowned(paths: { string }, groups: { Group }) -> { string }`

Finds changed paths that no supplied group owns.

### `ScopedChecks.select`

`select(paths: { string }, groups: { Group }, candidateSpecs: { string }, keep: ((string, Group) -> boolean)?) -> Selection`

Selects owning groups, matching specifications and distinct commands for the changed paths and optional
selection.

## Silent fallbacks

The check finds three silent fallbacks in Luau source: `lookup-or-literal`, a keyed lookup that falls back to a
string literal; `discarded-pcall`, a protected call whose result nothing reads; and `display-empty-fallback`,
an empty string that stands in for a missing value in a display field. A `Config` supplies the report `label`,
the `displayFields` names, the `bestEffortWords` that mark a callee as best-effort, the `skipPaths` patterns of
files that are never scanned and the `teardownPaths` patterns where a discarded protected call is allowed.
An `Entry` allowlists one finding by `path`, `rule` and `snippet`, with a `disposition` of `authored` or
`pending` and a `reason` of at least twenty characters. The consumer owns every entry and every `Config` value.
`check` fails on an entry without a reason or a known disposition, on an entry that matches nothing and on any
finding that no entry allows. With `selected`, only entries under the `roots` take part.
Pending entries print and do not fail. `check` takes the listed `paths` and a `read` function from the host.

```luau
local code = SilentFallbacks.check({
	config = config,
	roots = roots,
	selected = false,
	entries = entries,
	paths = SourceScan.collect(roots, host, "%.luau$"),
	read = host.read,
}, print)
```

See the executable contract in the Execute source checkout (`extensions/luau/silent-fallbacks.verify.luau`).

Exported types: `SilentFallbacks.Hit`, `SilentFallbacks.Entry`, `SilentFallbacks.Config`, `SilentFallbacks.File`, `SilentFallbacks.Input`.

### `SilentFallbacks.normalize`

`normalize(text: string) -> string`

Collapses whitespace and bounds a snippet to 160 bytes.

### `SilentFallbacks.lintFile`

`lintFile(path: string, contents: string, config: Config) -> { Hit }`

Finds the fallbacks in one file, in line order. Comment lines are ignored.

### `SilentFallbacks.lint`

`lint(files: { File }, entries: { Entry }, config: Config) -> ({ Hit }, { Entry })`

Returns the findings that no entry allows, sorted by path, line and rule, and the entries that matched nothing.

### `SilentFallbacks.unreasoned`

`unreasoned(entries: { Entry }) -> { Entry }`

Returns the entries with a short reason or an unknown disposition.

### `SilentFallbacks.pending`

`pending(entries: { Entry }) -> { Entry }`

Returns the entries whose disposition is `pending`.

### `SilentFallbacks.selectEntries`

`selectEntries(entries: { Entry }, roots: { string }, selected: boolean) -> { Entry }`

Returns every entry, or only the entries under the roots when `selected` is true.

### `SilentFallbacks.check`

`check(input: Input, report: (string) -> ()) -> number`

Runs the allowlist and scan checks and reports each failure. Returns 0 if clean and 1 otherwise.

## Source scan

A `Host` supplies `exists`, `kind` and `children` for a path. `kind` returns `file`, `dir` or another value that
the scan skips. `collect` walks the roots depth first in name order, adds each file whose path matches the Luau
pattern, accepts a file as a root and skips an absent root.
`reconcile` splits findings into those that no allowlist entry covers and the entries that cover nothing, using
the supplied key functions. The consumer owns the host, the roots and the allowlist.

```luau
local files = SourceScan.collect({ "src" }, host, "%.luau$")
```

See the executable contract in the Execute source checkout (`extensions/luau/source-scan.verify.luau`).

Exported types: `SourceScan.Host`, `SourceScan.Reconciled`.

### `SourceScan.normalize`

`normalize(text: string, limit: number) -> string`

Trims text, collapses whitespace runs to one space and cuts it to `limit` bytes.

### `SourceScan.inRoots`

`inRoots(path: string, roots: { string }) -> boolean`

Checks whether a path equals a root or lies under it.

### `SourceScan.collect`

`collect(roots: { string }, host: Host, pattern: string) -> { string }`

Lists the matching files under the roots.

### `SourceScan.reconcile`

`reconcile<Hit, Entry>(hits: { Hit }, entries: { Entry }, hitKey: (Hit) -> string, entryKey: (Entry) -> string) -> Reconciled<Hit, Entry>`

Returns the findings no entry covers, in input order, and the entries no finding matched.

## Worker setup

`StepOutcome` has `name`, `status` (`PASS`, `SKIP`, `WARN` or `FAIL`) and `detail`.
`Config` declares `base`, `inputs` and optional `directories`, `lfs`, `lock` and `manifests`.
Each `Input` names `outputs`, tracked `sources` and a `regenerate` command.
A lock declares its file `path`, hash `marker` and `sync` command.
`Host` supplies `run`, `exists`, `modified`, `read`, `write`, `remove` and `createDirectory`.
An input is fresh only when outputs exist and no source modification time is newer.
Setup records the lock blob hash after sync. It removes undeclared generated manifests matching the supplied pathspec.

`commandStep` catches runner exceptions and nonzero exits as FAIL.
`directoryStep` skips an existing directory and catches creation errors as FAIL.
`cleanTreeStep` returns WARN for dirty or unreadable status. WARN does not prove cleanliness.
`ensureWorktree` reuses only the declared branch. A different branch or failed Git operation returns FAIL.
`prepareCheckout` returns all preparation outcomes, then appended step outcomes. Inspect `failureCount` before continuing.
`freshness` returns findings without changing files. Each finding has `kind`, `subject`, `detail` and `remedy`.
`DIRTY_PATH_LIMIT` bounds displayed paths. `firstLine` trims trailing whitespace from the first line.

```luau
local outcomes = WorkerSetup.prepareCheckout(config, host, {})
assert(WorkerSetup.failureCount(outcomes) == 0)
local findings = WorkerSetup.freshness(config, host)
```

See the executable contract in the Execute source checkout (`extensions/luau/worker-setup.verify.luau`).

Exported types: `WorkerSetup.StepStatus`, `WorkerSetup.StepOutcome`, `WorkerSetup.Step`, `WorkerSetup.CommandResult`, `WorkerSetup.Host`, `WorkerSetup.Input`, `WorkerSetup.Lock`, `WorkerSetup.Config`, `WorkerSetup.WorktreeSpec`, `WorkerSetup.Finding`.

`Config` and `Input` configure local generation. Reference-copy options and the host copy operation are absent.

### `WorkerSetup.DIRTY_PATH_LIMIT`

Maximum number of dirty paths shown before the warning reports the remaining count.

### `WorkerSetup.firstLine`

`firstLine(text: string) -> string`

Returns the first line of text with trailing whitespace removed.

### `WorkerSetup.commandStep`

`commandStep(name: string, command: { string }, run: ({ string }) -> CommandResult) -> StepOutcome`

Runs a command through the supplied function. Converts process failures and thrown errors into step outcomes.

### `WorkerSetup.directoryStep`

`directoryStep(path: string, exists: (string) -> boolean, create: (string) -> ()) -> StepOutcome`

Creates a missing directory through the supplied functions. Skips an existing directory and reports creation
errors.

### `WorkerSetup.dirtyPaths`

`dirtyPaths(statusOutput: string) -> { string }`

Extracts paths from Git porcelain status output.

### `WorkerSetup.cleanTreeStep`

`cleanTreeStep(name: string, result: CommandResult, warning: (string) -> string) -> StepOutcome`

Reports a clean checkout or a warning with dirty paths. An unreadable status is a warning, not proof of
cleanliness.

### `WorkerSetup.failureCount`

`failureCount(outcomes: { StepOutcome }) -> number`

Counts outcomes whose status is `FAIL`.

### `WorkerSetup.ensureWorktree`

`ensureWorktree(spec: WorktreeSpec, host: Host) -> StepOutcome`

Creates or reuses the declared branch worktree. Refuses a path that holds a different branch.

### `WorkerSetup.prepareCheckout`

`prepareCheckout(config: Config, host: Host, after: { Step }) -> { StepOutcome }`

Creates directories, hydrates LFS, syncs changed dependencies and regenerates absent or stale inputs. Removes
undeclared generated manifests. Then runs appended steps. Returns all step outcomes.

### `WorkerSetup.freshness`

`freshness(config: Config, host: Host) -> { Finding }`

Reports moved bases, unsynced locks, LFS pointers, missing or stale inputs and undeclared generated manifests.
Changes no files.

### `WorkerSetup.describeFinding`

`describeFinding(finding: Finding) -> string`

Formats a freshness finding with its subject, detail and remedy.
