--!strict

local SilentFallbacks = require("./silent-fallbacks")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local SELECTED = "area/Selected.luau"
local OTHER = "shared/Other.luau"
local UNSAFE = 'local text = labels[key] or "missing"'

local CONFIG: SilentFallbacks.Config = {
	label = "scan",
	displayFields = { "Text", "title" },
	bestEffortWords = { "cleanup", "log" },
	skipPaths = { "%.verify%.luau$", "^allow%.luau$", "/probe/" },
	teardownPaths = { "^tools/" },
}

local function entry(path: string, reason: string?, snippet: string?): SilentFallbacks.Entry
	return {
		path = path,
		rule = "lookup-or-literal",
		snippet = snippet or UNSAFE,
		disposition = "authored",
		reason = reason or "Authored fallback for the isolated test fixture.",
	}
end

local function run(
	roots: { string },
	selected: boolean,
	entries: { SilentFallbacks.Entry },
	files: { [string]: string }
): (number, string)
	local paths: { string } = {}
	for path in files do
		table.insert(paths, path)
	end
	table.sort(paths)
	local output: { string } = {}
	local code = SilentFallbacks.check({
		config = CONFIG,
		roots = roots,
		selected = selected,
		entries = entries,
		paths = paths,
		read = function(path: string): string
			return assert(files[path])
		end,
	}, function(line: string)
		table.insert(output, line)
	end)
	return code, table.concat(output, "\n")
end

local function rules(source: string, path: string?): { string }
	local found: { string } = {}
	for _, hit in SilentFallbacks.lintFile(path or SELECTED, source, CONFIG) do
		table.insert(found, hit.rule)
	end
	return found
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("silent fallback rules", function()
		it("flags a keyed lookup that falls back to a string literal", function()
			expect(rules(UNSAFE)):toEqual({ "lookup-or-literal" })
			expect(rules('local v = list[1] or "x"')):toEqual({})
			expect(rules('local v = args[key] or "x"')):toEqual({})
			expect(rules('local v = list[] or "x"')):toEqual({})
		end)

		it("flags a discarded protected call unless it is best effort or consumed", function()
			expect(rules("pcall(writeProfile)")):toEqual({ "discarded-pcall" })
			expect(rules("pcall(cleanupRows)")):toEqual({})
			expect(rules("pcall(Logger.log, message)")):toEqual({})
			expect(rules("local ok = \npcall(writeProfile)")):toEqual({})
			expect(rules("local ok = pcall(writeProfile)")):toEqual({})
		end)

		it("exempts teardown paths from the discarded call rule only", function()
			expect(rules("pcall(writeProfile)", "tools/run.luau")):toEqual({})
			expect(rules(UNSAFE, "tools/run.luau")):toEqual({ "lookup-or-literal" })
		end)

		it("flags an empty-string fallback assigned to a display field", function()
			expect(rules('Text = catalog.first or ""')):toEqual({ "display-empty-fallback" })
			expect(rules('title = names.first or ""')):toEqual({ "display-empty-fallback" })
			expect(rules('Other = names.first or ""')):toEqual({})
		end)

		it("ignores comments, block comments and skipped paths", function()
			expect(rules("-- " .. UNSAFE)):toEqual({})
			expect(rules("--[[\n" .. UNSAFE .. "\n]]\n")):toEqual({})
			expect(rules(UNSAFE, "area/probe/Case.luau")):toEqual({})
			expect(rules(UNSAFE, "area/Case.verify.luau")):toEqual({})
		end)

		it("reports the line and a bounded snippet", function()
			local hits = SilentFallbacks.lintFile(SELECTED, "local a = 1\n  " .. UNSAFE .. "  \n", CONFIG)
			expect(#hits):toBe(1)
			expect(hits[1].line):toBe(2)
			expect(hits[1].snippet):toBe(UNSAFE)
			expect(#SilentFallbacks.normalize(string.rep("x ", 200))):toBe(160)
		end)
	end)

	describe("silent fallback check", function()
		it("ignores unrelated stale and unreasoned entries in a selected scan", function()
			local code, output = run({ "area" }, true, { entry(SELECTED), entry(OTHER, "") }, { [SELECTED] = UNSAFE })
			expect(code):toBe(0)
			expect(output):toContain("1 authored")
		end)

		it("keeps selected unsafe fallbacks red", function()
			local code, output = run({ "area" }, true, { entry(OTHER) }, { [SELECTED] = UNSAFE })
			expect(code):toBe(1)
			expect(output):toContain("1 silent fallback(s)")
			expect(output):toContain(SELECTED)
		end)

		it("keeps selected stale entries red", function()
			local code, output = run({ "area" }, true, { entry(SELECTED) }, { [SELECTED] = "local text = labels[key]" })
			expect(code):toBe(1)
			expect(output):toContain("1 allowlist entry(s) match nothing")
		end)

		it("keeps selected deleted-file entries red", function()
			local code, output = run({ "area" }, true, { entry(SELECTED) }, {})
			expect(code):toBe(1)
			expect(output):toContain("match nothing")
		end)

		it("keeps selected unreasoned entries red", function()
			local code, output = run({ "area" }, true, { entry(SELECTED, "") }, { [SELECTED] = UNSAFE })
			expect(code):toBe(1)
			expect(output):toContain("carry no disposition or reason")
		end)

		it("does not report pending entries outside the selection", function()
			local other = entry(OTHER)
			other.disposition = "pending"
			local code, output = run({ "area" }, true, { entry(SELECTED), other }, { [SELECTED] = UNSAFE })
			expect(code):toBe(0)
			expect(string.find(output, OTHER, 1, true)):toBeNil()
			expect(output):toContain("0 pending")
		end)

		it("prints pending entries inside the scope with their reason", function()
			local pending = entry(SELECTED)
			pending.disposition = "pending"
			local code, output = run({ "area" }, true, { pending }, { [SELECTED] = UNSAFE })
			expect(code):toBe(0)
			expect(output):toContain("scan: pending " .. SELECTED)
			expect(output):toContain("0 authored, 1 pending")
		end)

		it("checks stale and unreasoned global entries during a full scan", function()
			local code, output = run(
				{ "area", "shared" },
				false,
				{ entry(SELECTED), entry(OTHER) },
				{ [SELECTED] = UNSAFE }
			)
			expect(code):toBe(1)
			expect(output):toContain("match nothing")
			expect(output):toContain(OTHER)
			local missing, detail = run({ "area" }, false, { entry(OTHER, "") }, {})
			expect(missing):toBe(1)
			expect(detail):toContain("carry no disposition or reason")
		end)

		it("selects directory descendants without selecting similarly prefixed directories", function()
			local selected = SilentFallbacks.selectEntries(
				{ entry(SELECTED), entry("area-other/Bad.luau", "") },
				{ "area" },
				true
			)
			expect(#selected):toBe(1)
			expect(selected[1].path):toBe(SELECTED)
		end)
	end)
end
