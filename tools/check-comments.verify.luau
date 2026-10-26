--!strict

local Check = require("./check-comments")
local Verify = require("../.lute/dependencies/verify/src/core")
local Bdd = require("../.lute/dependencies/verify/src/bdd")

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("check comments", function()
		it("ignores comment text inside string literals", function()
			expect(#Check.added("", '--!strict\nlocal x = "-- text"\nreturn x')):toBe(0)
			expect(#Check.added("", "local x = [=[-- text]=]\nreturn `-- {x}`")):toBe(0)
		end)

		it("reports an inline comment", function()
			expect(Check.added("", "local x = 1 -- new comment\nreturn x")[1]):toBe(1)
		end)

		it("reports a trailing comment", function()
			expect(Check.added("", "return 1\n-- trailing comment")[1]):toBe(2)
		end)

		it("reports a block comment", function()
			expect(Check.added("", "--[[ block comment ]]\nreturn 1")[1]):toBe(1)
		end)

		it("keeps comments that already exist", function()
			expect(#Check.added("-- existing\nreturn 1", "-- existing\nreturn 2")):toBe(0)
			expect(#Check.added("-- existing\nreturn 1", "-- existing\n-- existing\nreturn 2")):toBe(1)
		end)

		it("keeps required license notices", function()
			expect(#Check.added("", "--[[Copyright Example\nPermission is hereby granted, free of charge.]]\nreturn 1")):toBe(
				0
			)
		end)
	end)
end
