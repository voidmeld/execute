--!strict

local CommitPolicy = require("./commit-policy")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

local RULES: CommitPolicy.Rules = {
	author = { name = "author", email = "author@example.invalid" },
	committer = { name = "author", email = "author@example.invalid" },
	forbiddenTrailers = { "Co-authored-by" },
}

local function record(
	sha: string,
	authorName: string,
	authorEmail: string,
	committerName: string,
	committerEmail: string,
	message: string
): string
	return table.concat({ sha, authorName, authorEmail, committerName, committerEmail, message }, CommitPolicy.FIELD)
		.. CommitPolicy.RECORD
end

local CLEAN = record("aaa", "author", "author@example.invalid", "author", "author@example.invalid", "Add a thing\n")

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("commit policy", function()
		it("parses a clean log", function()
			local commits, parseError = CommitPolicy.parseLog(CLEAN)
			expect(parseError):toBeNil()
			assert(commits)
			expect(#(assert(commits))):toBe(1)
			expect((assert(commits))[1].sha):toBe("aaa")
			expect((assert(commits))[1].message):toBe("Add a thing")
		end)

		it("refuses a malformed log", function()
			local commits, parseError =
				CommitPolicy.parseLog("only" .. CommitPolicy.FIELD .. "two" .. CommitPolicy.RECORD)
			expect(commits):toBeNil()
			assert(parseError)
		end)

		it("parses an empty log", function()
			local commits, parseError = CommitPolicy.parseLog("")
			expect(parseError):toBeNil()
			assert(commits)
			expect(#(assert(commits))):toBe(0)
		end)

		it("detects trailers only as trailers", function()
			expect(CommitPolicy.hasTrailer("Subject\n\nCo-authored-by: someone", "Co-authored-by")):toBeTruthy()
			expect(CommitPolicy.hasTrailer("Subject\n\n  co-AUTHORED-by : someone", "Co-authored-by")):toBeTruthy()
			expect(CommitPolicy.hasTrailer("Subject mentioning co-authored-by inline", "Co-authored-by")):toBeFalsy()
			expect(CommitPolicy.hasTrailer("Subject\n\nSigned-off-by: someone", "Co-authored-by")):toBeFalsy()
		end)

		it("refuses an empty candidate", function()
			local verdict = CommitPolicy.evaluate({}, RULES)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_commits_empty")
		end)

		it("passes a clean candidate", function()
			local commits = assert(CommitPolicy.parseLog(CLEAN))
			local verdict = CommitPolicy.evaluate(commits, RULES)
			assert(verdict.status == "pass")
			expect((verdict).count):toBe(1)
		end)

		it("refuses a wrong author", function()
			local wrongAuthor =
				record("bbb", "other", "other@example.invalid", "author", "author@example.invalid", "Subject")
			local commits = assert(CommitPolicy.parseLog(wrongAuthor))
			local verdict = CommitPolicy.evaluate(commits, RULES)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_author_mismatch")
		end)

		it("refuses a wrong committer", function()
			local wrongCommitter =
				record("ccc", "author", "author@example.invalid", "other", "other@example.invalid", "Subject")
			local commits = assert(CommitPolicy.parseLog(wrongCommitter))
			local verdict = CommitPolicy.evaluate(commits, RULES)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_committer_mismatch")
		end)

		it("refuses a forbidden trailer", function()
			local trailered = record(
				"ddd",
				"author",
				"author@example.invalid",
				"author",
				"author@example.invalid",
				"Subject\n\nCo-authored-by: helper"
			)
			local commits = assert(CommitPolicy.parseLog(trailered))
			local verdict = CommitPolicy.evaluate(commits, RULES)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_forbidden_trailer")
		end)

		it("reads the range through the injected command", function()
			local seen: { string }? = nil
			local verdict = CommitPolicy.runRange("main", "feature", RULES, function(argv: { string })
				seen = argv
				return { exitcode = 0, stdout = CLEAN, stderr = "" }
			end)
			assert(verdict.status == "pass")
			assert(seen)
			expect((assert(seen))[4]):toBe("main..feature")
		end)

		it("refuses an unreadable log", function()
			local verdict = CommitPolicy.runRange("main", "feature", RULES, function()
				return { exitcode = 128, stdout = "", stderr = "bad revision" }
			end)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_commit_log_unreadable")
		end)

		it("refuses a malformed range log", function()
			local verdict = CommitPolicy.runRange("main", "feature", RULES, function()
				return {
					exitcode = 0,
					stdout = "one" .. CommitPolicy.FIELD .. "two" .. CommitPolicy.RECORD,
					stderr = "",
				}
			end)
			assert(verdict.status == "refuse")
			expect((verdict).reason):toBe("candidate_commit_log_malformed")
		end)
	end)
end
