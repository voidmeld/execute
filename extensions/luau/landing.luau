--!strict

export type CommandResult = {
	exitcode: number,
	stdout: string,
	stderr: string,
}

export type Refusal = {
	ok: false,
	reason: string,
	detail: string,
	failingLines: { string },
	member: string?,
	logPath: string?,
}

export type Success = {
	ok: true,
	sha: string,
	filesChanged: number,
}

export type Outcome = Refusal | Success

export type FastForward =
	{ status: "failed", detail: string }
	| { status: "unproven", detail: string }
	| { status: "ok", filesChanged: number }

export type Resolver = {
	resolve: (worktreePath: string) -> (boolean, string?),
	afterContinue: ((worktreePath: string) -> (boolean, string?))?,
	maxAttempts: number?,
}

export type ConflictPolicy = {
	resolvers: { [string]: Resolver },
	handAuthored: { [string]: string },
	maxIterations: number,
}

export type ConflictClass = "resolvable" | "hand_authored" | "real"

export type FailurePolicy = {
	maxLines: number,
	maxLineChars: number,
	patterns: { string },
}

export type StepHost = {
	run: (command: { string }, cwd: string) -> CommandResult,
	writeLog: (label: string, output: string) -> string?,
}

export type Step = {
	reason: string,
	label: string,
	command: { string },
	cwd: string,
}

export type Git = {
	commonDir: () -> CommandResult,
	branchRef: (branch: string) -> CommandResult,
	worktreeList: () -> CommandResult,
	worktreeAdd: (path: string, branch: string, startPoint: string) -> CommandResult,
	worktreeRemove: (path: string) -> CommandResult,
	branchDelete: (branch: string) -> CommandResult,
	rebase: (worktreePath: string, onto: string) -> CommandResult,
	rebaseContinue: (worktreePath: string) -> CommandResult,
	conflictedFiles: (worktreePath: string) -> CommandResult,
	add: (worktreePath: string, path: string) -> CommandResult,
	mergeFastForward: (branch: string, cwd: string?) -> CommandResult,
	resetHard: (worktreePath: string, sha: string) -> CommandResult,
	push: () -> CommandResult,
	fetch: () -> CommandResult,
	revParse: (ref: string) -> CommandResult,
}

export type Plan = {
	base: string,
	remote: string,
	trainRoot: string,
	trainBranchPrefix: string,
	conflicts: ConflictPolicy,
	failure: FailurePolicy,
	setup: (worktreePath: string) -> Refusal?,
	prepare: (worktreePath: string) -> Refusal?,
	commitGuard: (branch: string) -> Refusal?,
	verify: (worktreePath: string) -> Refusal?,
	changeGuard: (branch: string) -> Refusal?,
	log: (message: string) -> (),
}

export type Dependencies = {
	git: Git,
	plan: Plan,
}

local function trimmed(value: string): string
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function trimmedLines(value: string): { string }
	local out: { string } = {}
	for line in string.gmatch(value, "[^\r\n]+") do
		local candidate = trimmed(line)
		if candidate ~= "" then
			table.insert(out, candidate)
		end
	end
	return out
end

local function refusal(reason: string, detail: string, failingLines: { string }?): Refusal
	return { ok = false, reason = reason, detail = detail, failingLines = failingLines or {} }
end

local function attributed(reason: string, detail: string, member: string): Refusal
	return { ok = false, reason = reason, detail = detail, failingLines = {}, member = member }
end

