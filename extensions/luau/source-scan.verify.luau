--!strict

local SourceScan = require("./source-scan")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local TREE: { [string]: { string } } = {
	src = { "b.luau", "a.luau", "notes.md", "deep" },
	["src/deep"] = { "c.luau" },
	other = { "d.luau" },
}

local host: SourceScan.Host = {
	exists = function(path: string): boolean
		return TREE[path] ~= nil or string.match(path, "%.%a+$") ~= nil
	end,
	kind = function(path: string): string
		if TREE[path] ~= nil then
			return "dir"
		end
		return if string.match(path, "%.%a+$") ~= nil then "file" else "other"
	end,
	children = function(path: string): { string }
		return TREE[path] or {}
	end,
}

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("source scan", function()
		it("collects matching files depth first in name order and skips absent roots", function()
			expect(SourceScan.collect({ "src", "missing", "other" }, host, "%.luau$")):toEqual({
				"src/a.luau",
				"src/b.luau",
				"src/deep/c.luau",
				"other/d.luau",
			})
		end)

		it("accepts a file root", function()
			expect(SourceScan.collect({ "src/a.luau", "src/notes.md" }, host, "%.luau$")):toEqual({ "src/a.luau" })
		end)

		it("matches a root exactly or as a directory prefix", function()
			expect(SourceScan.inRoots("roblox", { "roblox" })):toBe(true)
			expect(SourceScan.inRoots("roblox/a.luau", { "roblox" })):toBe(true)
			expect(SourceScan.inRoots("roblox-other/a.luau", { "roblox" })):toBe(false)
			expect(SourceScan.inRoots("shared/a.luau", { "roblox", "shared/a.luau" })):toBe(true)
		end)

		it("collapses whitespace and bounds a snippet", function()
			expect(SourceScan.normalize("  local   a =\t1  ", 160)):toBe("local a = 1")
			expect(SourceScan.normalize(string.rep("x", 200), 10)):toBe("xxxxxxxxxx")
		end)

		it("keeps open hits and reports entries that match nothing", function()
			local reconciled = SourceScan.reconcile({ "a", "b", "a" }, { "a", "z" }, function(hit: string): string
				return hit
			end, function(entry: string): string
				return entry
			end)
			expect(reconciled.hits):toEqual({ "b" })
			expect(reconciled.stale):toEqual({ "z" })
		end)
	end)
end
