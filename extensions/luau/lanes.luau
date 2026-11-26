--!strict

local WorkerSetup = require("./worker-setup")

export type Observation = {
	startedAt: number,
	reported: boolean,
	alive: boolean,
}

export type Status = "running" | "reported" | "exited without a report" | "over the cap"

export type Landing = {
	repo: string,
	worktree: string,
	branch: string,
	main: string,
	remote: string,
	setup: { string },
	check: { string },
	release: { string }?,
	otherPids: { number },
}

export type Host = {
	run: (command: { string }, cwd: string) -> WorkerSetup.CommandResult,
	releaseRunning: () -> boolean,
	waitForPoll: () -> (),
	pause: (pid: number) -> (() -> ())?,
}

local function classify(lane: Observation, now: number, capSeconds: number): Status
	assert(capSeconds > 0 and capSeconds < math.huge, "expected a positive time cap in seconds")
	if lane.reported then
		return "reported"
	elseif not lane.alive then
		return "exited without a report"
	elseif now - lane.startedAt >= capSeconds then
		return "over the cap"
	end
	return "running"
end

local function run(host: Host, cwd: string, command: { string }): string
	local result = host.run(command, cwd)
	if result.exitcode ~= 0 then
		local detail = if result.stderr ~= "" then result.stderr else result.stdout
		error(("%s exited %d: %s"):format(table.concat(command, " "), result.exitcode, detail), 0)
	end
	return (string.gsub(result.stdout, "[\r\n]+$", ""))
end

local function withPeersPaused(pids: { number }, host: Host, check: () -> ())
	local resumes: { { pid: number, resume: () -> () } } = {}
	local ok, problem = pcall(function()
		for _, pid in pids do
			local resume = host.pause(pid)
			if resume then
				table.insert(resumes, { pid = pid, resume = resume })
			end
		end
		check()
	end)
	local errors: { string } = {}
	if not ok then
		table.insert(errors, tostring(problem))
	end
	for i = #resumes, 1, -1 do
		local peer = resumes[i]
		local resumed, reason = pcall(peer.resume)
		if not resumed then
			table.insert(errors, ("resume PID %d: %s"):format(peer.pid, tostring(reason)))
		end
	end
	if #errors > 0 then
		error(table.concat(errors, "\n"), 0)
	end
end

local function land(lane: Landing, host: Host): string
	assert(lane.branch ~= lane.main, "choose a lane branch distinct from the main branch")
	assert(lane.setup[1] and lane.check[1], "supply setup and check commands")
	local release = lane.release
	assert(release == nil or release[1], "supply a release command or omit it")
	for _, pid in lane.otherPids do
		assert(pid > 0 and pid % 1 == 0, "expected a positive process ID")
	end

	while host.releaseRunning() do
		host.waitForPoll()
	end

	local function inLane(command: { string }): string
		return run(host, lane.worktree, command)
	end
	local branch = "refs/heads/" .. lane.branch
	local main = "refs/heads/" .. lane.main
	local function cleanHead(): string
		assert(inLane({ "git", "symbolic-ref", "HEAD" }) == branch, "worktree must hold " .. branch)
		local status =
			inLane({ "git", "status", "--porcelain=v1", "--untracked-files=all", "--ignore-submodules=none" })
		assert(status == "", "worktree has changes:\n" .. status)
		return inLane({ "git", "rev-parse", "--verify", "HEAD^{commit}" })
	end

	inLane({ "git", "check-ref-format", main })
	local commonDir = { "git", "rev-parse", "--path-format=absolute", "--git-common-dir" }
	assert(inLane(commonDir) == run(host, lane.repo, commonDir), "worktree belongs to another repository")
	cleanHead()
	local path = inLane({ "git", "rev-parse", "--show-toplevel" })
	inLane({ "git", "fetch", "--no-tags", "--", lane.remote, main })
	local rebased, reason = pcall(inLane, { "git", "rebase", "--no-update-refs", "--no-autostash", "FETCH_HEAD" })
	if not rebased then
		local aborted, abortReason = pcall(inLane, { "git", "rebase", "--abort" })
		error(if aborted then tostring(reason) else tostring(reason) .. "\n" .. tostring(abortReason), 0)
	end
	local commit = cleanHead()
	inLane(lane.setup)
	withPeersPaused(lane.otherPids, host, function()
		assert(cleanHead() == commit, "setup changed the lane commit")
		inLane(lane.check)
	end)
	assert(cleanHead() == commit, "check changed the lane commit")
	inLane({ "git", "push", "--no-follow-tags", "--", lane.remote, commit .. ":" .. main })

	local finished, problem = pcall(function()
		assert(cleanHead() == commit, "lane moved after push")
		run(host, lane.repo, { "git", "worktree", "remove", "--", path })
		run(host, lane.repo, { "git", "update-ref", "--no-deref", "-d", branch, commit })
		if release then
			local command = table.clone(release)
			table.insert(command, commit)
			run(host, lane.repo, command)
		end
	end)
	if not finished then
		error("Pushed " .. commit .. ". " .. tostring(problem), 0)
	end
	return commit
end

return {
	classify = classify,
	land = land,
}