local function extractFailingLines(output: string, policy: FailurePolicy): { string }
	local lines: { string } = {}
	for line in string.gmatch(output, "[^\r\n]+") do
		if #lines >= policy.maxLines then
			break
		end
		local matched = false
		for _, pattern in policy.patterns do
			if string.match(line, pattern) ~= nil then
				matched = true
				break
			end
		end
		if matched then
			table.insert(lines, if #line <= policy.maxLineChars then line else string.sub(line, 1, policy.maxLineChars))
		end
	end
	return lines
end

local function tailLines(output: string, policy: FailurePolicy): { string }
	local all: { string } = {}
	for line in string.gmatch(output, "[^\r\n]+") do
		table.insert(all, if #line <= policy.maxLineChars then line else string.sub(line, 1, policy.maxLineChars))
	end
	local tail: { string } = {}
	for index = math.max(1, #all - policy.maxLines + 1), #all do
		table.insert(tail, all[index])
	end
	return tail
end

local function runStep(step: Step, host: StepHost, policy: FailurePolicy): Refusal?
	local ran, outcome = pcall(host.run, step.command, step.cwd)
	local result: CommandResult = if ran then outcome else { exitcode = 1, stdout = "", stderr = tostring(outcome) }
	if result.exitcode == 0 then
		return nil
	end
	local output = result.stdout .. (if result.stderr == "" then "" else "\n" .. result.stderr)
	local failing = extractFailingLines(output, policy)
	local logPath = host.writeLog(step.label, output)
	local detail = ("%s: %s exited %d"):format(step.label, table.concat(step.command, " "), result.exitcode)
	if #failing > 0 then
		detail ..= "; failing: " .. table.concat(failing, " | ")
	else
		detail ..= "; last output: " .. table.concat(tailLines(output, policy), " | ")
	end
	detail ..= if logPath ~= nil then "; log: " .. logPath else "; no log could be written"
	return { ok = false, reason = step.reason, detail = detail, failingLines = failing, logPath = logPath }
end

local function isPrimaryCheckout(commonDirOutput: string): boolean
	return trimmed(commonDirOutput) == ".git"
end

local function findWorktreeForBranch(porcelain: string, branch: string): (string?, string?)
	local target = "branch refs/heads/" .. branch
	local currentPath: string? = nil
	for line in (porcelain .. "\n"):gmatch("([^\n]*)\n") do
		local candidate = string.match(line, "^(.-)\r?$") or line
		if candidate == "" then
			currentPath = nil
		else
			local path = string.match(candidate, "^worktree%s+(.+)$")
			if path ~= nil then
				currentPath = path
			elseif candidate == target and currentPath ~= nil then
				return currentPath, nil
			end
		end
	end
	return nil,
		(
			"no worktree in `git worktree list` carries refs/heads/%s; landing rebases, gates and"
			.. " fast-forward merges a candidate inside its own worktree. Check it out first with"
			.. " `git worktree add <path> %s`, then land again"
		):format(branch, branch)
end

local function classifyFastForward(result: CommandResult): FastForward
	if result.exitcode ~= 0 then
		local detail = result.stderr
		if detail == "" then
			detail = result.stdout
		end
		return { status = "failed", detail = detail }
	end
	local filesChanged = string.match(result.stdout, "(%d+) files? changed")
	return { status = "ok", filesChanged = tonumber(filesChanged or "0") :: number }
end

local function resolvedSha(result: CommandResult): string?
	local value = trimmed(result.stdout)
	return if result.exitcode == 0 and #value == 40 and string.match(value, "^%x+$") ~= nil then value else nil
end

local function mergeVerified(
	branch: string,
	target: string,
	cwd: string?,
	deps: Dependencies,
	verifiedCandidate: string?
): FastForward
	local candidate = resolvedSha(deps.git.revParse(branch))
	if candidate == nil or (verifiedCandidate ~= nil and candidate ~= verifiedCandidate) then
		return { status = "unproven", detail = "candidate commit is unresolved or changed after verification" }
	end
	local result = classifyFastForward(deps.git.mergeFastForward(branch, cwd))
	if result.status ~= "ok" then
		return result
	end
	local landed = resolvedSha(deps.git.revParse(target))
	local currentCandidate = resolvedSha(deps.git.revParse(branch))
	if landed ~= candidate or currentCandidate ~= candidate then
		return {
			status = "unproven",
			detail = "merge returned success but exact candidate and destination commits do not match; inspect local refs before any further mutation",
		}
	end
	return result
end

local function classifyConflict(paths: { string }, policy: ConflictPolicy): ConflictClass
	if #paths == 0 then
		return "real"
	end
	local allResolvable = true
	for _, path in paths do
		if policy.resolvers[path] == nil then
			allResolvable = false
			break
		end
	end
	if allResolvable then
		return "resolvable"
	end
	for _, path in paths do
		if policy.handAuthored[path] ~= nil then
			return "hand_authored"
		end
	end
	return "real"
end

local function handAuthoredDetail(paths: { string }, policy: ConflictPolicy): string
	local notes: { string } = {}
	local sorted = table.clone(paths)
	table.sort(sorted)
	for _, path in sorted do
		local note = policy.handAuthored[path]
		if note ~= nil then
			table.insert(notes, ("%s: %s"):format(path, note :: string))
		end
	end
	return table.concat(notes, "; ")
end

local function resolveConflicts(
	worktreePath: string,
	files: { string },
	deps: Dependencies
): (boolean, string?, string?, { string }?)
	local policy = deps.plan.conflicts
	local resolvedPaths: { [string]: boolean } = {}
	local attempts: { [string]: number } = {}
	local pending = files
	local iterations = 0
	while true do
		iterations += 1
		if iterations > policy.maxIterations then
			return false,
				"rebase_resolve_loop_exceeded",
				("conflict resolution in %s did not converge after %d rebase --continue cycles"):format(
					worktreePath,
					policy.maxIterations
				),
				nil
		end
		if #pending == 0 then
			return false, nil, nil, nil
		end
		for _, path in pending do
			if policy.resolvers[path] == nil then
				return false, nil, nil, nil
			end
		end
		local sorted = table.clone(pending)
		table.sort(sorted)
		deps.plan.log(("resolving conflicted paths in %s: %s"):format(worktreePath, table.concat(sorted, ", ")))
		local afterContinue: { (worktreePath: string) -> (boolean, string?) } = {}
		for _, path in sorted do
			local resolver = policy.resolvers[path] :: Resolver
			local attempt = (attempts[path] or 0) + 1
			attempts[path] = attempt
			if attempt > (resolver.maxAttempts or policy.maxIterations) then
				return false,
					"rebase_resolve_failed",
					("%s stayed conflicted in %s after its resolver ran %d time(s)"):format(
						path,
						worktreePath,
						attempt - 1
					),
					nil
			end
			local resolved, detail = resolver.resolve(worktreePath)
			if not resolved then
				return false, "rebase_resolve_failed", detail or ("could not resolve " .. path), nil
			end
			resolvedPaths[path] = true
			if deps.git.add(worktreePath, path).exitcode ~= 0 then
				return false, "rebase_resolve_failed", "git add " .. path .. " failed after resolving it", nil
			end
			if resolver.afterContinue ~= nil then
				table.insert(afterContinue, resolver.afterContinue :: (string) -> (boolean, string?))
			end
		end
		local continued = deps.git.rebaseContinue(worktreePath)
		if continued.exitcode == 0 then
			for _, hook in afterContinue do
				local ok, detail = hook(worktreePath)
				if not ok then
					return false, "rebase_resolve_failed", detail or "post-resolution repair failed", nil
				end
			end
			local sortedPaths: { string } = {}
			for path in resolvedPaths do
				table.insert(sortedPaths, path)
			end
			table.sort(sortedPaths)
			return true, nil, nil, sortedPaths
		end
		local conflicted = deps.git.conflictedFiles(worktreePath)
		local nextFiles: { string } = if conflicted.exitcode == 0 then trimmedLines(conflicted.stdout) else {}
		if #nextFiles == 0 then
			return false,
				"rebase_resolve_failed",
				("git rebase --continue in %s exited %d after resolving conflicts: %s"):format(
					worktreePath,
					continued.exitcode,
					if continued.stderr ~= "" then continued.stderr else continued.stdout
				),
				nil
		end
		local outside = false
		for _, path in nextFiles do
			if policy.resolvers[path] == nil then
				outside = true
				break
			end
		end
		if outside then
			table.sort(nextFiles)
			return false,
				"rebase_failed",
				("git rebase --continue in %s stopped again with unresolvable conflicts: %s"):format(
					worktreePath,
					table.concat(nextFiles, ", ")
				),
				nil
		end
		pending = nextFiles
	end
end

local function rebaseOnto(worktreePath: string, onto: string, deps: Dependencies): (Refusal?, { string }?)
	local rebased = deps.git.rebase(worktreePath, onto)
	if rebased.exitcode == 0 then
		return nil, nil
	end

	local conflicted = deps.git.conflictedFiles(worktreePath)
	local conflictedPaths: { string }? = nil
	if conflicted.exitcode == 0 then
		local files = trimmedLines(conflicted.stdout)
		if #files > 0 then
			conflictedPaths = files
		end
	end

	local classification: ConflictClass = "real"
	if conflictedPaths ~= nil then
		classification = classifyConflict(conflictedPaths :: { string }, deps.plan.conflicts)
		if classification == "resolvable" then
			local repaired, reason, detail, resolvedPaths =
				resolveConflicts(worktreePath, conflictedPaths :: { string }, deps)
			if repaired then
				return nil, resolvedPaths
			end
			if reason ~= nil then
				return refusal(reason :: string, detail :: string), nil
			end
		end
	end

	local conflictDetail = ""
	if conflictedPaths ~= nil then
		local sorted = table.clone(conflictedPaths :: { string })
		table.sort(sorted)
		conflictDetail = (" -- conflicting paths: %s"):format(table.concat(sorted, ", "))
		if classification == "hand_authored" then
			conflictDetail ..= " -- " .. handAuthoredDetail(conflictedPaths :: { string }, deps.plan.conflicts)
		end
	end
	return refusal(
		"rebase_failed",
		(
			"git rebase %s in %s exited %d; resolve the conflict in the worktree and rerun (a branch cut from a"
			.. " candidate that was later squashed needs git rebase --onto %s <old candidate tip>): %s%s"
		):format(
			onto,
			worktreePath,
			rebased.exitcode,
			onto,
			(if rebased.stderr ~= "" then rebased.stderr else rebased.stdout),
			conflictDetail
		)
	),
		nil
end

local function requirePrimary(deps: Dependencies): Refusal?
	deps.plan.log("verifying the working directory is the primary checkout")
	local commonDir = deps.git.commonDir()
	if commonDir.exitcode ~= 0 then
		return refusal(
			"git_common_dir_failed",
			"git rev-parse --git-common-dir exited " .. tostring(commonDir.exitcode)
		)
	end
	if not isPrimaryCheckout(commonDir.stdout) then
		return refusal(
			"not_primary_checkout",
			(
				"landing must run with the working directory at the primary checkout, not a worktree;"
				.. ' git rev-parse --git-common-dir resolved to %q instead of ".git", and a'
				.. " fast-forward merge run inside a worktree silently no-ops"
			):format(trimmed(commonDir.stdout))
		)
	end
	deps.plan.log("PASS primary checkout")
	return nil
end

local function pushAndVerify(deps: Dependencies): (string?, Refusal?)
	local base = deps.plan.base
	local tracking = deps.plan.remote .. "/" .. base
	deps.plan.log(("pushing %s %s"):format(deps.plan.remote, base))
	local pushed = deps.git.push()
	if pushed.exitcode ~= 0 then
		return nil, refusal("push_failed", ("git push %s %s exited %d"):format(deps.plan.remote, base, pushed.exitcode))
	end
	local fetched = deps.git.fetch()
	if fetched.exitcode ~= 0 then
		return nil,
			refusal("fetch_failed", ("git fetch %s %s exited %d"):format(deps.plan.remote, base, fetched.exitcode))
	end
	local localSha = resolvedSha(deps.git.revParse(base))
	local remoteSha = resolvedSha(deps.git.revParse(tracking))
	if localSha == nil or remoteSha == nil or localSha ~= remoteSha then
		return nil,
			refusal(
				"remote_mismatch",
				("%s=%s %s=%s did not match after push and fetch"):format(
					base,
					tostring(localSha),
					tracking,
					tostring(remoteSha)
				)
			)
	end
	deps.plan.log(("PASS pushed and verified remote equality at %s"):format(localSha))
	return localSha, nil
end

local function cleanupOne(worktreePath: string, branch: string, sha: string, deps: Dependencies): Refusal?
	local removed = deps.git.worktreeRemove(worktreePath)
	if removed.exitcode ~= 0 then
		return refusal(
			"worktree_remove_failed",
			("%s is integrated and pushed at %s, but git worktree remove --force %s exited %d; remove" .. " it by hand"):format(
				deps.plan.base,
				sha,
				worktreePath,
				removed.exitcode
			)
		)
	end
	local deleted = deps.git.branchDelete(branch)
	if deleted.exitcode ~= 0 then
		return refusal(
			"branch_delete_failed",
			(
				"%s is integrated and pushed at %s, and the worktree is gone, but git branch -D %s exited"
				.. " %d; delete it by hand"
			):format(deps.plan.base, sha, branch, deleted.exitcode)
		)
	end
	return nil
end

local function shortSha(sha: string): string
	return string.sub(trimmed(sha), 1, 7)
end

local function trainBranchName(prefix: string, memberShas: { string }): string
	local shorts: { string } = {}
	for _, sha in memberShas do
		table.insert(shorts, shortSha(sha))
	end
	return prefix .. table.concat(shorts, "-")
end

local function trainGuidance(trainBranch: string, trainPath: string, branches: { string }, culprit: string?): string
	if culprit ~= nil then
		return (" -- bisect member %s; train %s at %s was reset and removed, each member restored to its own head"):format(
			culprit :: string,
			trainBranch,
			trainPath
		)
	end
	return (" -- bisect across train %s members [%s] at %s was reset and removed, each member restored to its own head"):format(
		trainBranch,
		table.concat(branches, ", "),
		trainPath
	)
end

local function abortTrain(
	trainPath: string,
	trainBranch: string,
	memberPaths: { string },
	memberShas: { string },
	deps: Dependencies
)
	for index, memberPath in memberPaths do
		local sha = memberShas[index]
		local reset = deps.git.resetHard(memberPath, sha)
		if reset.exitcode ~= 0 then
			deps.plan.log(
				("bisect cleanup: git reset --hard %s in %s exited %d; restore it by hand"):format(
					sha,
					memberPath,
					reset.exitcode
				)
			)
		end
	end
	local removed = deps.git.worktreeRemove(trainPath)
	if removed.exitcode ~= 0 then
		deps.plan.log(
			("bisect cleanup: git worktree remove --force %s exited %d; remove it by hand"):format(
				trainPath,
				removed.exitcode
			)
		)
	end
	local deleted = deps.git.branchDelete(trainBranch)
	if deleted.exitcode ~= 0 then
		deps.plan.log(
			("bisect cleanup: git branch -D %s exited %d; delete it by hand"):format(trainBranch, deleted.exitcode)
		)
	end
end

local function logRebase(deps: Dependencies, label: string, resolvedPaths: { string }?)
	if resolvedPaths ~= nil and #(resolvedPaths :: { string }) > 0 then
		deps.plan.log(("PASS rebase %s resolved=%s"):format(label, table.concat(resolvedPaths :: { string }, ",")))
	else
		deps.plan.log("PASS rebase " .. label)
	end
end

local function landOne(branch: string, deps: Dependencies): Outcome
	local plan = deps.plan
	local primaryRefusal = requirePrimary(deps)
	if primaryRefusal ~= nil then
		return primaryRefusal :: Refusal
	end

	plan.log(("verifying branch %s exists"):format(branch))
	if deps.git.branchRef(branch).exitcode ~= 0 then
		return refusal("branch_missing", ("refs/heads/%s does not exist"):format(branch))
	end
	plan.log("PASS branch exists")

	plan.log("resolving the branch's worktree path")
	local worktrees = deps.git.worktreeList()
	if worktrees.exitcode ~= 0 then
		return refusal("worktree_list_failed", "git worktree list --porcelain exited " .. tostring(worktrees.exitcode))
	end
	local worktreePath, notFound = findWorktreeForBranch(worktrees.stdout, branch)
	if worktreePath == nil then
		return refusal("worktree_missing", notFound :: string)
	end
	plan.log(("PASS worktree=%s"):format(worktreePath :: string))

	plan.log(("rebasing %s onto %s inside %s"):format(branch, plan.base, worktreePath :: string))
	local rebaseRefusal, resolvedPaths = rebaseOnto(worktreePath :: string, plan.base, deps)
	if rebaseRefusal ~= nil then
		return rebaseRefusal :: Refusal
	end
	logRebase(deps, branch, resolvedPaths)

	local prepareRefusal = plan.prepare(worktreePath :: string)
	if prepareRefusal ~= nil then
		return prepareRefusal :: Refusal
	end

	local commitRefusal = plan.commitGuard(branch)
	if commitRefusal ~= nil then
		return commitRefusal :: Refusal
	end

	local verifiedCandidate = resolvedSha(deps.git.revParse(branch))
	if verifiedCandidate == nil then
		return refusal("candidate_unresolved", "candidate commit could not be resolved before verification")
	end
	local verifyRefusal = plan.verify(worktreePath :: string)
	if verifyRefusal ~= nil then
		return verifyRefusal :: Refusal
	end

	local changeRefusal = plan.changeGuard(branch)
	if changeRefusal ~= nil then
		return changeRefusal :: Refusal
	end

	plan.log(("fast-forward merging %s from the primary checkout"):format(branch))
	local classified = mergeVerified(branch, plan.base, nil, deps, verifiedCandidate)
	if classified.status ~= "ok" then
		return refusal("merge_" .. classified.status, classified.detail)
	end
	plan.log(("PASS merge files_changed=%d"):format(classified.filesChanged))

	local sha, pushRefusal = pushAndVerify(deps)
	if pushRefusal ~= nil then
		return pushRefusal :: Refusal
	end

	plan.log(("cleaning up worktree %s and branch %s"):format(worktreePath :: string, branch))
	local cleanupRefusal = cleanupOne(worktreePath :: string, branch, sha :: string, deps)
	if cleanupRefusal ~= nil then
		return cleanupRefusal :: Refusal
	end
	plan.log("PASS cleanup")

	return { ok = true, sha = sha :: string, filesChanged = classified.filesChanged }
end

local function landTrain(branches: { string }, deps: Dependencies): Outcome
	local plan = deps.plan
	local primaryRefusal = requirePrimary(deps)
	if primaryRefusal ~= nil then
		return primaryRefusal :: Refusal
	end

	plan.log(("resolving worktree paths for %d train members"):format(#branches))
	local worktrees = deps.git.worktreeList()
	if worktrees.exitcode ~= 0 then
		return refusal("worktree_list_failed", "git worktree list --porcelain exited " .. tostring(worktrees.exitcode))
	end

	local memberPaths: { string } = {}
	local memberShas: { string } = {}
	for _, branch in branches do
		plan.log(("verifying branch %s exists"):format(branch))
		local branchRef = deps.git.branchRef(branch)
		if branchRef.exitcode ~= 0 then
			return attributed("branch_missing", ("refs/heads/%s does not exist"):format(branch), branch)
		end
		local path, notFound = findWorktreeForBranch(worktrees.stdout, branch)
		if path == nil then
			return attributed("worktree_missing", notFound :: string, branch)
		end
		table.insert(memberPaths, path :: string)
		table.insert(memberShas, trimmed(branchRef.stdout))
	end
	plan.log("PASS resolved all member worktrees")

	local trainBranch = trainBranchName(plan.trainBranchPrefix, memberShas)
	local trainPath = plan.trainRoot .. "/" .. trainBranch

	plan.log(("building train %s at %s from %s"):format(trainBranch, trainPath, plan.base))
	local added = deps.git.worktreeAdd(trainPath, trainBranch, plan.base)
	if added.exitcode ~= 0 then
		return refusal(
			"train_worktree_add_failed",
			("git worktree add %s -b %s %s exited %d"):format(trainPath, trainBranch, plan.base, added.exitcode)
		)
	end
	plan.log("PASS train worktree created")

	local function abortWith(reason: string, detail: string, culprit: string?): Refusal
		abortTrain(trainPath, trainBranch, memberPaths, memberShas, deps)
		local guided = detail .. trainGuidance(trainBranch, trainPath, branches, culprit)
		if culprit ~= nil then
			return attributed(reason, guided, culprit :: string)
		end
		return refusal(reason, guided)
	end

	local setupRefusal = plan.setup(trainPath)
	if setupRefusal ~= nil then
		local refused = setupRefusal :: Refusal
		return abortWith(refused.reason, refused.detail, nil)
	end

	for index, branch in branches do
		local memberPath = memberPaths[index]
		plan.log(("rebasing member %s onto train %s inside %s"):format(branch, trainBranch, memberPath))
		local rebaseRefusal, resolvedPaths = rebaseOnto(memberPath, trainBranch, deps)
		if rebaseRefusal ~= nil then
			local refused = rebaseRefusal :: Refusal
			return abortWith(refused.reason, refused.detail, branch)
		end
		logRebase(deps, branch, resolvedPaths)

		plan.log(("fast-forward merging member %s into train %s"):format(branch, trainBranch))
		local classified = mergeVerified(branch, trainBranch, trainPath, deps)
		if classified.status ~= "ok" then
			return abortWith("train_" .. classified.status, classified.detail, branch)
		end
		plan.log(("PASS merged %s files_changed=%d"):format(branch, classified.filesChanged))
	end

	local prepareRefusal = plan.prepare(trainPath)
	if prepareRefusal ~= nil then
		local refused = prepareRefusal :: Refusal
		return abortWith(refused.reason, refused.detail, nil)
	end

	local commitRefusal = plan.commitGuard(trainBranch)
	if commitRefusal ~= nil then
		local refused = commitRefusal :: Refusal
		return abortWith(refused.reason, refused.detail, nil)
	end

	local verifiedCandidate = resolvedSha(deps.git.revParse(trainBranch))
	if verifiedCandidate == nil then
		return abortWith("candidate_unresolved", "train commit could not be resolved before verification", nil)
	end
	local verifyRefusal = plan.verify(trainPath)
	if verifyRefusal ~= nil then
		local refused = verifyRefusal :: Refusal
		return abortWith(refused.reason, refused.detail, nil)
	end

	local changeRefusal = plan.changeGuard(trainBranch)
	if changeRefusal ~= nil then
		local refused = changeRefusal :: Refusal
		return abortWith(refused.reason, refused.detail, nil)
	end

	plan.log(("fast-forward merging train %s from the primary checkout"):format(trainBranch))
	local classified = mergeVerified(trainBranch, plan.base, nil, deps, verifiedCandidate)
	if classified.status ~= "ok" then
		return refusal(
			"merge_" .. classified.status,
			classified.detail .. trainGuidance(trainBranch, trainPath, branches, nil)
		)
	end
	plan.log(("PASS merge files_changed=%d"):format(classified.filesChanged))

	local sha, pushRefusal = pushAndVerify(deps)
	if pushRefusal ~= nil then
		local refused = pushRefusal :: Refusal
		return refusal(refused.reason, refused.detail .. trainGuidance(trainBranch, trainPath, branches, nil))
	end

	plan.log("cleaning up train members")
	for index, branch in branches do
		local cleanupRefusal = cleanupOne(memberPaths[index], branch, sha :: string, deps)
		if cleanupRefusal ~= nil then
			return cleanupRefusal :: Refusal
		end
	end
	plan.log(("cleaning up train %s"):format(trainBranch))
	local trainCleanupRefusal = cleanupOne(trainPath, trainBranch, sha :: string, deps)
	if trainCleanupRefusal ~= nil then
		return trainCleanupRefusal :: Refusal
	end
	plan.log("PASS cleanup")

	return { ok = true, sha = sha :: string, filesChanged = classified.filesChanged }
end

return {
	refusal = refusal,
	attributed = attributed,
	extractFailingLines = extractFailingLines,
	runStep = runStep,
	isPrimaryCheckout = isPrimaryCheckout,
	findWorktreeForBranch = findWorktreeForBranch,
	classifyFastForward = classifyFastForward,
	mergeVerified = mergeVerified,
	classifyConflict = classifyConflict,
	handAuthoredDetail = handAuthoredDetail,
	shortSha = shortSha,
	trainBranchName = trainBranchName,
	trainGuidance = trainGuidance,
	landOne = landOne,
	landTrain = landTrain,
}
