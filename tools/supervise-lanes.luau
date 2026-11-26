--!strict

local process = require("@std/process")
local path = require("@std/path")
local Lanes = require("../extensions/luau/lanes")
local LaneProcess = require("./lib/lane-process")

local args = process.args
local usage =
	"usage: supervise-lanes CAP_SECONDS NAME WORKTREE STARTED_AT REPORT_FILE PID [NAME WORKTREE STARTED_AT REPORT_FILE PID ...]"
assert(#args >= 7 and (#args - 2) % 5 == 0, usage)
local cap = assert(tonumber(args[2]), usage)
local now = os.time()

for i = 3, #args, 5 do
	local name, worktree = args[i], args[i + 1]
	local startedAt = assert(tonumber(args[i + 2]), usage)
	local alive = LaneProcess.alive(LaneProcess.parsePid(args[i + 4]))
	local reported = LaneProcess.reported(path.format(path.resolve(worktree, args[i + 3])))
	local status = Lanes.classify({ startedAt = startedAt, reported = reported, alive = alive }, now, cap)
	print(("%s\t%s\t%s"):format(name, status, worktree))
end
