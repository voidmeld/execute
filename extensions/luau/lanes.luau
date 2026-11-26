--!strict

local WorkerSetup = require("./worker-setup")
local ScopedChecks = require("./scoped-checks")
local Hygiene = require("./lane-hygiene")

export type Hygiene = Hygiene.Config
export type HygieneHost = Hygiene.Host

export type Observation = {
	startedAt: number,
	reported: boolean,
	alive: boolean,
}

export type Status = "running" | "reported" | "exited without a report" | "over the cap"

export type Pending = { name: string, brief: string }
export type Queue = { pending: { Pending }, slots: number, capSeconds: number, start: { string } }
export type Run = { name: string, startedAt: number, report: string, pid: number?, status: Status }
export type QueueHost = {
	now: () -> number,
	alive: (pid: number) -> boolean,
	reported: (file: string) -> boolean,
	start: (command: { string }) -> (number, string),
	save: (runs: { Run }) -> (),
	notify: (name: string, status: Status | "started", detail: string) -> (),
	hygiene: ((known: { [string]: boolean }) -> ())?,
}

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
	pausePatterns: { string }?,
}

export type PeerPolling = {
	processes: () -> { { pid: number, command: string } },
	startCheck: (command: { string }, cwd: string) -> (seconds: number) -> WorkerSetup.CommandResult?,
}

export type Host = {
	run: (command: { string }, cwd: string) -> WorkerSetup.CommandResult,
	releaseRunning: () -> boolean,
	waitForPoll: () -> (),
	pause: (pid: number) -> (() -> ())?,
	polling: PeerPolling?,
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

local function selectStarts(pending: { Pending }, known: { [string]: boolean }, slots: number): { Pending }
	assert(slots >= 0 and slots % 1 == 0, "expected a nonnegative whole number of slots")
	local available = slots
	for _, alive in known do
		if alive then
			available -= 1
		end
	end
	local starts: { Pending } = {}
	local names: { [string]: boolean } = {}
	for _, lane in pending do
		assert(lane.name ~= "" and lane.brief ~= "", "supply a lane name and a brief file")
		assert(not names[lane.name], "duplicate queued lane: " .. lane.name)
		names[lane.name] = true
		if known[lane.name] == nil and #starts < available then
			table.insert(starts, lane)
		end
	end
	return starts
end

local priority: { [Status]: number } = {
	running = 0,
	["over the cap"] = 1,
	["exited without a report"] = 2,
	reported = 3,
}

local function runTick(queue: Queue, runs: { Run }, host: QueueHost)
	assert(queue.capSeconds > 0 and queue.capSeconds < math.huge, "expected a positive time cap in seconds")
	assert(queue.slots == 0 or queue.start[1], "supply a start command")
	local now = host.now()
	local known: { [string]: boolean } = {}
	local reports: { [string]: boolean } = {}
	local updated: { Run } = {}
	local changed = false
	for _, previous in runs do
		local lane = table.clone(previous)
		assert(known[lane.name] == nil, "duplicate lane run: " .. lane.name)
		assert(not reports[lane.report], "each lane run needs its own report file: " .. lane.report)
		reports[lane.report] = true
		local alive = lane.pid ~= nil and host.alive(lane.pid)
		known[lane.name] = alive
		if not alive and lane.pid ~= nil then
			lane.pid = nil
			changed = true
		end
		local reported = lane.status == "reported" or host.reported(lane.report)
		local observed = { startedAt = lane.startedAt, reported = reported, alive = alive }
		local status = classify(observed, now, queue.capSeconds)
		if priority[status] > priority[lane.status] then
			host.notify(lane.name, status, lane.report)
			lane.status = status
			changed = true
		end
		table.insert(updated, lane)
	end
	local starts = selectStarts(queue.pending, known, queue.slots)
	if changed then
		host.save(updated)
	end
	if host.hygiene then
		host.hygiene(known)
	end
	for _, lane in starts do
		local command = table.clone(queue.start)
		table.insert(command, lane.name)
		table.insert(command, lane.brief)
		local startedAt = host.now()
		local pid, report = host.start(command)
		assert(pid > 0 and pid % 1 == 0, "expected a positive process ID")
		assert(report ~= "" and not reports[report], "expected a new report file for " .. lane.name)
		reports[report] = true
		local launched: Run =
			{ name = lane.name, startedAt = startedAt, pid = pid, report = report, status = "running" }
		table.insert(updated, launched)
		host.save(updated)
		host.notify(lane.name, "started", lane.brief)
	end
end

local function output(command: { string }, result: WorkerSetup.CommandResult): string
	if result.exitcode ~= 0 then
		local detail = if result.stderr ~= "" then result.stderr else result.stdout
		error(("%s exited %d: %s"):format(table.concat(command, " "), result.exitcode, detail), 0)
	end
	return (string.gsub(result.stdout, "[\r\n]+$", ""))
end

local function run(host: Host, cwd: string, command: { string }): string
	return output(command, host.run(command, cwd))
end

local function withPeersPaused(pids: { number }, host: Host, check: ((number) -> (), { string }) -> ())
	local resumes: { { pid: number, resume: () -> () } } = {}
	local errors: { string } = {}
	local function pause(pid: number)
		assert(pid > 0 and pid % 1 == 0, "expected a positive process ID")
		local resume = host.pause(pid)
		if resume then
			table.insert(resumes, { pid = pid, resume = resume })
		end
	end
	local ok, problem = pcall(function()
		for _, pid in pids do
			pause(pid)
		end
		check(pause, errors)
	end)
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

local function pollingCheck(
	lane: Landing,
	patterns: { string },
	host: PeerPolling,
	pause: (number) -> (),
	errors: { string }
)
	local function scan()
		for _, peer in host.processes() do
			if ScopedChecks.matches(peer.command, patterns) then
				pause(peer.pid)
			end
		end
	end
	scan()
	local waitForExit = host.startCheck(lane.check, lane.worktree)
	while true do
		local result = waitForExit(3)
		if result then
			output(lane.check, result)
			return
		end
		if #errors == 0 then
			local ok, reason = pcall(scan)
			if not ok then
				table.insert(errors, tostring(reason))
			end
		end
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
	local patterns, polling = lane.pausePatterns, host.polling
	if patterns and #patterns > 0 then
		assert(polling, "supply a polling host for pausePatterns")
		for _, pattern in patterns do
			assert(pattern ~= "", "expected a nonempty process pattern")
		end
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
	withPeersPaused(lane.otherPids, host, function(pause, errors)
		assert(cleanHead() == commit, "setup changed the lane commit")
		if patterns and #patterns > 0 and polling then
			pollingCheck(lane, patterns, polling, pause, errors)
		else
			inLane(lane.check)
		end
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
	selectStarts = selectStarts,
	runTick = runTick,
	hygiene = Hygiene.run,
	land = land,
}
