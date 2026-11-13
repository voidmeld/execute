# API reference

This page owns public signatures, return values and failure behavior.
The public-surface check requires an entry here for every exported member and type.

| Task | Reference |
| --- | --- |
| Scan Luau source for calls, arguments and member references | [Call scanner](#call-scanner) |
| Select checks for changed files | [Scoped checks](#scoped-checks) |
| Check commit identity and trailers | [Commit policy](#commit-policy) |
| Check authority over paths and sections | [Guarded surface](#guarded-surface) |
| Integrate a verified candidate | [Landing](#landing) |
| Compile shipped modules at the engine register limit | [Register limit](#register-limit) |
| Plan retention and apply authorized deletion | [Retention](#retention) |
| Find silent fallbacks against a reviewed allowlist | [Silent fallbacks](#silent-fallbacks) |
| List source files and reconcile findings with an allowlist | [Source scan](#source-scan) |
| Prepare an isolated checkout | [Worker setup](#worker-setup) |

## Shared setup

Examples are fragments. Replace `path.to.execute` with the copied `extensions/luau` directory:

```luau
local CallScanner = require(path.to.execute["call-scanner"])
local ScopedChecks = require(path.to.execute["scoped-checks"])
local CommitPolicy = require(path.to.execute["commit-policy"])
local GuardedSurface = require(path.to.execute["guarded-surface"])
local Landing = require(path.to.execute.landing)
local RegisterLimit = require(path.to.execute["register-limit"])
local Retention = require(path.to.execute.retention)
local SilentFallbacks = require(path.to.execute["silent-fallbacks"])
local SourceScan = require(path.to.execute["source-scan"])
local WorkerSetup = require(path.to.execute["worker-setup"])
```

Each area names the consumer records that its fragment assumes, such as `rules`, `policy`, `config` and `host`.
Calls use dots. A module does no ambient Git, filesystem, clock or process work.
The consumer injects those effects and binds authority before invoking them.
Types in each signature belong to that module. `CommandResult` has `exitcode`, `stdout` and `stderr`.
Callers must inspect the returned verdict or outcome before continuing.
Host exceptions propagate unless a call explicitly catches them below.
Malformed Luau patterns can raise. Selection does not execute a check.

The [quickstart](quickstart.md) runs a complete fixture.
Adjacent [specifications](../extensions/luau) exercise every module, including refusals and recovery.

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

See the [executable contract](../extensions/luau/call-scanner.verify.luau).

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

## Commit policy

`Verdict` is `{ status = "pass", count }` or `{ status = "refuse", reason, detail }`.
An empty range, mismatched identity or forbidden trailer refuses.
`parseLog` returns `nil, reason` for a record with the wrong field count; an empty log returns an empty list.
`hasTrailer` matches case-insensitive trailer lines. It does not change a commit.

```luau
local commits, failure = CommitPolicy.parseLog(logOutput)
assert(commits, failure)
local verdict = CommitPolicy.evaluate(commits, rules)
assert(verdict.status == "pass")
```

Use `LOG_FORMAT` with Git before parsing. `FIELD` and `RECORD` delimit the six fields and each record.
See the [executable contract](../extensions/luau/commit-policy.verify.luau).

Exported types: `CommitPolicy.Identity`, `CommitPolicy.Rules`, `CommitPolicy.Commit`, `CommitPolicy.Pass`, `CommitPolicy.Refuse`, `CommitPolicy.Verdict`, `CommitPolicy.CommandResult`, `CommitPolicy.Git`.

### `CommitPolicy.FIELD`

`FIELD: string = string.char(31)`

The commit log format and parser use this field separator.

### `CommitPolicy.RECORD`

`RECORD: string = string.char(30)`

The commit log format and parser use this record separator.

### `CommitPolicy.LOG_FORMAT`

`LOG_FORMAT: string = "%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1e"`

This Git log format carries commit identity, author, committer and body for policy checks.

### `CommitPolicy.parseLog`

`parseLog(output: string) -> ({ Commit }?, string?)`

Parses formatted Git log output into commits. Returns a parse error when a record is malformed.

### `CommitPolicy.hasTrailer`

`hasTrailer(message: string, trailer: string) -> boolean`

Checks whether a commit body contains an attribution trailer covered by the policy.

### `CommitPolicy.evaluate`

`evaluate(commits: { Commit }, rules: Rules) -> Verdict`

Checks commits against the supplied author, committer and trailer rules. Returns a policy verdict.

### `CommitPolicy.runRange`

`runRange(base: string, head: string, rules: Rules, git: Git) -> Verdict`

Reads the candidate range through the supplied Git function, parses it and evaluates its commits. Refuses
unreadable or malformed logs.

## Guarded surface

`Verdict` is `pass`, `refuse` or `pass_override`. A refusal includes `reason`, `detail` and `paths`.
`matchedRule` returns the first exact or prefix rule, or nil. A prefix rule ends in `/**`.
`headingIndex` indexes second-level Markdown headings; `headingAt` returns nil before the first heading.
`parseHunks` returns an empty list when no unified-diff headers match.
`sectionsTouched` checks old and new changed lines and returns unique matching headings.
Missing mixed-section evidence refuses closed.
Authority passes guarded changes only when `actual` is present and equals `recorded`.
`withOverride` preserves all results except an explicitly requested override of a refusal.
An override records the bypass, warning and supplied banking text. It grants no authority itself.

```luau
local verdict = GuardedSurface.evaluate(changedPaths, policy, authority, dependencies)
assert(verdict.status == "pass")
```

See the [executable contract](../extensions/luau/guarded-surface.verify.luau).

Exported types: `GuardedSurface.Tier`, `GuardedSurface.MixedRule`, `GuardedSurface.Authority`, `GuardedSurface.Policy`, `GuardedSurface.Dependencies`, `GuardedSurface.Pass`, `GuardedSurface.PassOverride`, `GuardedSurface.Refuse`, `GuardedSurface.Verdict`, `GuardedSurface.Hunk`, `GuardedSurface.Heading`.

### `GuardedSurface.matchedRule`

`matchedRule(path: string, tier: Tier) -> string?`

Finds the supplied surface rule that matches a path.

### `GuardedSurface.parseHunks`

`parseHunks(diffText: string) -> { Hunk }`

Parses changed line ranges from a diff.

### `GuardedSurface.headingIndex`

`headingIndex(text: string) -> { Heading }`

Indexes Markdown headings for section checks.

### `GuardedSurface.headingAt`

`headingAt(index: { Heading }, lineNumber: number) -> string?`

Finds the heading that owns a line.

### `GuardedSurface.sectionsTouched`

`sectionsTouched(diffText: string, baseText: string, headText: string, headingPattern: string) -> { string }`

Finds the sections that the changed line ranges affect.

### `GuardedSurface.offendingPaths`

`offendingPaths(changedPaths: { string }, policy: Policy, deps: Dependencies) -> { string }`

Collects paths that violate the supplied surface rules.

### `GuardedSurface.evaluate`

`evaluate(changedPaths: { string }, policy: Policy, authority: Authority, deps: Dependencies) -> Verdict`

Evaluates the acting identity and changed paths or sections against the supplied authority rules.

### `GuardedSurface.withOverride`

`withOverride(verdict: Verdict, requested: boolean, label: string, banking: string) -> Verdict`

Applies an explicit override to a refusal. Returns a warning with the bypassed refusal and banking result.

## Landing

`Outcome` is `{ ok = true, sha, filesChanged }` or a `Refusal`.
A refusal has `ok = false`, `reason`, `detail`, `failingLines`, and optional `member` and `logPath`.
Run landing from the primary checkout. Each candidate requires its own worktree.
The plan supplies setup, preparation, authority checks, verification, conflict policy and logging.
Landing can rebase, commit conflict resolutions, merge, push and remove worktrees through the injected Git host.
Call it only under grants for those effects. The module proves remote equality before cleanup.

`runStep` returns nil on exit zero. It catches runner exceptions and reports bounded output and a log path.
`findWorktreeForBranch` returns a path, or `nil, reason` with a worktree setup remedy.
`classifyFastForward` returns `ok`, `failed` or `unproven`; `ok` includes the changed-file count.
`mergeVerified` also checks exact destination identity. A successful merge command alone is insufficient.
`classifyConflict` returns `resolvable`, `hand_authored` or `real` from the supplied rules.
`shortSha` returns up to seven characters after trimming whitespace. `trainBranchName` binds the ordered member identities.

```luau
local outcome = Landing.landOne("fixture-change", dependencies)
assert(outcome.ok, if outcome.ok then nil else outcome.detail)
```

The [landing specification](../extensions/luau/landing.verify.luau) supplies a fake host.
The [local integration specification](../extensions/luau/worktree.lute.verify.luau) exercises temporary repositories.

Exported types: `Landing.CommandResult`, `Landing.Refusal`, `Landing.Success`, `Landing.Outcome`, `Landing.FastForward`, `Landing.Resolver`, `Landing.ConflictPolicy`, `Landing.ConflictClass`, `Landing.FailurePolicy`, `Landing.StepHost`, `Landing.Step`, `Landing.Git`, `Landing.Plan`, `Landing.Dependencies`.

### `Landing.extractFailingLines`

`extractFailingLines(output: string, policy: FailurePolicy) -> { string }`

Extracts failure summaries from gate output.

### `Landing.runStep`

`runStep(step: Step, host: StepHost, policy: FailurePolicy) -> Refusal?`

Runs a named command through the host. Reports a failed command with an output tail and a log path.

### `Landing.isPrimaryCheckout`

`isPrimaryCheckout(commonDirOutput: string) -> boolean`

Checks whether the current checkout is the primary checkout.

### `Landing.findWorktreeForBranch`

`findWorktreeForBranch(porcelain: string, branch: string) -> (string?, string?)`

Finds the worktree that holds the named branch from Git worktree output.

### `Landing.classifyFastForward`

`classifyFastForward(result: CommandResult) -> FastForward`

Reads a merge command result. Returns `failed` on a nonzero exit, or `ok` with the parsed changed-file count.

### `Landing.mergeVerified`

`mergeVerified(branch: string, target: string, cwd: string?, deps: Dependencies, verifiedCandidate: string?) -> FastForward`

Fast-forwards a verified candidate and proves the resulting identity.

### `Landing.classifyConflict`

`classifyConflict(paths: { string }, policy: ConflictPolicy) -> ConflictClass`

Classifies a conflict against the registered conflict rules.

### `Landing.handAuthoredDetail`

`handAuthoredDetail(paths: { string }, policy: ConflictPolicy) -> string`

Builds the refusal detail for a conflict that needs a manual resolution.

### `Landing.shortSha`

`shortSha(sha: string) -> string`

Returns the short display form of a commit identity.

### `Landing.trainBranchName`

`trainBranchName(prefix: string, memberShas: { string }) -> string`

Builds the branch name for an integration train.

### `Landing.landOne`

`landOne(branch: string, deps: Dependencies) -> Outcome`

Lands one candidate through host setup, preparation, guard and verification. Requires a candidate worktree,
integrates serially and proves remote equality before cleanup.

### `Landing.landTrain`

`landTrain(branches: { string }, deps: Dependencies) -> Outcome`

Combines the supplied candidates as one integration. Runs the train checks and resets members when the train
aborts.

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

See the [executable contract](../extensions/luau/register-limit.verify.luau).

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

## Retention

A `Row` contains `path`, `group`, numeric `rank`, `retained`, `terminal` and `detail`.
A `Family` chooses `newest-per-group` or `retained-terminal`, with a category and reasons.
Each `Deletion` contains `path`, `category` and `reason`.
Equal ranks keep the lexicographically greatest path. Retained-terminal rows need both flags true to survive.
`plan` sorts combined deletions by path. It does not deduplicate rows.
`run("plan", ...)` changes nothing. `run("check", ...)` returns `retention_violation` if any deletion is planned.
Only `run("apply", ...)` calls `remove(paths)`. A nonzero exit returns `remove_failed:<exitcode>`.
Unknown modes return `usage`. Every outcome includes `deletions`; inspect `ok` before reading `reason`.
The host owns deletion authority and exception handling. A plan is not permission to delete originals.

```luau
local outcome = Retention.run("plan", families, remove)
assert(outcome.ok)
local deletions = outcome.deletions
```

See the [executable contract](../extensions/luau/retention.verify.luau).

Exported types: `Retention.Row`, `Retention.FamilyKind`, `Retention.Family`, `Retention.Deletion`, `Retention.Outcome`, `Retention.CommandResult`.

### `Retention.newestPerGroup`

`newestPerGroup(category: string, reason: string, rows: { Row }) -> { Deletion }`

Plans deletion of all rows except the newest row in each group. Breaks equal ranks by path.

### `Retention.retainedTerminal`

`retainedTerminal(category: string, supersededReason: string, nonTerminalReason: string, rows: { Row }) -> { Deletion }`

Plans deletion of superseded or nonterminal rows. A superseded reason takes priority over a nonterminal reason.

### `Retention.plan`

`plan(families: { Family }) -> { Deletion }`

Combines family deletion plans and sorts them by path.

### `Retention.run`

`run(mode: string, families: { Family }, remove: ({ string }) -> CommandResult) -> Outcome`

Runs `plan`, `check` or `apply`. Only `apply` invokes the supplied remove function. Returns a refusal for an
unknown mode or a failed remove command.

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

Run the [complete example](../examples/scoped-checks.luau).
See the [executable contract](../extensions/luau/scoped-checks.verify.luau).

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

See the [executable contract](../extensions/luau/silent-fallbacks.verify.luau).

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

See the [executable contract](../extensions/luau/source-scan.verify.luau).

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

See the [executable contract](../extensions/luau/worker-setup.verify.luau).

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
