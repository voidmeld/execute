--!strict

local RegisterLimit = require("./register-limit")
local SourceScan = require("./source-scan")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local TREE: { [string]: { string } } = {
	roblox = { "shared" },
	["roblox/shared"] = { "Core.luau", "Core.lute.verify.luau", "Legacy.lua", "notes.md", "deep" },
	["roblox/shared/deep"] = { "Inner.luau" },
	shared = { "Rules.luau" },
}

local host: SourceScan.Host = {
	exists = function(path: string): boolean
		return TREE[path] ~= nil or string.match(path, "%.%a+$") ~= nil
	end,
	kind = function(path: string): string
		return if TREE[path] ~= nil then "dir" else "file"
	end,
	children = function(path: string): { string }
		return TREE[path] or {}
	end,
}

local function config(compile: (source: string) -> ()): RegisterLimit.Config
	return {
		label = "register-limit",
		roots = { "roblox", "shared", "absent" },
		include = { "%.luau$", "%.lua$" },
		exclude = { "%.verify%.luau$" },
		compile = compile,
	}
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("register limit", function()
		it("lists every shipped module and no specification or other file", function()
			expect(RegisterLimit.shipped(config(function() end), host)):toEqual({
				"roblox/shared/Core.luau",
				"roblox/shared/Legacy.lua",
				"roblox/shared/deep/Inner.luau",
				"shared/Rules.luau",
			})
		end)

		it("compiles each module at optimization level 0", function()
			local seen: { string } = {}
			local reports: { string } = {}
			local code = RegisterLimit.check(
				{ "a", "b" },
				function(path: string): string
					return "return " .. path
				end,
				config(function(source: string)
					table.insert(seen, source)
				end),
				function(line: string)
					table.insert(reports, line)
				end
			)
			expect(code):toBe(0)
			expect(seen):toEqual({ RegisterLimit.UNOPTIMIZED .. "return a", RegisterLimit.UNOPTIMIZED .. "return b" })
			expect(reports):toEqual({ "register-limit: 2 module(s) compiled at optimization level 0, 0 refused" })
		end)

		it("fails on any refused module and keeps checking the rest", function()
			local reports: { string } = {}
			local code = RegisterLimit.check(
				{ "valid", "invalid", "later" },
				function(path: string): string
					return path
				end,
				config(function(source: string)
					if string.find(source, "invalid", 1, true) ~= nil then
						error("syntax error: out of registers\nsecond line", 0)
					end
				end),
				function(line: string)
					table.insert(reports, line)
				end
			)
			expect(code):toBe(1)
			expect(reports[1]):toBe("register-limit: FAIL invalid: out of registers")
			expect(reports[2]):toBe("register-limit: 3 module(s) compiled at optimization level 0, 1 refused")
		end)
	end)
end
