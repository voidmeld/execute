# Luau API

Require a module from `extensions/luau/<module>`. Each module returns the table described here.
The host supplies external operations. Types are exported from the same module.
The [extension guide](../extensions/luau/README.md) owns configuration and adoption.

## Commit policy

### `CommitPolicy.FIELD`

Field separator used by the commit log format and parser.

### `CommitPolicy.RECORD`

Record separator used by the commit log format and parser.

### `CommitPolicy.LOG_FORMAT`

Git log format that carries commit identity, author, committer and body for policy checks.

### `CommitPolicy.parseLog`

Parses formatted Git log output into commits. Returns a parse error when a record is malformed.

### `CommitPolicy.hasTrailer`

Checks whether a commit body contains an attribution trailer covered by the policy.

### `CommitPolicy.evaluate`

Checks commits against the supplied author, committer and trailer rules. Returns a policy verdict.

### `CommitPolicy.runRange`

Reads the candidate range through the supplied Git function, parses it and evaluates its commits.
Refuses unreadable or malformed logs.

## Guarded surface

### `GuardedSurface.sectionText`

Extracts a named Markdown section from supplied text.

### `GuardedSurface.withoutAsides`

Removes HTML asides before section content is inspected.

### `GuardedSurface.pathsFromSection`

Extracts the paths declared in a Markdown section.

### `GuardedSurface.matchedRule`

Finds the supplied surface rule that matches a path.

### `GuardedSurface.parseHunks`

Parses changed line ranges from a diff.

### `GuardedSurface.headingIndex`

Indexes Markdown headings for section checks.

### `GuardedSurface.headingAt`

Finds the heading that owns a line.

### `GuardedSurface.sectionsTouched`

Finds the sections affected by the changed line ranges.

### `GuardedSurface.offendingPaths`

Collects paths that violate the supplied surface rules.

### `GuardedSurface.evaluate`

Evaluates the acting identity and changed paths or sections against the supplied authority rules.

### `GuardedSurface.withOverride`

Applies an explicit override to a refusal. Returns a warning that identifies the bypassed refusal and banking result.

## Landing

### `Landing.refusal`

Constructs a refusal with a reason, detail and exit code.

### `Landing.attributed`

Adds branch attribution to a refusal.

### `Landing.extractFailingLines`

Extracts failure summaries from gate output.

### `Landing.runStep`

Runs a named command through the host. Reports a failed command with an output tail and a log path.

### `Landing.isPrimaryCheckout`

Checks whether the current checkout is the primary checkout.

### `Landing.findWorktreeForBranch`

Finds the worktree that holds the named branch from Git worktree output.

### `Landing.classifyFastForward`

Classifies base movement against the paths touched by the verified candidate.

### `Landing.mergeVerified`

Fast-forwards a verified candidate and proves the resulting identity.

### `Landing.classifyConflict`

Classifies a conflict against the registered conflict rules.

### `Landing.handAuthoredDetail`

Builds the refusal detail for a conflict that needs a manual resolution.

### `Landing.shortSha`

Returns the short display form of a commit identity.

### `Landing.trainBranchName`

Builds the branch name for an integration train.

### `Landing.trainGuidance`

Builds recovery guidance for a refused train.

### `Landing.landOne`

Lands one candidate through host setup, preparation, guard and verification.
Requires a candidate worktree, integrates serially and proves remote equality before cleanup.

### `Landing.landTrain`

Combines the supplied candidates as one integration. Runs the train checks and resets members when the train aborts.

## Retention

### `Retention.newestPerGroup`

Plans deletion of all rows except the newest row in each group. Breaks equal ranks by path.

### `Retention.retainedTerminal`

Plans deletion of superseded or nonterminal rows. A superseded reason takes priority over a nonterminal reason.

### `Retention.plan`

Combines family deletion plans and sorts them by path.

### `Retention.run`

Runs `plan`, `check` or `apply`. Only `apply` invokes the supplied remove function.
Returns a refusal for an unknown mode or a failed remove command.

## Scoped checks

### `ScopedChecks.matches`

Checks a value against supplied Luau patterns.

### `ScopedChecks.touched`

Finds the groups that own changed paths.

### `ScopedChecks.unowned`

Finds changed paths that no supplied group owns.

### `ScopedChecks.select`

Selects owning groups, matching specifications and distinct commands for the changed paths and optional selection.

## Worker setup

### `WorkerSetup.DIRTY_PATH_LIMIT`

Maximum number of dirty paths shown before the warning reports the remaining count.

### `WorkerSetup.firstLine`

Returns the first line of text with trailing whitespace removed.

### `WorkerSetup.commandStep`

Runs a command through the supplied function. Converts process failures and thrown errors into step outcomes.

### `WorkerSetup.directoryStep`

Creates a missing directory through the supplied functions. Skips an existing directory and reports creation errors.

### `WorkerSetup.dirtyPaths`

Extracts paths from Git porcelain status output.

### `WorkerSetup.cleanTreeStep`

Reports a clean checkout or a warning with dirty paths. An unreadable status is a warning, not proof of cleanliness.

### `WorkerSetup.failureCount`

Counts outcomes whose status is `FAIL`.

### `WorkerSetup.ensureWorktree`

Creates or reuses the declared branch worktree. Refuses a path that holds a different branch.

### `WorkerSetup.prepareCheckout`

Creates directories, hydrates LFS, syncs changed dependencies and prepares declared generated inputs.
Removes undeclared generated manifests, then runs appended steps. Returns all step outcomes.

### `WorkerSetup.freshness`

Reports moved bases, unsynced locks, LFS pointers, missing or stale inputs and undeclared generated manifests.
Changes no files.

### `WorkerSetup.describeFinding`

Formats a freshness finding with its subject, detail and remedy.
