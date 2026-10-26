--!strict

local WorkerSetup = require("./worker-setup")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local function warning(paths: string): string
	return "dirty: " .. paths
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("worker setup", function()
		it("reads the first line", function()
			expect(WorkerSetup.firstLine("first  \nsecond")):toBe("first")
			expect(WorkerSetup.firstLine("only")):toBe("only")
			expect(WorkerSetup.firstLine("")):toBe("")
		end)

		it("passes a command step", function()
			local seen: { string }? = nil
			local outcome = WorkerSetup.commandStep("sync", { "tool", "sync" }, function(command: { string })
				seen = command
				return { exitcode = 0, stdout = "synced\nextra", stderr = "" }
			end)
			expect(outcome.status):toBe("PASS")
			expect(outcome.detail):toBe("synced")
			expect(seen):toBeTruthy()
			expect((seen :: { string })[2]):toBe("sync")
		end)

		it("fails a command step with stderr", function()
			local outcome = WorkerSetup.commandStep("sync", { "tool" }, function()
				return { exitcode = 3, stdout = "out", stderr = "boom\ndetail" }
			end)
			expect(outcome.status):toBe("FAIL")
			expect(outcome.detail):toBe("exit 3: boom")
		end)

		it("fails a command step with stdout fallback", function()
			local outcome = WorkerSetup.commandStep("sync", { "tool" }, function()
				return { exitcode = 3, stdout = "fallback", stderr = "" }
			end)
			expect(outcome.status):toBe("FAIL")
			expect(outcome.detail):toBe("exit 3: fallback")
		end)

		it("fails a command step that throws", function()
			local outcome = WorkerSetup.commandStep("sync", { "tool" }, function(): WorkerSetup.CommandResult
				error("spawn failed")
			end)
			expect(outcome.status):toBe("FAIL")
			expect(outcome.detail):toContain("spawn failed")
		end)

		it("skips an existing directory and creates a missing one", function()
			local created: { string } = {}
			local existing: { [string]: boolean } = { build = true }
			local skipped = WorkerSetup.directoryStep("build", function(path: string): boolean
				return existing[path] == true
			end, function(path: string)
				table.insert(created, path)
			end)
			expect(skipped.status):toBe("SKIP")
			expect(#created):toBe(0)

			local made = WorkerSetup.directoryStep("build/generated", function(path: string): boolean
				return existing[path] == true
			end, function(path: string)
				table.insert(created, path)
			end)
			expect(made.status):toBe("PASS")
			expect(created[1]):toBe("build/generated")
		end)

		it("fails a directory step that throws", function()
			local failed = WorkerSetup.directoryStep("build", function(): boolean
				return false
			end, function()
				error("read-only filesystem")
			end)
			expect(failed.status):toBe("FAIL")
			expect(failed.detail):toContain("read-only filesystem")
		end)

		it("parses dirty paths", function()
			local paths = WorkerSetup.dirtyPaths(" M src/main.luau\n?? new.txt\ngarbage\n")
			expect(#paths):toBe(2)
			expect(paths[1]):toBe("src/main.luau")
			expect(paths[2]):toBe("new.txt")
		end)

		it("passes a clean tree", function()
			local clean = WorkerSetup.cleanTreeStep("tree", { exitcode = 0, stdout = "", stderr = "" }, warning)
			expect(clean.status):toBe("PASS")
			expect(clean.detail):toBe("clean")
		end)

		it("warns about dirty paths", function()
			local dirty =
				WorkerSetup.cleanTreeStep("tree", { exitcode = 0, stdout = " M a\n M b\n", stderr = "" }, warning)
			expect(dirty.status):toBe("WARN")
			expect(dirty.detail):toBe("dirty: a, b")
		end)

		it("truncates a long dirty list", function()
			local lines: { string } = {}
			for index = 1, 12 do
				table.insert(lines, (" M file%d"):format(index))
			end
			local many = WorkerSetup.cleanTreeStep(
				"tree",
				{ exitcode = 0, stdout = table.concat(lines, "\n"), stderr = "" },
				warning
			)
			expect(many.status):toBe("WARN")
			expect(many.detail):toContain("and 2 more")
			expect(many.detail).never:toContain("file11")
		end)

		it("warns when git is unavailable", function()
			local unavailable =
				WorkerSetup.cleanTreeStep("tree", { exitcode = 127, stdout = "", stderr = "git missing" }, warning)
			expect(unavailable.status):toBe("WARN")
			expect(unavailable.detail):toContain("git missing")
		end)

		it("counts no failures for an empty plan", function()
			expect(WorkerSetup.failureCount({})):toBe(0)
		end)
	end)
end
