--!strict

local fs = require("@std/fs")
local process = require("@lute/process")
local Bdd = require("@verify/src/bdd")
local Verify = require("@verify/src/core")
local TemporaryDirectory = require("@verify/src/checks").temporaryDirectory

local command = process.cwd() .. "/tools/tick-lanes.luau"

local function run(root: string, slots: number, ...: string): process.ProcessResult
	return process.run(
		{ process.execPath(), "run", command, tostring(slots), "3600", "queue", "state", ... },
		{ cwd = root }
	)
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("the lane tick command", function()
		it("saves each launch, retries the next lane and remembers a report across invocations", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-queue", function(root)
				fs.writeStringToFile(root .. "/queue", "docs\tbrief one\r\napi\tbrief two")
				local launcher = [[
if [ "$1" = api ] && [ ! -f ready ]; then exit 9; fi
printf '%s\t%s\n' "$1" "$2" >> launches
printf '%s\t%s\n' "$0" "$1 report"
]]
				local function launch()
					return run(root, 2, "sh", "-c", launcher, tostring(process.pid()))
				end
				local first = launch()
				expect(first.ok):toBeFalsy()
				expect(first.stderr):toContain("start api exited 9")
				expect(fs.exists(root .. "/state.lock")):toBeFalsy()
				fs.writeStringToFile(root .. "/ready", "")
				local second = launch()
				assert(second.ok, second.stderr)
				expect(second.stdout):toBe("api\tstarted\tbrief two\n")
				expect(fs.readFileToString(root .. "/launches")):toBe("docs\tbrief one\napi\tbrief two\n")
				fs.writeStringToFile(root .. "/docs report", "finished")
				local reported = run(root, 0)
				assert(reported.ok, reported.stderr)
				expect(reported.stdout):toContain("docs\treported\t")
				local quiet = run(root, 0)
				assert(quiet.ok, quiet.stderr)
				expect(quiet.stdout):toBe("")
				return true
			end)
		end)

		it("holds the lock when a successful launcher returns an unreadable receipt", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-queue-recovery", function(root)
				fs.writeStringToFile(root .. "/queue", "docs\tbrief")
				local first = run(root, 1, "sh", "-c", "echo start >> launches; echo missing-pid")
				expect(first.ok):toBeFalsy()
				expect(first.stderr):toContain("must print PID")
				expect(fs.readFileToString(root .. "/state.lock/starting")):toBe("docs")
				local locked = run(root, 1, "sh", "-c", "echo second >> launches")
				expect(locked.ok):toBeFalsy()
				expect(fs.readFileToString(root .. "/launches")):toBe("start\n")
				fs.writeStringToFile(
					root .. "/state",
					("docs\t1\t%d\t%s/docs.report\trunning\n"):format(process.pid(), root)
				)
				fs.remove(root .. "/state.lock/starting")
				fs.removeDirectory(root .. "/state.lock")
				local resumed = run(root, 1, "sh", "-c", "echo duplicate >> launches")
				assert(resumed.ok, resumed.stderr)
				expect(resumed.stdout):toContain("docs\tover the cap\t")
				expect(fs.readFileToString(root .. "/launches")):toBe("start\n")
				return true
			end)
		end)
	end)
end
