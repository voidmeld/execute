--!strict

local Guarded = require("./guarded-surface")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local TIER: Guarded.Tier = {
	name = "Sealed",
	exactFiles = { "docs/SEALED.md", "tools/gate.luau" },
	prefixes = { "policy/**" },
}

type DependenciesOverrides = {
	mixedDiff: ((path: string) -> string?)?,
	mixedBase: ((path: string) -> string?)?,
	mixedHead: ((path: string) -> string?)?,
}

local function deps(overrides: DependenciesOverrides): Guarded.Dependencies
	local base: Guarded.Dependencies = {
		mixedDiff = function(): string?
			return ""
		end,
		mixedBase = function(): string?
			return ""
		end,
		mixedHead = function(): string?
			return ""
		end,
	}
	base.mixedDiff = overrides.mixedDiff or base.mixedDiff
	base.mixedBase = overrides.mixedBase or base.mixedBase
	base.mixedHead = overrides.mixedHead or base.mixedHead
	return base
end

local POLICY: Guarded.Policy = {
	tiers = { TIER },
	mixed = { path = "docs/MIXED.md", sectionPattern = "^##%s+Law" },
	reason = "sealed_requires_seat",
	passDetail = "change touches no sealed surface",
	authorizedDetail = function(actual: string): string
		return "verified " .. actual .. " may edit sealed surfaces"
	end,
	refusalDetail = function(offending: { string }, authority: Guarded.Authority): string
		return ("actual=%s recorded=%s offending=%s"):format(
			authority.actual or "UNVERIFIABLE",
			authority.recorded or "UNVERIFIABLE",
			table.concat(offending, "; ")
		)
	end,
}

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("guarded surface", function()
		it("matches the rule of a path", function()
			expect(Guarded.matchedRule("docs/SEALED.md", TIER)):toBe("docs/SEALED.md")
			expect(Guarded.matchedRule("policy/anything/deep.md", TIER)):toBe("policy/**")
			expect(Guarded.matchedRule("src/main.luau", TIER)):toBeNil()
		end)

		it("parses diff hunks", function()
			local hunks = Guarded.parseHunks("@@ -3,4 +3,6 @@ context\nline\n@@ -20 +22 @@\n")
			expect(#hunks):toBe(2)
			expect(hunks[1].oldStart):toBe(3)
			expect(hunks[1].oldCount):toBe(4)
			expect(hunks[1].newStart):toBe(3)
			expect(hunks[1].newCount):toBe(6)
			expect(hunks[2].oldCount):toBe(1)
			expect(hunks[2].newCount):toBe(1)
		end)

		it("indexes headings", function()
			local text = "# Title\n\n## Law\n\nrule\n\n## Prose\n\nnote\n"
			local index = Guarded.headingIndex(text)
			expect(#index):toBe(2)
			expect(Guarded.headingAt(index, 1)):toBeNil()
			expect(Guarded.headingAt(index, 5)):toBe("## Law")
			expect(Guarded.headingAt(index, 9)):toBe("## Prose")
		end)

		it("finds touched sections", function()
			local text = "# Title\n\n## Law\n\nrule\n\n## Prose\n\nnote\n"
			local touchedLaw = Guarded.sectionsTouched("@@ -5,1 +5,1 @@\n", text, text, "^##%s+Law")
			expect(#touchedLaw):toBe(1)
			expect(touchedLaw[1]):toBe("## Law")
			local touchedProse = Guarded.sectionsTouched("@@ -9,1 +9,1 @@\n", text, text, "^##%s+Law")
			expect(#touchedProse):toBe(0)
		end)

		it("passes a change with no guarded path", function()
			local verdict = Guarded.evaluate({ "src/main.luau" }, POLICY, { actual = nil, recorded = nil }, deps({}))
			expect(verdict.status):toBe("pass")
			expect((verdict :: Guarded.Pass).detail):toBe("change touches no sealed surface")
		end)

		it("refuses a guarded path without authority", function()
			local verdict = Guarded.evaluate(
				{ "docs/SEALED.md" },
				POLICY,
				{ actual = nil, recorded = "seat" },
				deps({})
			)
			expect(verdict.status):toBe("refuse")
			expect((verdict :: Guarded.Refuse).reason):toBe("sealed_requires_seat")
			expect(#(verdict :: Guarded.Refuse).paths):toBe(1)
			expect((verdict :: Guarded.Refuse).paths[1]):toContain("Sealed rule: docs/SEALED.md")
		end)

		it("passes a verified seat", function()
			local verdict = Guarded.evaluate(
				{ "policy/x.md" },
				POLICY,
				{ actual = "seat", recorded = "seat" },
				deps({})
			)
			expect(verdict.status):toBe("pass")
			expect((verdict :: Guarded.Pass).detail):toBe("verified seat may edit sealed surfaces")
		end)

		it("refuses another seat", function()
			local verdict = Guarded.evaluate(
				{ "policy/x.md" },
				POLICY,
				{ actual = "other", recorded = "seat" },
				deps({})
			)
			expect(verdict.status):toBe("refuse")
		end)

		it("evaluates mixed documents by section", function()
			local text = "# Mixed\n\n## Law\n\nrule\n\n## Prose\n\nnote\n"
			local touching = Guarded.evaluate(
				{ "docs/MIXED.md" },
				POLICY,
				{ actual = nil, recorded = nil },
				deps({
					mixedDiff = function(): string?
						return "@@ -5,1 +5,1 @@\n"
					end,
					mixedBase = function(): string?
						return text
					end,
					mixedHead = function(): string?
						return text
					end,
				})
			)
			expect(touching.status):toBe("refuse")
			expect((touching :: Guarded.Refuse).paths[1]):toContain("guarded sections touched")

			local sparing = Guarded.evaluate(
				{ "docs/MIXED.md" },
				POLICY,
				{ actual = nil, recorded = nil },
				deps({
					mixedDiff = function(): string?
						return "@@ -9,1 +9,1 @@\n"
					end,
					mixedBase = function(): string?
						return text
					end,
					mixedHead = function(): string?
						return text
					end,
				})
			)
			expect(sparing.status):toBe("pass")
		end)

		it("refuses an unreadable mixed diff", function()
			local unreadable = Guarded.evaluate(
				{ "docs/MIXED.md" },
				POLICY,
				{ actual = nil, recorded = nil },
				deps({
					mixedDiff = function(): string?
						return nil
					end,
				})
			)
			expect(unreadable.status):toBe("refuse")
			expect((unreadable :: Guarded.Refuse).paths[1]):toContain("UNPROVABLE")
		end)

		it("applies the override only to refusals", function()
			local refused = Guarded.evaluate(
				{ "docs/SEALED.md" },
				POLICY,
				{ actual = "other", recorded = "seat" },
				deps({})
			)
			local overridden = Guarded.withOverride(refused, true, "OWNER_OVERRIDE=1", "bank the override")
			expect(overridden.status):toBe("pass_override")
			expect((overridden :: Guarded.PassOverride).bypassed):toBe("sealed_requires_seat")
			expect((overridden :: Guarded.PassOverride).warning):toContain("OWNER_OVERRIDE=1")
			expect((overridden :: Guarded.PassOverride).banking):toBe("bank the override")

			local kept = Guarded.withOverride(refused, false, "OWNER_OVERRIDE=1", "bank the override")
			expect(kept.status):toBe("refuse")

			local passed = Guarded.evaluate({ "src/main.luau" }, POLICY, { actual = nil, recorded = nil }, deps({}))
			expect(Guarded.withOverride(passed, true, "OWNER_OVERRIDE=1", "bank the override").status):toBe("pass")
		end)
	end)
end
