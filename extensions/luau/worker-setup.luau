--!strict

export type StepStatus = "PASS" | "SKIP" | "WARN" | "FAIL"

export type StepOutcome = {
	name: string,
	status: StepStatus,
	detail: string,
}

export type Step = {
	name: string,
	run: (name: string) -> StepOutcome,
}

export type CommandResult = {
	exitcode: number,
	stdout: string,
	stderr: string,
}

export type Host = {
	run: (command: { string }, cwd: string?) -> CommandResult,
	exists: (path: string) -> boolean,
	modified: (path: string) -> number?,
	read: (path: string) -> string?,
	write: (path: string, contents: string) -> (),
	copy: (from: string, to: string) -> (),
	remove: (path: string) -> (),
	createDirectory: (path: string) -> (),
}

export type Input = {
	name: string,
	outputs: { string },
	sources: { string },
	regenerate: { string },
	copyFromReference: boolean?,
}

export type Lock = {
	path: string,
	marker: string,
	sync: { string },
}

export type Config = {
	base: string,
	reference: string?,
	directories: { string }?,
	lfs: boolean?,
	lock: Lock?,
	inputs: { Input },
	manifests: { pathspec: string, keep: { string } }?,
}

export type WorktreeSpec = {
	repo: string,
	path: string,
	branch: string,
	base: string,
}

export type Finding = {
	kind: "base_moved" | "lock_changed" | "lfs_pointer" | "input_missing" | "input_stale" | "stale_manifest",
	subject: string,
	detail: string,
	remedy: string,
}

local DIRTY_PATH_LIMIT = 10

local function firstLine(text: string): string
	local line = string.match(text, "^[^\n]*") or text
	return (string.gsub(line, "%s+$", ""))
end

local function detailOf(result: CommandResult): string
	return if result.stderr ~= "" then firstLine(result.stderr) else firstLine(result.stdout)
end

local function commandStep(name: string, command: { string }, run: ({ string }) -> CommandResult): StepOutcome
	local ok, result = pcall(run, command)
	if not ok then
		return { name = name, status = "FAIL", detail = tostring(result) }
	end
	local completed = result :: CommandResult
	if completed.exitcode ~= 0 then
		return { name = name, status = "FAIL", detail = ("exit %d: %s"):format(completed.exitcode, detailOf(completed)) }
	end
	return { name = name, status = "PASS", detail = firstLine(completed.stdout) }
end

local function directoryStep(path: string, exists: (string) -> boolean, create: (string) -> ()): StepOutcome
	if exists(path) then
		return { name = path, status = "SKIP", detail = "already exists" }
	end
	local ok, err = pcall(create, path)
	if not ok then
		return { name = path, status = "FAIL", detail = tostring(err) }
	end
	return { name = path, status = "PASS", detail = "created" }
end

local function dirtyPaths(statusOutput: string): { string }
	local paths: { string } = {}
	for line in string.gmatch(statusOutput, "[^\n]+") do
		local path = string.match(line, "^..%s+(.+)$")
		if path ~= nil then
			table.insert(paths, path)
		end
	end
	return paths
end

