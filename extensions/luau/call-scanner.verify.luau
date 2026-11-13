--!strict

local CallScanner = require("./call-scanner")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("call scanner", function()
		it("skips quoted text, long brackets and comments", function()
			expect(CallScanner.skipQuoted('"a\\"b" tail', 1)):toBe(7)
			expect(CallScanner.skipQuoted('"open', 1)):toBe(6)
			expect(CallScanner.skipLong("[==[x]]y]==] z", 1)):toBe(13)
			expect(CallScanner.skipLong("[x]", 1)):toBeNil()
			expect(CallScanner.skipLong("[[open", 1)):toBe(7)
			expect(CallScanner.skipComment("-- one\ntwo", 1)):toBe(7)
			expect(CallScanner.skipComment("--[[ a\nb ]] c", 1)):toBe(12)
		end)

		it("counts the bytes a literal body produces", function()
			expect(CallScanner.literalBytes("abc")):toBe(3)
			expect(CallScanner.literalBytes("a\\nb")):toBe(3)
			expect(CallScanner.literalBytes("\\65\\x41")):toBe(2)
			expect(CallScanner.literalBytes("a\\zb")):toBe(2)
			expect(CallScanner.literalBytes("\\u{20AC}")):toBe(3)
		end)

		it("splits arguments at top-level commas only", function()
			expect(CallScanner.splitTop('a, f(b, c), "x,y", {1, 2}, [k]')):toEqual({
				"a",
				" f(b, c)",
				' "x,y"',
				" {1, 2}",
				" [k]",
			})
			expect(CallScanner.splitTop("")):toEqual({ "" })
		end)

		it("reduces an expression to its top-level shape", function()
			expect(CallScanner.topLevel('f(x) .. "s" + {1}')):toBe("f() .. S + {}")
		end)

		it("recognizes a call that spans the whole expression", function()
			expect(CallScanner.wholeCall("math.max(a, b)", "math.max(")):toEqual({ "a", " b" })
			expect(CallScanner.wholeCall("math.max(a) + 1", "math.max(")):toBeNil()
			expect(CallScanner.wholeCall("other(a)", "math.max(")):toBeNil()
		end)

		it("finds method calls and skips declarations, strings and comments", function()
			local source = table.concat({
				"local part = make()",
				'part:Mark("a", f(1, 2))',
				'local text = ":Mark(ignored)"',
				"-- part:Mark(commented)",
				"function Class:Mark(name)",
				"end",
				"part :Mark(7)",
			}, "\n")
			local calls = CallScanner.findCalls(source, ":Mark(")
			expect(#calls):toBe(2)
			expect(calls[1].args):toEqual({ '"a"', " f(1, 2)" })
			expect(CallScanner.lineOf(source, calls[1].start)):toBe(2)
			expect(calls[2].args):toEqual({ "7" })
			expect(CallScanner.lineOf(source, calls[2].start)):toBe(7)
		end)

		it("finds member references that are not declarations or type queries", function()
			local source = table.concat({
				"part.Mark(part, 1)",
				"local read = part.Mark",
				"function Class.Mark(self) end",
				"local t: typeof(part.Mark)",
				'local s = ".Mark"',
			}, "\n")
			local positions = CallScanner.findReferences(source, "Mark")
			expect(#positions):toBe(2)
			expect(CallScanner.lineOf(source, positions[1])):toBe(1)
			expect(CallScanner.lineOf(source, positions[2])):toBe(2)
			expect(#CallScanner.findReferences("local x = 1", "Mark")):toBe(0)
		end)

		it("maps positions to line numbers", function()
			expect(CallScanner.lineOf("a\nb\nc", 1)):toBe(1)
			expect(CallScanner.lineOf("a\nb\nc", 5)):toBe(3)
		end)
	end)
end
