--!strict

local CommitPolicy = require("./commit-policy")
local Verify = require("../../.lute/dependencies/verify/src/core")

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
	suite:case("parses a clean log", function(context)
		local commits, parseError = CommitPolicy.parseLog(CLEAN)
		context:expect(parseError):toBeNil()
		context:expect(commits):toBeTruthy()
		context:expect(#(commits :: { CommitPolicy.Commit })):toBe(1)
		context:expect((commits :: { CommitPolicy.Commit })[1].sha):toBe("aaa")
		context:expect((commits :: { CommitPolicy.Commit })[1].message):toBe("Add a thing")
	end)

	suite:case("refuses a malformed log", function(context)
		local commits, parseError = CommitPolicy.parseLog("only" .. CommitPolicy.FIELD .. "two" .. CommitPolicy.RECORD)
		context:expect(commits):toBeNil()
		context:expect(parseError):toBeTruthy()
	end)

	suite:case("parses an empty log", function(context)
		local commits, parseError = CommitPolicy.parseLog("")
		context:expect(parseError):toBeNil()
		context:expect(commits):toBeTruthy()
		context:expect(#(commits :: { CommitPolicy.Commit })):toBe(0)
	end)

	suite:case("detects trailers only as trailers", function(context)
		context:expect(CommitPolicy.hasTrailer("Subject\n\nCo-authored-by: someone", "Co-authored-by")):toBeTruthy()
		context:expect(CommitPolicy.hasTrailer("Subject\n\n  co-AUTHORED-by : someone", "Co-authored-by")):toBeTruthy()
		context
			:expect(CommitPolicy.hasTrailer("Subject mentioning co-authored-by inline", "Co-authored-by"))
			:toBeFalsy()
		context:expect(CommitPolicy.hasTrailer("Subject\n\nSigned-off-by: someone", "Co-authored-by")):toBeFalsy()
	end)

	suite:case("refuses an empty candidate", function(context)
		local verdict = CommitPolicy.evaluate({}, RULES)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_commits_empty")
	end)

	suite:case("passes a clean candidate", function(context)
		local commits = CommitPolicy.parseLog(CLEAN) :: { CommitPolicy.Commit }
		local verdict = CommitPolicy.evaluate(commits, RULES)
		context:expect(verdict.status):toBe("pass")
		context:expect((verdict :: CommitPolicy.Pass).count):toBe(1)
	end)

	suite:case("refuses a wrong author", function(context)
		local wrongAuthor =
			record("bbb", "other", "other@example.invalid", "author", "author@example.invalid", "Subject")
		local commits = CommitPolicy.parseLog(wrongAuthor) :: { CommitPolicy.Commit }
		local verdict = CommitPolicy.evaluate(commits, RULES)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_author_mismatch")
	end)

	suite:case("refuses a wrong committer", function(context)
		local wrongCommitter =
			record("ccc", "author", "author@example.invalid", "other", "other@example.invalid", "Subject")
		local commits = CommitPolicy.parseLog(wrongCommitter) :: { CommitPolicy.Commit }
		local verdict = CommitPolicy.evaluate(commits, RULES)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_committer_mismatch")
	end)

	suite:case("refuses a forbidden trailer", function(context)
		local trailered = record(
			"ddd",
			"author",
			"author@example.invalid",
			"author",
			"author@example.invalid",
			"Subject\n\nCo-authored-by: helper"
		)
		local commits = CommitPolicy.parseLog(trailered) :: { CommitPolicy.Commit }
		local verdict = CommitPolicy.evaluate(commits, RULES)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_forbidden_trailer")
	end)

	suite:case("reads the range through the injected command", function(context)
		local seen: { string }? = nil
		local verdict = CommitPolicy.runRange("main", "feature", RULES, function(argv: { string })
			seen = argv
			return { exitcode = 0, stdout = CLEAN, stderr = "" }
		end)
		context:expect(verdict.status):toBe("pass")
		context:expect(seen):toBeTruthy()
		context:expect((seen :: { string })[4]):toBe("main..feature")
	end)

	suite:case("refuses an unreadable log", function(context)
		local verdict = CommitPolicy.runRange("main", "feature", RULES, function()
			return { exitcode = 128, stdout = "", stderr = "bad revision" }
		end)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_commit_log_unreadable")
	end)

	suite:case("refuses a malformed range log", function(context)
		local verdict = CommitPolicy.runRange("main", "feature", RULES, function()
			return { exitcode = 0, stdout = "one" .. CommitPolicy.FIELD .. "two" .. CommitPolicy.RECORD, stderr = "" }
		end)
		context:expect(verdict.status):toBe("refuse")
		context:expect((verdict :: CommitPolicy.Refuse).reason):toBe("candidate_commit_log_malformed")
	end)
end
