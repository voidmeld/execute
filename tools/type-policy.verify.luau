--!strict

local fs = require("@std/fs")
local process = require("@lute/process")
local Verify = require("../.lute/dependencies/verify/src/core")
local Bdd = require("../.lute/dependencies/verify/src/bdd")
local TemporaryDirectory = require("../.lute/dependencies/verify/src/checks").temporaryDirectory

type Probe = { name: string, source: string, accepted: boolean }
local probes: { Probe } = {
	{
		name = "accepts narrowed unknown values",
		source = '--!strict\nlocal value: unknown = 1\nreturn if type(value) == "number" then value else 0\n',
		accepted = true,
	},
	{ name = "rejects explicit any", source = "--!strict\nlocal value: any = 1\nreturn value\n", accepted = false },
	{ name = "rejects concrete casts", source = "--!strict\nreturn 1 :: number\n", accepted = false },
	{ name = "rejects unknown casts", source = "--!strict\nreturn 1 :: unknown\n", accepted = false },
	{ name = "rejects nonstrict files", source = "--!nonstrict\nreturn 1\n", accepted = false },
	{ name = "rejects unchecked files", source = "--!nocheck\nreturn 1\n", accepted = false },
}

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect
	describe("repository syntax policy", function()
		for _, probe in probes do
			it(probe.name, function()
				local root = process.cwd()
				TemporaryDirectory.run(root .. "/.lute/tmp", "syntax-policy", function(fixture)
					local initialized = process.run({ "git", "init", "-q", fixture })
					assert(initialized.ok, initialized.stderr)
					fs.writeStringToFile(fixture .. "/input.luau", probe.source)
					local result = process.run({ "lute", "run", root .. "/tools/check-no-any.luau" }, { cwd = fixture })
					expect(result.ok):toBe(probe.accepted)
					return true
				end)
			end)
		end
	end)
end
