--!strict

local WorkerSetup = require("./worker-setup")
local Verify = require("../../.lute/dependencies/verify/src/core")

local function warning(paths: string): string
	return "dirty: " .. paths
end

return function(suite: Verify.Harness)
	suite:case("reads the first line", function(context)
		context:expect(WorkerSetup.firstLine("first  \nsecond")):toBe("first")
		context:expect(WorkerSetup.firstLine("only")):toBe("only")
		context:expect(WorkerSetup.firstLine("")):toBe("")
	end)

	suite:case("passes a command step", function(context)
		local seen: { string }? = nil
		local outcome = WorkerSetup.commandStep("sync", { "tool", "sync" }, function(command: { string })
			seen = command
			return { exitcode = 0, stdout = "synced\nextra", stderr = "" }
		end)
		context:expect(outcome.status):toBe("PASS")
		context:expect(outcome.detail):toBe("synced")
		context:expect(seen):toBeTruthy()
		context:expect((seen :: { string })[2]):toBe("sync")
	end)

	suite:case("fails a command step with stderr", function(context)
		local outcome = WorkerSetup.commandStep("sync", { "tool" }, function()
			return { exitcode = 3, stdout = "out", stderr = "boom\ndetail" }
		end)
		context:expect(outcome.status):toBe("FAIL")
		context:expect(outcome.detail):toBe("exit 3: boom")
	end)

	suite:case("fails a command step with stdout fallback", function(context)
		local outcome = WorkerSetup.commandStep("sync", { "tool" }, function()
			return { exitcode = 3, stdout = "fallback", stderr = "" }
		end)
		context:expect(outcome.status):toBe("FAIL")
		context:expect(outcome.detail):toBe("exit 3: fallback")
	end)

	suite:case("fails a command step that throws", function(context)
		local outcome = WorkerSetup.commandStep("sync", { "tool" }, function(): WorkerSetup.CommandResult
			error("spawn failed")
		end)
		context:expect(outcome.status):toBe("FAIL")
		context:expect(outcome.detail):toContain("spawn failed")
	end)

	suite:case("skips an existing directory and creates a missing one", function(context)
		local created: { string } = {}
		local existing: { [string]: boolean } = { build = true }
		local skipped = WorkerSetup.directoryStep("build", function(path: string): boolean
			return existing[path] == true
		end, function(path: string)
			table.insert(created, path)
		end)
		context:expect(skipped.status):toBe("SKIP")
		context:expect(#created):toBe(0)

		local made = WorkerSetup.directoryStep("build/generated", function(path: string): boolean
			return existing[path] == true
		end, function(path: string)
			table.insert(created, path)
		end)
		context:expect(made.status):toBe("PASS")
		context:expect(created[1]):toBe("build/generated")
	end)

	suite:case("fails a directory step that throws", function(context)
		local failed = WorkerSetup.directoryStep("build", function(): boolean
			return false
		end, function()
			error("read-only filesystem")
		end)
		context:expect(failed.status):toBe("FAIL")
		context:expect(failed.detail):toContain("read-only filesystem")
	end)

	suite:case("parses dirty paths", function(context)
		local paths = WorkerSetup.dirtyPaths(" M src/main.luau\n?? new.txt\ngarbage\n")
		context:expect(#paths):toBe(2)
		context:expect(paths[1]):toBe("src/main.luau")
		context:expect(paths[2]):toBe("new.txt")
	end)

	suite:case("passes a clean tree", function(context)
		local clean = WorkerSetup.cleanTreeStep("tree", { exitcode = 0, stdout = "", stderr = "" }, warning)
		context:expect(clean.status):toBe("PASS")
		context:expect(clean.detail):toBe("clean")
	end)

	suite:case("warns about dirty paths", function(context)
		local dirty = WorkerSetup.cleanTreeStep("tree", { exitcode = 0, stdout = " M a\n M b\n", stderr = "" }, warning)
		context:expect(dirty.status):toBe("WARN")
		context:expect(dirty.detail):toBe("dirty: a, b")
	end)

	suite:case("truncates a long dirty list", function(context)
		local lines: { string } = {}
		for index = 1, 12 do
			table.insert(lines, (" M file%d"):format(index))
		end
		local many = WorkerSetup.cleanTreeStep(
			"tree",
			{ exitcode = 0, stdout = table.concat(lines, "\n"), stderr = "" },
			warning
		)
		context:expect(many.status):toBe("WARN")
		context:expect(many.detail):toContain("and 2 more")
		context:expect(many.detail).never:toContain("file11")
	end)

	suite:case("warns when git is unavailable", function(context)
		local unavailable =
			WorkerSetup.cleanTreeStep("tree", { exitcode = 127, stdout = "", stderr = "git missing" }, warning)
		context:expect(unavailable.status):toBe("WARN")
		context:expect(unavailable.detail):toContain("git missing")
	end)

	suite:case("runs every step of a plan in order", function(context)
		local order: { string } = {}
		local outcomes = WorkerSetup.runPlan({
			{
				name = "one",
				run = function(name: string): WorkerSetup.StepOutcome
					table.insert(order, name)
					return { name = name, status = "PASS", detail = "" }
				end,
			},
			{
				name = "two",
				run = function(name: string): WorkerSetup.StepOutcome
					table.insert(order, name)
					return { name = name, status = "FAIL", detail = "" }
				end,
			},
			{
				name = "three",
				run = function(name: string): WorkerSetup.StepOutcome
					table.insert(order, name)
					return { name = name, status = "WARN", detail = "" }
				end,
			},
		})
		context:expect(#outcomes):toBe(3)
		context:expect(order[1]):toBe("one")
		context:expect(order[2]):toBe("two")
		context:expect(order[3]):toBe("three")
		context:expect(WorkerSetup.failureCount(outcomes)):toBe(1)
	end)

	suite:case("counts no failures for an empty plan", function(context)
		context:expect(WorkerSetup.failureCount({})):toBe(0)
	end)
end
