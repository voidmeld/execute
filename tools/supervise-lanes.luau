--!strict

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local Lanes = require("../extensions/luau/lanes")

local args = process.args
local usage =
	"usage: supervise-lanes CAP_SECONDS NAME WORKTREE STARTED_AT REPORT_FILE PID [NAME WORKTREE STARTED_AT REPORT_FILE PID ...]"
assert(#args >= 7 and (#args - 2) % 5 == 0, usage)
local cap = assert(tonumber(args[2]), usage)
local now = os.time()

local function alive(pid: string): boolean
	local result = process.run({ "ps", "-p", pid, "-o", "stat=" })
	if result.exitcode == 1 and result.stderr == "" and not string.find(result.stdout, "%S") then
		return false
	end
	assert(result.ok, "could not inspect PID " .. pid .. ": " .. result.stderr)
	local state = assert(string.match(result.stdout, "%S"), "missing process state for PID " .. pid)
	return state ~= "Z"
end

for i = 3, #args, 5 do
	local name, worktree, report, pid = args[i], args[i + 1], args[i + 3], args[i + 4]
	local startedAt = assert(tonumber(args[i + 2]), usage)
	assert(string.match(pid, "^[1-9]%d*$"), "expected a positive process ID")
	local running = alive(pid)
	local file = path.resolve(worktree, report)
	local reported = fs.exists(file) and fs.type(file) == "file"
	local status = Lanes.classify({ startedAt = startedAt, reported = reported, alive = running }, now, cap)
	print(("%s\t%s\t%s"):format(name, status, worktree))
end
