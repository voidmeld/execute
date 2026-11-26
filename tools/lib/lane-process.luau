--!strict

local fs = require("@std/fs")
local process = require("@std/process")

local function parsePid(value: string): number
	assert(string.match(value, "^[1-9]%d*$"), "expected a positive process ID")
	local pid = assert(tonumber(value))
	assert(math.isfinite(pid), "expected a finite process ID")
	return pid
end

local function alive(pid: number): boolean
	local result = process.run({ "ps", "-p", tostring(pid), "-o", "stat=" })
	if result.exitcode == 1 and result.stderr == "" and not string.find(result.stdout, "%S") then
		return false
	end
	assert(result.ok, "could not inspect PID " .. pid .. ": " .. result.stderr)
	local state = assert(string.match(result.stdout, "%S"), "missing process state for PID " .. pid)
	return state ~= "Z"
end

local function reported(file: string): boolean
	return fs.exists(file) and fs.type(file) == "file"
end

return { parsePid = parsePid, alive = alive, reported = reported }
