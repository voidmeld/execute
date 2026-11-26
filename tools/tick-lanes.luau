--!strict

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local Lanes = require("../extensions/luau/lanes")
local LaneProcess = require("./lib/lane-process")
local hygiene = require("./lib/lane-hygiene-host")

local args = process.args
local usage = "usage: tick-lanes SLOTS CAP_SECONDS QUEUE STATE [START [ARG ...]]"
assert(#args >= 5, usage)
local slots, cap = assert(tonumber(args[2]), usage), assert(tonumber(args[3]), usage)
local queueFile, state = args[4], args[5]
assert(path.format(path.resolve(queueFile)) ~= path.format(path.resolve(state)), "use separate queue and state files")
local lock = state .. ".lock"
local staged, starting = lock .. "/next", lock .. "/starting"

local function rows(file: string, width: number): { { string } }
	local entries: { { string } } = {}
	for line in string.gmatch(fs.readFileToString(file) .. "\n", "([^\n]*)\n") do
		line = string.gsub(line, "\r$", "")
		if line ~= "" then
			local fields = string.split(line, "\t")
			assert(#fields == width and not table.find(fields, ""), "invalid row in " .. file .. ": " .. line)
			table.insert(entries, fields)
		end
	end
	return entries
end

local function readRuns(): { Lanes.Run }
	local runs: { Lanes.Run } = {}
	if fs.exists(state) then
		for _, row in rows(state, 5) do
			local name, start, pid, report, status = table.unpack(row)
			assert(
				status == "running"
					or status == "reported"
					or status == "exited without a report"
					or status == "over the cap",
				"unknown lane status in " .. state .. ": " .. status
			)
			local startedAt = assert(tonumber(start), "invalid start time for " .. name)
			assert(math.isfinite(startedAt), "expected a finite start time")
			table.insert(runs, {
				name = name,
				startedAt = startedAt,
				pid = if pid == "-" then nil else LaneProcess.parsePid(pid),
				report = report,
				status = status,
			})
		end
	end
	return runs
end

local function save(runs: { Lanes.Run })
	local lines: { string } = {}
	for _, lane in runs do
		local pid = if lane.pid then tostring(lane.pid) else "-"
		table.insert(
			lines,
			table.concat({ lane.name, tostring(lane.startedAt), pid, lane.report, lane.status }, "\t") .. "\n"
		)
	end
	fs.writeStringToFile(staged, table.concat(lines))
	fs.move(staged, state)
	if fs.exists(starting) then
		fs.remove(starting)
	end
end

local function start(command: { string }): (number, string)
	local name = command[#command - 1]
	fs.writeStringToFile(starting, name)
	local result = process.run(command)
	if not result.ok then
		if not result.signal then
			fs.remove(starting)
		end
		error(("start %s exited %d: %s%s"):format(name, result.exitcode, result.stdout, result.stderr), 0)
	end
	local pid, report = string.match(result.stdout, "^([1-9]%d*)\t([^\t\r\n]+)\r?\n?$")
	assert(pid and report, "start " .. name .. " must print PID, a tab and the report path")
	return LaneProcess.parsePid(pid), path.format(path.resolve(report))
end

local function runTick()
	local pending: { Lanes.Pending } = {}
	for _, row in rows(queueFile, 2) do
		table.insert(pending, { name = row[1], brief = row[2] })
	end
	Lanes.runTick(
		{ pending = pending, slots = slots, capSeconds = cap, start = table.move(args, 6, #args, 1, {}) },
		readRuns(),
		{
			now = function()
				return os.time()
			end,
			alive = LaneProcess.alive,
			reported = LaneProcess.reported,
			start = start,
			save = save,
			hygiene = function(known)
				local result = process.run({ "git", "rev-parse", "--show-toplevel" })
				if result.exitcode == 128 and result.stderr:find("not a git repository", 1, true) then
					return
				end
				assert(result.ok, result.stderr)
				local repo = result.stdout:gsub("\n$", "")
				hygiene({
					repo = repo,
					trunk = process.env.EXECUTE_TRUNK or "main",
					lanesRoot = process.env.EXECUTE_LANES_ROOT or repo .. "-worktrees",
				}, function(name)
					return known[name] == true
				end, print)
			end,
			notify = function(name, status, detail)
				print(("%s\t%s\t%s"):format(name, status, detail))
			end,
		}
	)
end

fs.createDirectory(lock)
local ok, reason = pcall(runTick)
if fs.exists(starting) then
	error(
		("%s\nCheck whether %s started before removing %s."):format(
			tostring(reason),
			fs.readFileToString(starting),
			lock
		),
		0
	)
end
if fs.exists(staged) then
	fs.remove(staged)
end
fs.removeDirectory(lock)
if not ok then
	error(reason, 0)
end
