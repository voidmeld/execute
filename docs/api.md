# API reference

This reference describes the public API of each Luau module, including what each call accepts,
what it returns, and how it can fail. The public-surface check requires an entry here for every
exported member and type.

| Task | Reference |
| --- | --- |
| Find calls, arguments, and member references in Luau source | [Call scanner](#call-scanner) |
| Queue, watch and land parallel worktrees | [Lanes](#lanes) |
| Choose which checks to run for changed files | [Scoped checks](#scoped-checks) |
| Check that the modules you ship fit within the compiler's register limit | [Register limit](#register-limit) |
| Compare silent fallbacks with a reviewed allowlist | [Silent fallbacks](#silent-fallbacks) |
| List source files and match findings against an allowlist | [Source scan](#source-scan) |
| Prepare an isolated checkout | [Worker setup](#worker-setup) |

## Shared setup

The examples use the `execute` alias from the [package install instructions](../README.md#optional-package-install).

```luau
local CallScanner = require("@execute/extensions/luau/call-scanner")
local Lanes = require("@execute/extensions/luau/lanes")
local ScopedChecks = require("@execute/extensions/luau/scoped-checks")
local RegisterLimit = require("@execute/extensions/luau/register-limit")
local SilentFallbacks = require("@execute/extensions/luau/silent-fallbacks")
local SourceScan = require("@execute/extensions/luau/source-scan")
local WorkerSetup = require("@execute/extensions/luau/worker-setup")
```

Your code supplies the configuration and any functions that work with Git, the filesystem, the clock,
or other processes. Before calling those functions, check what your project allows.
Each type in a signature belongs to that module. A `CommandResult` contains `exitcode`, `stdout`, and `stderr`.

Inspect each call's verdict or result before you continue. If a host function throws an error, it reaches
the caller unless the entry below says the module catches it. An invalid Luau pattern can also raise an error.
Selecting checks only lists them. Your code runs them separately.

For a complete example, run `lute run examples/scoped-checks.luau` in the Execute source checkout.
You'll also find a specification alongside each module there.

## Call scanner

The scanner works on the source text without parsing Luau. It skips quoted strings, long brackets, and
comments. Positions count bytes from the start of the source, with the first byte at position 1.

To find calls, pass `findCalls` a prefix such as `:Mark(`. The prefix consists of `:` or `.`, the name, and `(`.
For each call, you get its `start` and `stop` positions and the text of each top-level argument.
The scanner skips function declarations with that name.

To find uses of `.name`, call `findReferences`. It skips declarations and operands of type queries.
Use `wholeCall` to get the arguments when the entire expression is a single call.
Your code decides what to do with the matches.

```luau
for _, call in CallScanner.findCalls(source, ":Mark(") do
	local line = CallScanner.lineOf(source, call.start)
end
```

In the Execute source checkout, see `extensions/luau/call-scanner.verify.luau` for the executable specification.

This module exports the type `CallScanner.Call`.

### `CallScanner.skipQuoted`

`skipQuoted(source: string, index: number) -> number`

Starting at the opening quote at `index`, `skipQuoted` returns the position just after the closing quote.
If the string never closes, it returns the position just past the end of the source.

### `CallScanner.skipLong`

`skipLong(source: string, index: number) -> number?`

If a long bracket starts at `index`, `skipLong` returns the position just after the bracketed text.
Otherwise it returns `nil`.

### `CallScanner.skipComment`

`skipComment(source: string, index: number) -> number`

`skipComment` returns the position just after the line or block comment that starts at `index`.

### `CallScanner.literalBytes`

`literalBytes(body: string) -> number`

`literalBytes` counts the bytes in the string after interpreting the escape sequences in `body`.

### `CallScanner.splitTop`

`splitTop(text: string) -> { string }`

`splitTop` splits the arguments at commas outside quotes and brackets. For example, the comma in `f(a, b)` stays inside that argument.

### `CallScanner.topLevel`

`topLevel(expression: string) -> string`

`topLevel` keeps the top-level operators, drops nested text, and replaces each top-level quoted string with `S`.

### `CallScanner.wholeCall`

`wholeCall(expression: string, prefix: string) -> { string }?`

If the whole expression is one call beginning with `prefix`, the function returns the text of each argument.
Otherwise it returns `nil`.

### `CallScanner.functionDefinitions`

`functionDefinitions(source: string) -> { [number]: boolean }`

`functionDefinitions` marks the positions of `.` and `:` in function declaration names.

### `CallScanner.findCalls`

`findCalls(source: string, needle: string) -> { Call }`

`findCalls` finds calls matching `needle` outside strings and comments.

### `CallScanner.findReferences`

`findReferences(source: string, member: string) -> { number }`

`findReferences` lists the positions of `.member` outside strings and comments. It skips declarations and operands of type queries.

### `CallScanner.lineOf`

`lineOf(source: string, position: number) -> number`

`lineOf` returns the number of the line containing the given byte position.

## Lanes

A lane is a coding agent working on its own Git branch in a linked worktree. Anyone with read access
to the report files and processes can check their progress. To land a lane, take over its idle
worktree after review. Use the landing procedure in projects that authorize direct pushes to their
main branch. The project decides who may push, control peer processes, and release.

For a lane that researches the domain and prepares review questions, use the
[expertise lane brief](expertise-lane.md).

### `Lanes.classify`

`classify(lane: Observation, now: number, capSeconds: number) -> Status`

Pass one `Lanes.Observation` per lane. Supply its start time in seconds, whether its report file exists
(`reported`), and whether its process is still `alive`. Use the same clock for `startedAt` and `now`
and a positive time cap. This function only reads its arguments. It returns a `Lanes.Status` using
the first matching row.

| What you observe | Status |
| --- | --- |
| The report file exists | `reported` |
| The process has exited | `exited without a report` |
| Elapsed time has reached the cap | `over the cap` |
| The process is still within its time cap | `running` |

On hosts with `ps`, the supervision command reads the clock, checks the recorded PIDs and looks for
a report file in each worktree. Supply the cap in seconds, then five arguments for each lane.
Use a Unix timestamp for the start time and a report path unique to this run. An absolute report
path also works.

```sh
lute run tools/supervise-lanes.luau 3600 docs ../docs-lane "$started_at" report.txt "$pid"
```

The command prints the lane name, status and worktree on one line per lane. All four statuses are
normal output. Invalid arguments or a failed process inspection make the command exit with an error.

### `Lanes.selectStarts`

`selectStarts(pending: { Pending }, known: { [string]: boolean }, slots: number) -> { Pending }`

Give each `Lanes.Pending` entry a unique `name` and the path to its `brief` file. In `known`, set
a lane's name to `true` while its process is alive and to `false` after it exits. Every live lane
uses one slot, including lanes outside the queue. The function returns the first pending entries
that have never started, up to the number of free slots. It leaves both inputs alone. Duplicate
queue names, empty names or briefs, and negative or fractional slot limits raise an error.

### `Lanes.runTick`

`runTick(queue: Queue, runs: { Run }, host: QueueHost) -> ()`

To run one tick from a scheduler on a host with `ps`, give the command a slot limit, a cap in
seconds, a queue file, a state file and your project's launcher. Run it from the project root
with `execute_dir` set to the Execute checkout or installed package directory.
For example, this queue has two rows with a tab between each name and its brief path.

```sh
printf 'docs\tbriefs/docs.md\napi\tbriefs/api.md\n' > queue.tsv
lute run "$execute_dir/tools/tick-lanes.luau" 2 3600 queue.tsv runs.tsv ./start-lane
```

The command appends the name and brief path to the launcher's arguments. The launcher starts one
worker, redirects its streams, and prints its PID, a tab and its report path on one line. Give each
run its own report path, relative to the project root or absolute. A nonzero exit means the launch
failed and left no worker running.

Repeat the same command to print new reports, exits without a report and cap overruns, then fill
free slots. Each output line contains the name, status and report path. For a start, it contains
the name, `started` and the brief path. A live worker still occupies its slot after it reports or
reaches the cap. Use zero slots and omit the launcher to watch existing runs.

The command creates the state file as needed. It saves each launch before starting the next lane.
It remembers each status, so a late report prints once even after an exit. A run keeps its name in
the state file after it finishes. Use a new name for a new run. To include a worker already running,
add a tab-separated row while the scheduler is idle. The columns are name, Unix start time, PID,
absolute report path and last status (initially `running`). A dash in the PID column records an exit.
Use a separate state file for each queue and keep tabs and newlines out of names and paths.

Overlapping ticks use the same `.lock` directory beside the state file. If an interruption leaves
the lock, first confirm the tick has stopped. Its `starting` file names any launch in progress.
Check whether that worker started and add its row if missing, then remove the lock directory and
rerun the command. A launcher that returns an invalid result also leaves the lock for recovery.

In Luau, supply `pending`, `slots`, `capSeconds` and the launcher's argument array (`start`) in
`Lanes.Queue`. Pass the last saved list of `Lanes.Run` records, or an empty list on the first tick.
Each record holds `name`, `startedAt`, `pid`, `report` and `status`. An exited worker has a nil PID.
The caller runs one tick at a time against that list.

Inside a Git checkout the tick also runs [lane hygiene](#laneshygiene) under its lock before
starting workers. Set `EXECUTE_TRUNK` (default `main`) and `EXECUTE_LANES_ROOT` (default the
checkout path followed by `-worktrees`). The POSIX host uses Git with `merge-tree --write-tree`,
`realpath`, `lsof`, `ps` and `mktemp`. Standalone queues outside Git still supervise their workers.

| Function in `Lanes.QueueHost` | What the project supplies |
| --- | --- |
| `now()` | Return the current time in seconds. |
| `alive(pid)`, `reported(file)` | Check whether the recorded worker is alive and whether the report file exists. |
| `start(command)` | Start one lane with the supplied argument array and return its PID and unique report path. |
| `save(runs)` | Persist the whole list before returning. The tick saves observed changes and each successful start. |
| `notify(name, status, detail)` | Deliver a status line. An interruption between notification and saving can repeat it on retry. |

### `Lanes.hygiene`

`hygiene(config: Hygiene, host: HygieneHost) -> ()`

Pass the coordinating checkout (`repo`), local branch name (`trunk`) and managed directory
(`lanesRoot`) in `Lanes.Hygiene`. If a lane uses a fixed checkout for its branch, supply
`lanePath(branch)` returning its absolute path or nil for other branches. The tick resolves
symlinks on the configured path and Git's path so a temporarily detached lane still counts
as having a worktree. It checks the idle branch tip even while the checkout is detached.
List absolute directories owned by other tools in `extraManagedRoots`. The tick leaves those
checkouts and their cleanup to their owner. A stale registration in one of these roots defers
Git's repository-wide worktree prune. On a live tick the pass fetches all remotes with pruning.
Set `dryRun = true` to preview cleanup using the current refs.
It checks each idle tip against the local trunk commit. A tip has landed if trunk contains it or
a conflict-free merge would reproduce trunk's exact tree, including after a squash landing.

Each `UNLANDED <lane> <commits> <age>` gives the local branch name (checkout path for a detached
HEAD), the number of commits outside trunk's history and the age of the tip in seconds. A
`DIRTY` line identifies pending worktree changes, which can give an idle lane a zero commit count.
The tick repeats findings until they clear. `REMOTE`, `NO_WORKTREE` and `STRAY` name nontrunk
remote branches, unattached local branches and linked checkouts outside the lanes root.

Only idle, clean, branch-bearing lane worktrees inside the resolved root qualify for removal.
The coordinating and primary checkouts, trunk, locks and parents of registered worktrees are
protected. The pass rechecks the checkout and worker before unforced removal, then deletes the
branch conditional on its inspected tip. A failed command prints `HYGIENE ERROR` with its reason.
Review any remaining branch on the next tick. Dry runs print `WOULD REMOVE` and skip mutations.

Supply `run(argv, cwd)`, `canonical(path)`, `busy(path, branch, refresh)`, `now()` and
`notify(line)` in `Lanes.HygieneHost`. Git output must preserve NULs, newlines and exit codes.
Resolve directory aliases, check worker ownership (including workers outside the queue), and
refresh the process census when requested. The packaged `tools/lib/lane-hygiene-host.luau`
adapter takes the config, a live lane-name predicate and an output function. It checks working
directories, open files and command lines, resolving `-C` and `--cd` paths against each process's
working directory. A temporary Git repository uses the built-in merge
rules to compare content independently of the adopter's custom merge drivers.
Custom schedulers can use the optional `QueueHost.hygiene(known)` callback or invoke the pass
directly while holding their tick lock.

### `Lanes.land`

`land(lane: Landing, host: Host) -> string`

In `Lanes.Landing`, supply the coordinating checkout (`repo`), the lane's `worktree` and `branch`,
the Git `remote` and the name of its `main` branch. Supply `setup` and `check` as argument arrays.
List the PIDs of peer lanes your coordinator owns in `otherPids`. An empty list works for a single lane.

The project supplies these functions in `Lanes.Host`.

| Function | What the project supplies |
| --- | --- |
| `run(command, cwd)` | Run the argument array in the given directory and return a `WorkerSetup.CommandResult`. |
| `releaseRunning()` | Return whether the project's release is in progress. |
| `waitForPoll()` | Wait until it is time to check again. |
| `pause(pid)` | Pause that peer and return a function that resumes the same process. Return `nil` if it has exited or was already paused. Check ownership and identity before signaling a process. Raise an error if the pause fails and leave the peer as you found it. |

To pause other work during the check, set `pausePatterns` to Luau patterns for peer command lines.
Supply `polling` in the host with these two functions from `Lanes.PeerPolling`.

| Function | What the project supplies |
| --- | --- |
| `processes()` | List the peers this coordinator owns and may pause, each with a `pid` and a `command` string. Exclude the coordinator, the check and its children. |
| `startCheck(command, cwd)` | Start the check once and return a function that waits up to the given number of seconds for its exit. Return `nil` on timeout or the command result on exit. If a host error ends the wait, finish or stop the check before raising it. |

The coordinator pauses matches before starting the check. Every three seconds while the check
runs, it asks for the list again and pauses matching newcomers. If a later scan or pause fails,
it waits for the check to finish, resumes the peers it paused and reports the error.

The coordinator waits for the current release to finish, then fetches the remote main branch and
rebases the lane onto it. On a rebase conflict it runs `git rebase --abort` and reports the error.
Setup runs in the lane. The coordinator pauses the peers for the check and calls every resume
function it acquired, even if another pause, the check, or a resume fails. A resume error identifies
the PID that needs attention.

Setup and checks must leave the same commit and a clean worktree. Once the check and resumes
succeed, the coordinator pushes that exact commit to the remote main branch with an ordinary
fast-forward push. If the push fails, the worktree and branch stay available. If main advanced,
run the landing procedure again to rebase and check the new commit.

After a successful push, the coordinator removes the worktree and deletes the lane branch only if
it still points to the checked commit. If you supply a `release` argument array, the coordinator
runs it from `repo` with the pushed commit ID appended. The release command must release that revision.
The call returns its full commit ID on success. A cleanup or release error includes the ID already
pushed so you can finish that step separately.

For an example in the source checkout, see `examples/lanes.luau`.

## Register limit

In `Config`, supply a `label` for the report and the `roots` to search. Use Luau patterns in `include`
and `exclude` to select files by path. You also supply `compile(source)`, which must throw an error if compilation fails.

The module adds `UNOPTIMIZED` to the start of each source file so the compiler can't optimize away
registers the module needs. If a file fails to compile, `check` reports the error and keeps checking
the remaining files. It returns zero only if every file compiles.

```luau
local files = RegisterLimit.shipped(config, host)
local code = RegisterLimit.check(files, host.read, config, print)
```

In the Execute source checkout, see `extensions/luau/register-limit.verify.luau` for the executable specification.

This module exports the type `RegisterLimit.Config`.

### `RegisterLimit.UNOPTIMIZED`

This constant holds the text that disables compiler optimization when added to the start of a source file.

### `RegisterLimit.shipped`

`shipped(config: Config, host: SourceScan.Host) -> { string }`

`shipped` returns files under the roots in path order. Each path must match an `include` pattern and none
of the `exclude` patterns. The search skips missing roots.

### `RegisterLimit.check`

`check(files: { string }, read: (string) -> string, config: Config, report: (string) -> ()) -> number`

`check` calls `config.compile` for each file. For each failure it reports `<label>: FAIL <path>: <first line>`.
It also reports a summary and returns 1 if any file failed to compile.

## Scoped checks

Each `Group` has a `name`, Luau patterns in `paths` and `specs`, and commands in `checks`.
When a changed path matches a group, `select` includes that group and its commands. It includes matching
specifications from the group if they also pass the optional `keep` filter.

In the returned `Selection`, `groups` lists the matching groups in declaration order, `specs` lists the
selected specifications in sorted order, and `checks` contains the selected command arrays.
The first element of each command identifies it. If several commands share that element, only the first
is selected. Give distinct checks different first elements.

If nothing matches, the lists are empty. Selecting checks never runs a command or fails because a path
has no group. Call `unowned` separately to get those paths in their original order.

```luau
local selected = ScopedChecks.select(changedPaths, groups, candidateSpecs)
assert(#ScopedChecks.unowned(changedPaths, groups) == 0)
```

For the complete example, run `lute run examples/scoped-checks.luau` from the Execute source checkout.
The specification for this module is in `extensions/luau/scoped-checks.verify.luau` in that checkout.

This module exports the types `ScopedChecks.Group` and `ScopedChecks.Selection`.

### `ScopedChecks.matches`

`matches(path: string, patterns: { string }) -> boolean`

`matches` returns true if `path` matches any of the Luau patterns.

### `ScopedChecks.touched`

`touched(paths: { string }, groups: { Group }) -> { Group }`

`touched` returns the groups that match at least one changed path.

### `ScopedChecks.unowned`

`unowned(paths: { string }, groups: { Group }) -> { string }`

`unowned` returns the changed paths that don't match any of the supplied groups.

### `ScopedChecks.select`

`select(paths: { string }, groups: { Group }, candidateSpecs: { string }, keep: ((string, Group) -> boolean)?) -> Selection`

`select` returns the groups that match the changed paths, their matching specifications, and their distinct
commands. If you supply `keep`, it filters the specifications.

## Silent fallbacks

The check looks for three ways Luau code can silently substitute a value or ignore a result.

- `lookup-or-literal` flags a keyed lookup that falls back to a string literal.
- `discarded-pcall` flags a protected call whose result the code ignores.
- `display-empty-fallback` flags a display field that uses an empty string when a value is missing.

In `Config`, supply a report `label` and the names of the display fields in `displayFields`. Use `bestEffortWords`
to identify functions whose names mark them as best effort. Use `skipPaths` for patterns that match files
to skip and `teardownPaths` for patterns that match files where code may discard a protected call's result.

To allow a finding, give its `path`, `rule`, and `snippet` in an `Entry`. Set `disposition` to `authored`
or `pending` and give a `reason` of at least twenty characters. Your project supplies every entry and
every `Config` value.

The host supplies the `paths` to check and a `read` function. When `selected` is true, `check` considers
only entries under the specified `roots`. The check fails if an entry has an invalid reason or disposition,
if an entry matches nothing, or if a finding has no matching entry. The check prints pending entries.
A pending disposition on its own doesn't cause a failure.

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

In the Execute source checkout, see `extensions/luau/silent-fallbacks.verify.luau` for the executable specification.

This module exports the types `SilentFallbacks.Hit`, `SilentFallbacks.Entry`, `SilentFallbacks.Config`, `SilentFallbacks.File`, and `SilentFallbacks.Input`.

### `SilentFallbacks.normalize`

`normalize(text: string) -> string`

`normalize` collapses whitespace and limits the snippet to 160 bytes.

### `SilentFallbacks.lintFile`

`lintFile(path: string, contents: string, config: Config) -> { Hit }`

`lintFile` skips comment lines and returns findings for one file in line order.

### `SilentFallbacks.lint`

`lint(files: { File }, entries: { Entry }, config: Config) -> ({ Hit }, { Entry })`

The first list contains findings that no entry allows, sorted by path, line, and rule.
The second contains entries that didn't match any findings.

### `SilentFallbacks.unreasoned`

`unreasoned(entries: { Entry }) -> { Entry }`

`unreasoned` returns entries whose reason is too short or whose disposition is unknown.

### `SilentFallbacks.pending`

`pending(entries: { Entry }) -> { Entry }`

`pending` returns entries with the `pending` disposition.

### `SilentFallbacks.selectEntries`

`selectEntries(entries: { Entry }, roots: { string }, selected: boolean) -> { Entry }`

Pass `false` for `selected` to get every entry, or `true` to get only entries under the supplied roots.

### `SilentFallbacks.check`

`check(input: Input, report: (string) -> ()) -> number`

`check` validates the allowlist and scans the files. It reports failures and returns 1 if a check fails or 0 if all checks pass.

## Source scan

Your code supplies the roots and the allowlist. It also supplies a `Host` with `exists`, `kind`, and
`children` functions for inspecting paths. The scan handles the `kind` values `file` and `dir`
and skips paths of other kinds.

A root can be a file or a directory. For each root that exists, `collect` walks depth first, visits children
in name order, and includes files whose paths match the supplied Luau pattern. To compare findings with
the allowlist, give `reconcile` a function that produces a key for each finding and one that produces a
key for each entry. It reports findings and entries whose keys have no match.

```luau
local files = SourceScan.collect({ "src" }, host, "%.luau$")
```

In the Execute source checkout, see `extensions/luau/source-scan.verify.luau` for the executable specification.

This module exports the types `SourceScan.Host` and `SourceScan.Reconciled`.

### `SourceScan.normalize`

`normalize(text: string, limit: number) -> string`

`normalize` trims the text, replaces each remaining run of whitespace with one space, and limits the result to `limit` bytes.

### `SourceScan.inRoots`

`inRoots(path: string, roots: { string }) -> boolean`

`inRoots` returns true if `path` equals one of the roots or lies under it.

### `SourceScan.collect`

`collect(roots: { string }, host: Host, pattern: string) -> { string }`

`collect` returns the paths of files under `roots` that match `pattern`.

### `SourceScan.reconcile`

`reconcile<Hit, Entry>(hits: { Hit }, entries: { Entry }, hitKey: (Hit) -> string, entryKey: (Entry) -> string) -> Reconciled<Hit, Entry>`

`reconcile` returns the findings that no entry covers, in input order, and the entries that didn't match any findings.

## Worker setup

Each `StepOutcome` records the step's `name`, its `status` (`PASS`, `SKIP`, `WARN`, or `FAIL`), and
a `detail` explaining the result. The `Host` supplies the functions `run`, `exists`, `modified`, `read`,
`write`, `remove`, and `createDirectory`.

In `Config`, specify the `base` and `inputs`. The `directories`, `lfs`, `lock`, and `manifests` fields are
optional. Each `Input` lists its generated `outputs`, its tracked `sources`, and a `regenerate` command.
The outputs are up to date only if they all exist and none is older than a tracked source.

For a lock, supply the file's `path`, a `marker` where setup can record its hash, and the `sync` command.
After a successful sync, setup records the lock file's blob hash. Setup also removes undeclared generated
manifests that match the supplied pathspec.

If the command runner throws an error or returns a nonzero exit status, `commandStep` reports `FAIL`.
If a directory exists, `directoryStep` skips it. If creating it fails, the step reports `FAIL`.
When the worktree has changes or its status can't be read, `cleanTreeStep` reports `WARN`.
Only a successful status check can confirm that the worktree is clean.

The `ensureWorktree` function reuses a worktree only if it holds the specified branch. A different branch
or a failed Git operation results in `FAIL`. `prepareCheckout` returns a result for every step, starting with
the built-in steps and ending with any you added. Check `failureCount` before continuing.

To inspect the checkout without changing files, use `freshness`. Each finding has a `kind`, `subject`,
`detail`, and `remedy`. The `DIRTY_PATH_LIMIT` constant limits how many changed paths appear in a warning.
The `firstLine` function removes trailing whitespace from the first line of text.

```luau
local outcomes = WorkerSetup.prepareCheckout(config, host, {})
assert(WorkerSetup.failureCount(outcomes) == 0)
local findings = WorkerSetup.freshness(config, host)
```

In the Execute source checkout, see `extensions/luau/worker-setup.verify.luau` for the executable specification.

This module exports the types `WorkerSetup.StepStatus`, `WorkerSetup.StepOutcome`, `WorkerSetup.Step`, `WorkerSetup.CommandResult`, `WorkerSetup.Host`, `WorkerSetup.Input`, `WorkerSetup.Lock`, `WorkerSetup.Config`, `WorkerSetup.WorktreeSpec`, and `WorkerSetup.Finding`.

Use `Config` and `Input` to generate files locally. The API has no option to copy files from a reference checkout
and the host supplies no copy operation.

### `WorkerSetup.DIRTY_PATH_LIMIT`

This constant limits how many changed paths a warning lists. The warning gives a count for the rest.

### `WorkerSetup.firstLine`

`firstLine(text: string) -> string`

`firstLine` returns the first line of text with any trailing whitespace removed.

### `WorkerSetup.commandStep`

`commandStep(name: string, command: { string }, run: ({ string }) -> CommandResult) -> StepOutcome`

The supplied `run` function executes the command. If the process fails or `run` throws an error,
the step records the failure in its result.

### `WorkerSetup.directoryStep`

`directoryStep(path: string, exists: (string) -> boolean, create: (string) -> ()) -> StepOutcome`

The step uses the supplied functions to check whether the directory exists and create it if it's missing.
It skips an existing directory and reports any error during creation.

### `WorkerSetup.dirtyPaths`

`dirtyPaths(statusOutput: string) -> { string }`

`dirtyPaths` extracts the paths from Git's porcelain status output.

### `WorkerSetup.cleanTreeStep`

`cleanTreeStep(name: string, result: CommandResult, warning: (string) -> string) -> StepOutcome`

The step reports a clean checkout if Git confirms it. If the checkout has changes, it returns a warning
with the affected paths. If it can't read the status, it warns that the worktree's status is unknown.

### `WorkerSetup.failureCount`

`failureCount(outcomes: { StepOutcome }) -> number`

`failureCount` counts steps with status `FAIL`.

### `WorkerSetup.ensureWorktree`

`ensureWorktree(spec: WorktreeSpec, host: Host) -> StepOutcome`

`ensureWorktree` creates or reuses a worktree for the specified branch. It fails if the path holds another branch.

### `WorkerSetup.prepareCheckout`

`prepareCheckout(config: Config, host: Host, after: { Step }) -> { StepOutcome }`

`prepareCheckout` creates directories, downloads file contents for LFS pointers, syncs changed dependencies,
and regenerates missing or outdated inputs. After removing undeclared generated manifests, it runs the
steps in `after` and returns the results of all steps.

### `WorkerSetup.freshness`

`freshness(config: Config, host: Host) -> { Finding }`

`freshness` inspects the checkout without modifying files. It reports when the base has moved, dependencies
are out of sync with the lock file, LFS files still contain pointers, generated inputs are missing or out of
date, or generated manifests are undeclared.

### `WorkerSetup.describeFinding`

`describeFinding(finding: Finding) -> string`

`describeFinding` turns a finding into a message that names the subject, describes the problem, and explains how to fix it.
