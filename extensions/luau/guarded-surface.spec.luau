--!strict

local Guarded = require("./guarded-surface")
local Verify = require("../../.lute/dependencies/verify/src/core")

local DOCUMENT = table.concat({
	"# Constitution",
	"",
	"## Sealed",
	"",
	"Sealed surfaces are docs/SEALED.md, tools/gate.luau, and everything under policy/** (aside).",
	"",
	"## Open",
	"",
	"Everything else is open.",
	"",
}, "\n")

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
	suite:case("extracts a section", function(context)
		local section = Guarded.sectionText(DOCUMENT, "^##%s+Sealed")
		context:expect(section):toBeTruthy()
		context:expect(section :: string):toContain("docs/SEALED.md")
		context:expect(section :: string).never:toContain("Everything else is open")
		context:expect(Guarded.sectionText(DOCUMENT, "^##%s+Absent")):toBeNil()
	end)

	suite:case("strips parenthesized asides", function(context)
		context:expect(Guarded.withoutAsides("keep (drop (nested)) keep")):toBe("keep   keep")
	end)

	suite:case("reads guarded paths from a section", function(context)
		local section = Guarded.sectionText(DOCUMENT, "^##%s+Sealed") :: string
		local exactFiles, prefixes = Guarded.pathsFromSection(section)
		context:expect(#prefixes):toBe(1)
		context:expect(prefixes[1]):toBe("policy/**")
		local found: { [string]: boolean } = {}
		for _, path in exactFiles do
			found[path] = true
		end
		context:expect(found["docs/SEALED.md"]):toBeTruthy()
		context:expect(found["tools/gate.luau"]):toBeTruthy()
		context:expect(found["aside"]):toBeFalsy()
	end)

	suite:case("matches the rule of a path", function(context)
		context:expect(Guarded.matchedRule("docs/SEALED.md", TIER)):toBe("docs/SEALED.md")
		context:expect(Guarded.matchedRule("policy/anything/deep.md", TIER)):toBe("policy/**")
		context:expect(Guarded.matchedRule("src/main.luau", TIER)):toBeNil()
	end)

	suite:case("parses diff hunks", function(context)
		local hunks = Guarded.parseHunks("@@ -3,4 +3,6 @@ context\nline\n@@ -20 +22 @@\n")
		context:expect(#hunks):toBe(2)
		context:expect(hunks[1].oldStart):toBe(3)
		context:expect(hunks[1].oldCount):toBe(4)
		context:expect(hunks[1].newStart):toBe(3)
		context:expect(hunks[1].newCount):toBe(6)
		context:expect(hunks[2].oldCount):toBe(1)
		context:expect(hunks[2].newCount):toBe(1)
	end)

	suite:case("indexes headings", function(context)
		local text = "# Title\n\n## Law\n\nrule\n\n## Prose\n\nnote\n"
		local index = Guarded.headingIndex(text)
		context:expect(#index):toBe(2)
		context:expect(Guarded.headingAt(index, 1)):toBeNil()
		context:expect(Guarded.headingAt(index, 5)):toBe("## Law")
		context:expect(Guarded.headingAt(index, 9)):toBe("## Prose")
	end)

	suite:case("finds touched sections", function(context)
		local text = "# Title\n\n## Law\n\nrule\n\n## Prose\n\nnote\n"
		local touchedLaw = Guarded.sectionsTouched("@@ -5,1 +5,1 @@\n", text, text, "^##%s+Law")
		context:expect(#touchedLaw):toBe(1)
		context:expect(touchedLaw[1]):toBe("## Law")
		local touchedProse = Guarded.sectionsTouched("@@ -9,1 +9,1 @@\n", text, text, "^##%s+Law")
		context:expect(#touchedProse):toBe(0)
	end)

	suite:case("passes a change with no guarded path", function(context)
		local verdict = Guarded.evaluate({ "src/main.luau" }, POLICY, { actual = nil, recorded = nil }, deps({}))
		context:expect(verdict.status):toBe("pass")
		context:expect((verdict :: Guarded.Pass).detail):toBe("change touches no sealed surface")
	end)

	suite:case("refuses a guarded path without authority", function(context)
		local verdict = Guarded.evaluate({ "docs/SEALED.md" }, POLICY, { actual = nil, recorded = "seat" }, deps({}))
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: Guarded.Refuse).reason):toBe("sealed_requires_seat")
		context:expect(#(verdict :: Guarded.Refuse).paths):toBe(1)
		context:expect((verdict :: Guarded.Refuse).paths[1]):toContain("Sealed rule: docs/SEALED.md")
	end)

	suite:case("passes a verified seat", function(context)
		local verdict = Guarded.evaluate({ "policy/x.md" }, POLICY, { actual = "seat", recorded = "seat" }, deps({}))
		context:expect(verdict.status):toBe("pass")
		context:expect((verdict :: Guarded.Pass).detail):toBe("verified seat may edit sealed surfaces")
	end)

	suite:case("refuses another seat", function(context)
		local verdict = Guarded.evaluate({ "policy/x.md" }, POLICY, { actual = "other", recorded = "seat" }, deps({}))
		context:expect(verdict.status):toBe("refuse")
	end)

	suite:case("evaluates mixed documents by section", function(context)
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
		context:expect(touching.status):toBe("refuse")
		context:expect((touching :: Guarded.Refuse).paths[1]):toContain("guarded sections touched")

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
		context:expect(sparing.status):toBe("pass")
	end)

	suite:case("refuses an unreadable mixed diff", function(context)
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
		context:expect(unreadable.status):toBe("refuse")
		context:expect((unreadable :: Guarded.Refuse).paths[1]):toContain("UNPROVABLE")
	end)

	suite:case("applies the override only to refusals", function(context)
		local refused = Guarded.evaluate(
			{ "docs/SEALED.md" },
			POLICY,
			{ actual = "other", recorded = "seat" },
			deps({})
		)
		local overridden = Guarded.withOverride(refused, true, "OWNER_OVERRIDE=1", "bank the override")
		context:expect(overridden.status):toBe("pass_override")
		context:expect((overridden :: Guarded.PassOverride).bypassed):toBe("sealed_requires_seat")
		context:expect((overridden :: Guarded.PassOverride).warning):toContain("OWNER_OVERRIDE=1")
		context:expect((overridden :: Guarded.PassOverride).banking):toBe("bank the override")

		local kept = Guarded.withOverride(refused, false, "OWNER_OVERRIDE=1", "bank the override")
		context:expect(kept.status):toBe("refuse")

		local passed = Guarded.evaluate({ "src/main.luau" }, POLICY, { actual = nil, recorded = nil }, deps({}))
		context:expect(Guarded.withOverride(passed, true, "OWNER_OVERRIDE=1", "bank the override").status):toBe("pass")
	end)
end
