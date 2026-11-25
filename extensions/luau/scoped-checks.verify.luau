--!strict

local ScopedChecks = require("./scoped-checks")
local Verify = require("@verify/src/core")
local Bdd = require("@verify/src/bdd")

local groups: { ScopedChecks.Group } = {
	{
		name = "routes",
		paths = { "^web/routes/" },
		specs = { "^tests/Route[^/]*%.verify%.luau$" },
		checks = { { "tools/audit.luau" } },
	},
	{
		name = "assets",
		paths = { "^assets/" },
		specs = { "^tests/Route[^/]*%.verify%.luau$", "^tests/Assets%.verify%.luau$" },
		checks = { { "tools/audit.luau" }, { "tools/rights.luau" } },
	},
}

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("scoped checks", function()
		it("matches path patterns", function()
			expect(ScopedChecks.matches("assets/a.png", { "^docs/", "^assets/" })):toBeTruthy()
			expect(ScopedChecks.matches("src/a.luau", { "^docs/", "^assets/" })):toBeFalsy()
		end)

		it("selects touched and unowned paths", function()
			local touched = ScopedChecks.touched({ "web/routes/a.luau", "README.md" }, groups)
			expect(#touched):toBe(1)
			expect(touched[1].name):toBe("routes")
			expect(#ScopedChecks.touched({ "README.md" }, groups)):toBe(0)
			local unowned = ScopedChecks.unowned({ "web/routes/a.luau", "README.md", "src/b.luau" }, groups)
			expect(#unowned):toBe(2)
			expect(unowned[1]):toBe("README.md")
			expect(unowned[2]):toBe("src/b.luau")
		end)

		it("selects specs and checks by owning group", function()
			local candidates = {
				"tests/RouteB.verify.luau",
				"tests/Assets.verify.luau",
				"tests/RouteA.verify.luau",
				"tests/Other.verify.luau",
			}
			local selection = ScopedChecks.select({ "web/routes/a.luau" }, groups, candidates, nil)
			expect(#selection.specs):toBe(2)
			expect(selection.specs[1]):toBe("tests/RouteA.verify.luau")
			expect(#selection.checks):toBe(1)
			expect(selection.checks[1][1]):toBe("tools/audit.luau")

			local both = ScopedChecks.select({ "web/routes/a.luau", "assets/b.png" }, groups, candidates, nil)
			expect(#both.specs):toBe(3)
			expect(#both.checks):toBe(2)

			local dropped = ScopedChecks.select({ "web/routes/a.luau" }, groups, candidates, function(spec: string)
				return spec ~= "tests/RouteB.verify.luau"
			end)
			expect(#dropped.specs):toBe(1)
			expect(dropped.specs[1]):toBe("tests/RouteA.verify.luau")

			local none = ScopedChecks.select({ "README.md" }, groups, candidates, nil)
			expect(#none.groups):toBe(0)
			expect(#none.specs):toBe(0)
			expect(#none.checks):toBe(0)
		end)
	end)
end