local function cleanTreeStep(name: string, result: CommandResult, warning: (string) -> string): StepOutcome
	if result.exitcode ~= 0 then
		return {
			name = name,
			status = "WARN",
			detail = ("git status is unavailable, so the tree is unproven: %s"):format(detailOf(result)),
		}
	end
	local paths = dirtyPaths(result.stdout)
	if #paths == 0 then
		return { name = name, status = "PASS", detail = "clean" }
	end
	local shown = paths
	if #paths > DIRTY_PATH_LIMIT then
		shown = table.move(paths, 1, DIRTY_PATH_LIMIT, 1, {})
		table.insert(shown, ("and %d more"):format(#paths - DIRTY_PATH_LIMIT))
	end
	return { name = name, status = "WARN", detail = warning(table.concat(shown, ", ")) }
end

local function runPlan(steps: { Step }): { StepOutcome }
	local outcomes: { StepOutcome } = {}
	for _, step in steps do
		table.insert(outcomes, step.run(step.name))
	end
	return outcomes
end

local function failureCount(outcomes: { StepOutcome }): number
	local failures = 0
	for _, outcome in outcomes do
		if outcome.status == "FAIL" then
			failures += 1
		end
	end
	return failures
end

local function trimmed(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

local function lines(text: string): { string }
	local out: { string } = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		table.insert(out, line)
	end
	return out
end

local function git(host: Host, arguments: { string }, cwd: string?): CommandResult
	local command: { string } = { "git" }
	for _, argument in arguments do
		table.insert(command, argument)
	end
	return host.run(command, cwd)
end

local function pathspecArguments(first: { string }, pathspecs: { string }): { string }
	local out = table.clone(first)
	table.insert(out, "--")
	for _, pathspec in pathspecs do
		table.insert(out, pathspec)
	end
	return out
end

local function dirname(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local function ensureWorktree(spec: WorktreeSpec, host: Host): StepOutcome
	local name = "worktree " .. spec.path
	if host.exists(spec.path .. "/.git") then
		local head = git(host, { "rev-parse", "--abbrev-ref", "HEAD" }, spec.path)
		local current = trimmed(head.stdout)
		if head.exitcode == 0 and current == spec.branch then
			return { name = name, status = "SKIP", detail = ("reused on branch %s"):format(spec.branch) }
		end
		return {
			name = name,
			status = "FAIL",
			detail = ("%s holds %s, not %s; choose another path or run git -C %s switch %s"):format(
				spec.path,
				if current == "" then "an unreadable HEAD" else current,
				spec.branch,
				spec.path,
				spec.branch
			),
		}
	end
	local exists = git(host, { "rev-parse", "--verify", "--quiet", "refs/heads/" .. spec.branch }, spec.repo)
	local command = if exists.exitcode == 0
		then { "worktree", "add", spec.path, spec.branch }
		else { "worktree", "add", "-b", spec.branch, spec.path, spec.base }
	local added = git(host, command, spec.repo)
	if added.exitcode ~= 0 then
		return {
			name = name,
			status = "FAIL",
			detail = ("git %s: %s"):format(table.concat(command, " "), detailOf(added)),
		}
	end
	return {
		name = name,
		status = "PASS",
		detail = if exists.exitcode == 0
			then ("created for existing branch %s"):format(spec.branch)
			else ("created on new branch %s from %s"):format(spec.branch, spec.base),
	}
end

local function lfsPointers(host: Host): ({ string }?, string?)
	local listed = git(host, { "lfs", "ls-files" })
	if listed.exitcode ~= 0 then
		return nil, detailOf(listed)
	end
	local pointers: { string } = {}
	for _, line in lines(listed.stdout) do
		local marker, path = string.match(line, "^%x+ ([%*%-]) (.+)$")
		if marker == "-" then
			table.insert(pointers, path :: string)
		end
	end
	return pointers, nil
end

local function lfsStep(name: string, host: Host): StepOutcome
	local pointers, problem = lfsPointers(host)
	if pointers == nil then
		return { name = name, status = "FAIL", detail = "git lfs ls-files: " .. (problem :: string) }
	end
	if #pointers == 0 then
		return { name = name, status = "SKIP", detail = "no LFS pointer files" }
	end
	local pulled = git(host, { "lfs", "pull" })
	if pulled.exitcode ~= 0 then
		return { name = name, status = "FAIL", detail = "git lfs pull: " .. detailOf(pulled) }
	end
	local remaining = lfsPointers(host)
	if remaining == nil or #remaining > 0 then
		return {
			name = name,
			status = "FAIL",
			detail = ("%d LFS file(s) are still pointers after git lfs pull"):format(
				if remaining then #remaining else 0
			),
		}
	end
	return { name = name, status = "PASS", detail = ("hydrated %d LFS file(s)"):format(#pointers) }
end

local function lockHash(lock: Lock, host: Host): string?
	local hashed = git(host, { "hash-object", lock.path })
	return if hashed.exitcode == 0 then trimmed(hashed.stdout) else nil
end

local function lockStale(lock: Lock, host: Host): string?
	local current = lockHash(lock, host)
	if current == nil then
		return nil
	end
	local recorded = host.read(lock.marker)
	if recorded ~= nil and trimmed(recorded) == current then
		return nil
	end
	return current
end

local function lockStep(name: string, lock: Lock, host: Host): StepOutcome
	local current = lockHash(lock, host)
	if current == nil then
		return { name = name, status = "FAIL", detail = "cannot hash " .. lock.path }
	end
	if lockStale(lock, host) == nil then
		return { name = name, status = "SKIP", detail = ("%s already synced"):format(lock.path) }
	end
	local synced = commandStep(name, lock.sync, function(command: { string }): CommandResult
		return host.run(command, nil)
	end)
	if synced.status == "PASS" then
		local directory = dirname(lock.marker)
		if directory ~= nil then
			host.createDirectory(directory)
		end
		host.write(lock.marker, current .. "\n")
	end
	return synced
end

local function newestSource(input: Input, host: Host): (string?, number)
	local listed = git(host, pathspecArguments({ "ls-files" }, input.sources))
	local newest: string? = nil
	local newestTime = 0
	for _, path in lines(listed.stdout) do
		local modified = host.modified(path)
		if modified ~= nil and modified > newestTime then
			newest, newestTime = path, modified
		end
	end
	return newest, newestTime
end

local function inputProblem(input: Input, host: Host): (("input_missing" | "input_stale")?, string?)
	local oldest: string? = nil
	local oldestTime = math.huge
	for _, output in input.outputs do
		local modified = if host.exists(output) then host.modified(output) else nil
		if modified == nil then
			return "input_missing", output .. " is absent"
		end
		if modified < oldestTime then
			oldest, oldestTime = output, modified
		end
	end
	if #input.sources == 0 then
		return nil, nil
	end
	local source, sourceTime = newestSource(input, host)
	if source ~= nil and sourceTime > oldestTime then
		return "input_stale", ("%s is older than source %s"):format(oldest :: string, source)
	end
	return nil, nil
end

local function sourceIdentity(input: Input, host: Host, repo: string?): string?
	local tree = git(host, pathspecArguments({ "ls-tree", "-r", "HEAD" }, input.sources), repo)
	local status = git(host, pathspecArguments({ "status", "--porcelain" }, input.sources), repo)
	if tree.exitcode ~= 0 or status.exitcode ~= 0 or trimmed(status.stdout) ~= "" or trimmed(tree.stdout) == "" then
		return nil
	end
	return tree.stdout
end

local function copyFromReference(input: Input, reference: string, host: Host): string?
	if #input.sources == 0 then
		return nil
	end
	local mine = sourceIdentity(input, host, nil)
	if mine == nil or mine ~= sourceIdentity(input, host, reference) then
		return nil
	end
	for _, output in input.outputs do
		if not host.exists(reference .. "/" .. output) then
			return nil
		end
	end
	for _, output in input.outputs do
		local directory = dirname(output)
		if directory ~= nil then
			host.createDirectory(directory)
		end
		host.copy(reference .. "/" .. output, output)
	end
	return reference
end

local function inputStep(input: Input, config: Config, host: Host): StepOutcome
	local problem = inputProblem(input, host)
	if problem == nil then
		return { name = input.name, status = "SKIP", detail = "fresh" }
	end
	if input.copyFromReference and config.reference ~= nil then
		local copied = copyFromReference(input, config.reference, host)
		if copied ~= nil then
			return { name = input.name, status = "PASS", detail = "copied from " .. copied .. " with identical sources" }
		end
	end
	local outcome = commandStep(input.name, input.regenerate, function(command: { string }): CommandResult
		return host.run(command, nil)
	end)
	if outcome.status == "PASS" then
		local stillBad, remainingProblem = inputProblem(input, host)
		if stillBad ~= nil then
			return {
				name = input.name,
				status = "FAIL",
				detail = "regeneration left the input unusable: " .. (remainingProblem :: string),
			}
		end
	end
	return outcome
end

local function staleManifests(config: Config, host: Host): { string }
	local manifests = config.manifests
	if manifests == nil then
		return {}
	end
	local listed = git(host, { "ls-files", "--others", "--ignored", "--exclude-standard", "--", manifests.pathspec })
	local keep: { [string]: boolean } = {}
	for _, path in manifests.keep do
		keep[path] = true
	end
	local stale: { string } = {}
	for _, path in lines(listed.stdout) do
		if not keep[path] and string.sub(path, -1) ~= "/" then
			table.insert(stale, path)
		end
	end
	return stale
end

local function manifestStep(config: Config, host: Host): StepOutcome
	local name = "stale generated manifests"
	local stale = staleManifests(config, host)
	if #stale == 0 then
		return { name = name, status = "SKIP", detail = "none" }
	end
	for _, path in stale do
		local ok, problem = pcall(host.remove, path)
		if not ok then
			return { name = name, status = "FAIL", detail = ("cannot remove %s: %s"):format(path, tostring(problem)) }
		end
	end
	return { name = name, status = "PASS", detail = "removed " .. table.concat(stale, ", ") }
end

local function prepareCheckout(config: Config, host: Host, after: { Step }): { StepOutcome }
	local steps: { Step } = {}
	for _, directory in config.directories or {} do
		table.insert(steps, {
			name = directory,
			run = function(name: string): StepOutcome
				return directoryStep(name, host.exists, host.createDirectory)
			end,
		})
	end
	if config.lfs then
		table.insert(steps, {
			name = "git lfs",
			run = function(name: string): StepOutcome
				return lfsStep(name, host)
			end,
		})
	end
	if config.lock ~= nil then
		local lock = config.lock :: Lock
		table.insert(steps, {
			name = "dependency sync",
			run = function(name: string): StepOutcome
				return lockStep(name, lock, host)
			end,
		})
	end
	for _, input in config.inputs do
		table.insert(steps, {
			name = input.name,
			run = function(): StepOutcome
				return inputStep(input, config, host)
			end,
		})
	end
	table.insert(steps, {
		name = "stale generated manifests",
		run = function(): StepOutcome
			return manifestStep(config, host)
		end,
	})
	for _, step in after do
		table.insert(steps, step)
	end
	return runPlan(steps)
end

local function freshness(config: Config, host: Host): { Finding }
	local findings: { Finding } = {}
	local behind = git(host, { "rev-list", "--count", "HEAD.." .. config.base })
	local count = if behind.exitcode == 0 then tonumber(trimmed(behind.stdout)) else nil
	if count == nil then
		local finding: Finding = {
			kind = "base_moved",
			subject = config.base,
			detail = "base ref cannot be read",
			remedy = ("create or fetch %s"):format(config.base),
		}
		table.insert(findings, finding)
	elseif count > 0 then
		local finding: Finding = {
			kind = "base_moved",
			subject = config.base,
			detail = ("%s has %d commit(s) this branch lacks"):format(config.base, count),
			remedy = ("git rebase %s, then rerun setup"):format(config.base),
		}
		table.insert(findings, finding)
	end
	if config.lock ~= nil then
		local lock = config.lock :: Lock
		if lockStale(lock, host) ~= nil then
			local finding: Finding = {
				kind = "lock_changed",
				subject = lock.path,
				detail = "dependency cache was not synced to the current lock",
				remedy = table.concat(lock.sync, " "),
			}
			table.insert(findings, finding)
		end
	end
	if config.lfs then
		local pointers: { string } = lfsPointers(host) or {}
		for _, path in pointers do
			local finding: Finding = {
				kind = "lfs_pointer",
				subject = path,
				detail = "file is an LFS pointer, not its content",
				remedy = "git lfs pull",
			}
			table.insert(findings, finding)
		end
	end
	for _, input in config.inputs do
		local kind, detail = inputProblem(input, host)
		if kind ~= nil then
			local finding: Finding = {
				kind = kind,
				subject = input.name,
				detail = detail :: string,
				remedy = table.concat(input.regenerate, " "),
			}
			table.insert(findings, finding)
		end
	end
	for _, path in staleManifests(config, host) do
		local finding: Finding = {
			kind = "stale_manifest",
			subject = path,
			detail = "generated manifest is not declared by the current sources",
			remedy = "delete it; setup removes it",
		}
		table.insert(findings, finding)
	end
	return findings
end

local function describeFinding(finding: Finding): string
	return ("STALE %s %s -- %s; fix: %s"):format(finding.kind, finding.subject, finding.detail, finding.remedy)
end

return {
	DIRTY_PATH_LIMIT = DIRTY_PATH_LIMIT,
	firstLine = firstLine,
	commandStep = commandStep,
	directoryStep = directoryStep,
	dirtyPaths = dirtyPaths,
	cleanTreeStep = cleanTreeStep,
	runPlan = runPlan,
	failureCount = failureCount,
	ensureWorktree = ensureWorktree,
	prepareCheckout = prepareCheckout,
	freshness = freshness,
	describeFinding = describeFinding,
}
