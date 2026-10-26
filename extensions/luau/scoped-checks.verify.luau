--!strict

local ScopedChecks = require("./scoped-checks")
local Verify = require("../../.lute/dependencies/verify/src/core")

local groups: { ScopedChecks.Group } = {
	{
		name = "zone",
		paths = { "^world/zone/" },
		specs = { "^tests/Zone[^/]*%.verify%.luau$" },
		checks = { { "tools/audit.luau" } },
	},
	{
		name = "art",
		paths = { "^assets/" },
		specs = { "^tests/Zone[^/]*%.verify%.luau$", "^tests/Art%.verify%.luau$" },
		checks = { { "tools/audit.luau" }, { "tools/rights.luau" } },
	},
}

return function(suite: Verify.Harness)
	suite:case("matches path patterns", function(context)
		context:expect(ScopedChecks.matches("assets/a.png", { "^docs/", "^assets/" })):toBeTruthy()
		context:expect(ScopedChecks.matches("src/a.luau", { "^docs/", "^assets/" })):toBeFalsy()
	end)

	suite:case("selects touched and unowned paths", function(context)
		local touched = ScopedChecks.touched({ "world/zone/a.luau", "README.md" }, groups)
		context:expect(#touched):toBe(1)
		context:expect(touched[1].name):toBe("zone")
		context:expect(#ScopedChecks.touched({ "README.md" }, groups)):toBe(0)
		local unowned = ScopedChecks.unowned({ "world/zone/a.luau", "README.md", "src/b.luau" }, groups)
		context:expect(#unowned):toBe(2)
		context:expect(unowned[1]):toBe("README.md")
		context:expect(unowned[2]):toBe("src/b.luau")
	end)

	suite:case("selects specs and checks by owning group", function(context)
		local candidates =
			{ "tests/ZoneB.verify.luau", "tests/Art.verify.luau", "tests/ZoneA.verify.luau", "tests/Other.verify.luau" }
		local selection = ScopedChecks.select({ "world/zone/a.luau" }, groups, candidates, nil)
		context:expect(#selection.specs):toBe(2)
		context:expect(selection.specs[1]):toBe("tests/ZoneA.verify.luau")
		context:expect(#selection.checks):toBe(1)
		context:expect(selection.checks[1][1]):toBe("tools/audit.luau")

		local both = ScopedChecks.select({ "world/zone/a.luau", "assets/b.png" }, groups, candidates, nil)
		context:expect(#both.specs):toBe(3)
		context:expect(#both.checks):toBe(2)

		local dropped = ScopedChecks.select({ "world/zone/a.luau" }, groups, candidates, function(spec: string)
			return spec ~= "tests/ZoneB.verify.luau"
		end)
		context:expect(#dropped.specs):toBe(1)
		context:expect(dropped.specs[1]):toBe("tests/ZoneA.verify.luau")

		local none = ScopedChecks.select({ "README.md" }, groups, candidates, nil)
		context:expect(#none.groups):toBe(0)
		context:expect(#none.specs):toBe(0)
		context:expect(#none.checks):toBe(0)
	end)
end
