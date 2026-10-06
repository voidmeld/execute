--!strict

local Check = require("./check-comments")
local Verify = require("../.lute/dependencies/verify/src/core")

return function(suite: Verify.Harness)
	suite:case("ignores comment text inside string literals", function(context)
		context:expect(#Check.added("", '--!strict\nlocal x = "-- text"\nreturn x')):toBe(0)
		context:expect(#Check.added("", "local x = [=[-- text]=]\nreturn `-- {x}`")):toBe(0)
	end)

	suite:case("reports an inline comment", function(context)
		context:expect(Check.added("", "local x = 1 -- new comment\nreturn x")[1]):toBe(1)
	end)

	suite:case("reports a trailing comment", function(context)
		context:expect(Check.added("", "return 1\n-- trailing comment")[1]):toBe(2)
	end)

	suite:case("reports a block comment", function(context)
		context:expect(Check.added("", "--[[ block comment ]]\nreturn 1")[1]):toBe(1)
	end)

	suite:case("keeps comments that already exist", function(context)
		context:expect(#Check.added("-- existing\nreturn 1", "-- existing\nreturn 2")):toBe(0)
		context:expect(#Check.added("-- existing\nreturn 1", "-- existing\n-- existing\nreturn 2")):toBe(1)
	end)

	suite:case("keeps required license notices", function(context)
		context
			:expect(
				#Check.added("", "--[[Copyright Example\nPermission is hereby granted, free of charge.]]\nreturn 1")
			)
			:toBe(0)
	end)
end
