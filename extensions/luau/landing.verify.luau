--!strict

local Landing = require("./landing")
local Verify = require("../../.lute/dependencies/verify/src/core")

type CommandResult = Landing.CommandResult
type ConflictPolicy = Landing.ConflictPolicy
type FailurePolicy = Landing.FailurePolicy
type Refusal = Landing.Refusal

local function ok(stdout: string): Landing.CommandResult
	return { exitcode = 0, stdout = stdout, stderr = "" }
end

local function bad(code: number, stderr: string): Landing.CommandResult
	return { exitcode = code, stdout = "", stderr = stderr }
end

local WORKTREE_LIST = table.concat({
	"worktree /repo",
	"HEAD aaaa",
	"branch refs/heads/main",
	"",
	"worktree /repo/.worktrees/feature",
	"HEAD bbbb",
	"branch refs/heads/feature",
	"",
}, "\n")

type GitOverrides = {
	commonDir: (() -> CommandResult)?,
	branchRef: ((branch: string) -> CommandResult)?,
	worktreeList: (() -> CommandResult)?,
	worktreeAdd: ((path: string, branch: string, startPoint: string) -> CommandResult)?,
	worktreeRemove: ((path: string) -> CommandResult)?,
	branchDelete: ((branch: string) -> CommandResult)?,
	rebase: ((worktreePath: string, onto: string) -> CommandResult)?,
	rebaseContinue: ((worktreePath: string) -> CommandResult)?,
	conflictedFiles: ((worktreePath: string) -> CommandResult)?,
	add: ((worktreePath: string, path: string) -> CommandResult)?,
	mergeFastForward: ((branch: string, cwd: string?) -> CommandResult)?,
	resetHard: ((worktreePath: string, sha: string) -> CommandResult)?,
	push: (() -> CommandResult)?,
	fetch: (() -> CommandResult)?,
	revParse: ((ref: string) -> CommandResult)?,
}

local function stubGit(overrides: GitOverrides): Landing.Git
	local base: Landing.Git = {
		commonDir = function(): Landing.CommandResult
			return ok(".git\n")
		end,
		branchRef = function(): Landing.CommandResult
			return ok("1111111111111111111111111111111111111111\n")
		end,
		worktreeList = function(): Landing.CommandResult
			return ok(WORKTREE_LIST)
		end,
		worktreeAdd = function(): Landing.CommandResult
			return ok("")
		end,
		worktreeRemove = function(): Landing.CommandResult
			return ok("")
		end,
		branchDelete = function(): Landing.CommandResult
			return ok("")
		end,
		rebase = function(): Landing.CommandResult
			return ok("")
		end,
		rebaseContinue = function(): Landing.CommandResult
			return ok("")
		end,
		conflictedFiles = function(): Landing.CommandResult
			return ok("")
		end,
		add = function(): Landing.CommandResult
			return ok("")
		end,
		mergeFastForward = function(): Landing.CommandResult
			return ok("2 files changed, 4 insertions(+)")
		end,
		resetHard = function(): Landing.CommandResult
			return ok("")
		end,
		push = function(): Landing.CommandResult
			return ok("")
		end,
		fetch = function(): Landing.CommandResult
			return ok("")
		end,
		revParse = function(): Landing.CommandResult
			return ok("cafecafecafecafecafecafecafecafecafecafe\n")
		end,
	}
	base.commonDir = overrides.commonDir or base.commonDir
	base.branchRef = overrides.branchRef or base.branchRef
	base.worktreeList = overrides.worktreeList or base.worktreeList
	base.worktreeAdd = overrides.worktreeAdd or base.worktreeAdd
	base.worktreeRemove = overrides.worktreeRemove or base.worktreeRemove
	base.branchDelete = overrides.branchDelete or base.branchDelete
	base.rebase = overrides.rebase or base.rebase
	base.rebaseContinue = overrides.rebaseContinue or base.rebaseContinue
	base.conflictedFiles = overrides.conflictedFiles or base.conflictedFiles
	base.add = overrides.add or base.add
	base.mergeFastForward = overrides.mergeFastForward or base.mergeFastForward
	base.resetHard = overrides.resetHard or base.resetHard
	base.push = overrides.push or base.push
	base.fetch = overrides.fetch or base.fetch
	base.revParse = overrides.revParse or base.revParse
	return base
end

type PlanOverrides = {
	base: string?,
	remote: string?,
	trainRoot: string?,
	trainBranchPrefix: string?,
	conflicts: ConflictPolicy?,
	failure: FailurePolicy?,
	setup: ((worktreePath: string) -> Refusal?)?,
	prepare: ((worktreePath: string) -> Refusal?)?,
	commitGuard: ((branch: string) -> Refusal?)?,
	verify: ((worktreePath: string) -> Refusal?)?,
	changeGuard: ((branch: string) -> Refusal?)?,
	log: ((message: string) -> ())?,
}

local function stubPlan(overrides: PlanOverrides): Landing.Plan
	local base: Landing.Plan = {
		base = "main",
		remote = "origin",
		trainRoot = "/repo/.worktrees",
		trainBranchPrefix = "train-",
		conflicts = { resolvers = {}, handAuthored = {}, maxIterations = 4 },
		failure = { maxLines = 4, maxLineChars = 80, patterns = { "^x " } },
		setup = function(): Landing.Refusal?
			return nil
		end,
		prepare = function(): Landing.Refusal?
			return nil
		end,
		commitGuard = function(): Landing.Refusal?
			return nil
		end,
		verify = function(): Landing.Refusal?
			return nil
		end,
		changeGuard = function(): Landing.Refusal?
			return nil
		end,
		log = function() end,
	}
	base.base = overrides.base or base.base
	base.remote = overrides.remote or base.remote
	base.trainRoot = overrides.trainRoot or base.trainRoot
	base.trainBranchPrefix = overrides.trainBranchPrefix or base.trainBranchPrefix
	base.conflicts = overrides.conflicts or base.conflicts
	base.failure = overrides.failure or base.failure
	base.setup = overrides.setup or base.setup
	base.prepare = overrides.prepare or base.prepare
	base.commitGuard = overrides.commitGuard or base.commitGuard
	base.verify = overrides.verify or base.verify
	base.changeGuard = overrides.changeGuard or base.changeGuard
	base.log = overrides.log or base.log
	return base
end

return function(suite: Verify.Harness)
	suite:case("recognizes the primary checkout", function(context)
		context:expect(Landing.isPrimaryCheckout(".git\n")):toBeTruthy()
		context:expect(Landing.isPrimaryCheckout("/repo/.git/worktrees/feature\n")):toBeFalsy()
	end)

	suite:case("finds the worktree of a branch", function(context)
		local path, reason = Landing.findWorktreeForBranch(WORKTREE_LIST, "feature")
		context:expect(path):toBe("/repo/.worktrees/feature")
		context:expect(reason):toBeNil()
		local missing, missingReason = Landing.findWorktreeForBranch(WORKTREE_LIST, "absent")
		context:expect(missing):toBeNil()
		context:expect(missingReason):toBeTruthy()
		context:expect(missingReason :: string):toContain("refs/heads/absent")
	end)

	suite:case("classifies fast-forward output", function(context)
		context:expect(Landing.classifyFastForward(ok("3 files changed, 5 insertions(+)")).status):toBe("ok")
		local counted = Landing.classifyFastForward(ok("1 file changed, 2 insertions(+)"))
		context:expect(counted.status):toBe("ok")
		context:expect((counted :: { status: "ok", filesChanged: number }).filesChanged):toBe(1)
		context:expect(Landing.classifyFastForward(ok("Already up to date.\n")).status):toBe("ok")
		context:expect(Landing.classifyFastForward(ok("Updating aaa..bbb\n")).status):toBe("ok")
		context:expect(Landing.classifyFastForward(bad(1, "not something we can merge")).status):toBe("failed")
	end)

	suite:case("shortens commit ids and names trains", function(context)
		context:expect(Landing.shortSha("0123456789abcdef")):toBe("0123456")
		context:expect(Landing.trainBranchName("train-", { "0123456789", "abcdef0123" })):toBe("train-0123456-abcdef0")
	end)

	suite:case("classifies conflicts", function(context)
		local policy: Landing.ConflictPolicy = {
			resolvers = {
				["generated/lock.luau"] = {
					resolve = function(): (boolean, string?)
						return true, nil
					end,
				},
			},
			handAuthored = { ["docs/ledger.md"] = "resolve it by hand" },
			maxIterations = 4,
		}
		context:expect(Landing.classifyConflict({}, policy)):toBe("real")
		context:expect(Landing.classifyConflict({ "generated/lock.luau" }, policy)):toBe("resolvable")
		context:expect(Landing.classifyConflict({ "docs/ledger.md" }, policy)):toBe("hand_authored")
		context:expect(Landing.classifyConflict({ "src/main.luau" }, policy)):toBe("real")
		context:expect(Landing.classifyConflict({ "generated/lock.luau", "src/main.luau" }, policy)):toBe("real")
		context
			:expect(Landing.handAuthoredDetail({ "docs/ledger.md" }, policy))
			:toBe("docs/ledger.md: resolve it by hand")
	end)

	suite:case("extracts and truncates failing lines", function(context)
		local policy: Landing.FailurePolicy = { maxLines = 2, maxLineChars = 8, patterns = { "^x ", "^gate:" } }
		local lines = Landing.extractFailingLines("x first failure\nnoise\ngate: red\nx third\n", policy)
		context:expect(#lines):toBe(2)
		context:expect(lines[1]):toBe("x first ")
		context:expect(lines[2]):toBe("gate: re")
	end)

	suite:case("lands one branch", function(context)
		local outcome = Landing.landOne("feature", { git = stubGit({}), plan = stubPlan({}) })
		context:expect(outcome.ok):toBeTruthy()
		context:expect((outcome :: Landing.Success).sha):toBe("cafecafecafecafecafecafecafecafecafecafe")
		context:expect((outcome :: Landing.Success).filesChanged):toBe(2)
	end)

	suite:case("refuses outside the primary checkout", function(context)
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				commonDir = function(): Landing.CommandResult
					return ok("/repo/.git/worktrees/feature\n")
				end,
			}),
			plan = stubPlan({}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("not_primary_checkout")
	end)

	suite:case("refuses when verification fails", function(context)
		local outcome = Landing.landOne("feature", {
			git = stubGit({}),
			plan = stubPlan({
				verify = function(): Landing.Refusal?
					return { ok = false, reason = "test_red", detail = "specs failed", failingLines = { "x spec" } }
				end,
			}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("test_red")
	end)

	suite:case("refuses an unproven merge without pushing", function(context)
		local pushed = false
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				mergeFastForward = function(): Landing.CommandResult
					return ok("Already up to date.\n")
				end,
				revParse = function(ref: string): Landing.CommandResult
					return ok(string.rep(if ref == "main" then "a" else "b", 40))
				end,
				push = function(): Landing.CommandResult
					pushed = true
					return ok("")
				end,
			}),
			plan = stubPlan({}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("merge_unproven")
		context:expect(pushed):toBeFalsy()
	end)

	suite:case("refuses a remote mismatch", function(context)
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				revParse = function(ref: string): Landing.CommandResult
					return ok(string.rep(if ref == "origin/main" then "a" else "b", 40))
				end,
			}),
			plan = stubPlan({}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("remote_mismatch")
	end)

	suite:case("resolves a registered conflict", function(context)
		local resolved = 0
		local continued = 0
		local afterRan = false
		local conflicts = { "generated/lock.luau" }
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				rebase = function(): Landing.CommandResult
					return bad(1, "conflict")
				end,
				conflictedFiles = function(): Landing.CommandResult
					return ok(table.concat(conflicts, "\n"))
				end,
				rebaseContinue = function(): Landing.CommandResult
					continued += 1
					return ok("")
				end,
			}),
			plan = stubPlan({
				conflicts = {
					resolvers = {
						["generated/lock.luau"] = {
							resolve = function(): (boolean, string?)
								resolved += 1
								return true, nil
							end,
							afterContinue = function(): (boolean, string?)
								afterRan = true
								return true, nil
							end,
						},
					},
					handAuthored = {},
					maxIterations = 4,
				},
			}),
		})
		context:expect(outcome.ok):toBeTruthy()
		context:expect(resolved):toBe(1)
		context:expect(continued):toBe(1)
		context:expect(afterRan):toBeTruthy()
	end)

	suite:case("refuses a hand-authored conflict", function(context)
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				rebase = function(): Landing.CommandResult
					return bad(1, "conflict")
				end,
				conflictedFiles = function(): Landing.CommandResult
					return ok("docs/ledger.md\n")
				end,
			}),
			plan = stubPlan({
				conflicts = {
					resolvers = {},
					handAuthored = { ["docs/ledger.md"] = "hand authored" },
					maxIterations = 4,
				},
			}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("rebase_failed")
		context:expect((outcome :: Landing.Refusal).detail):toContain("hand authored")
	end)

	suite:case("lands a train through one integration branch", function(context)
		local TRAIN_LIST = table.concat({
			"worktree /repo",
			"branch refs/heads/main",
			"",
			"worktree /repo/.worktrees/one",
			"branch refs/heads/one",
			"",
			"worktree /repo/.worktrees/two",
			"branch refs/heads/two",
			"",
		}, "\n")
		local addedBranch: string? = nil
		local setupPath: string? = nil
		local outcome = Landing.landTrain({ "one", "two" }, {
			git = stubGit({
				worktreeList = function(): Landing.CommandResult
					return ok(TRAIN_LIST)
				end,
				branchRef = function(): Landing.CommandResult
					return ok("abcdef1234567890abcdef1234567890abcdef12\n")
				end,
				worktreeAdd = function(_path: string, branch: string): Landing.CommandResult
					addedBranch = branch
					return ok("")
				end,
			}),
			plan = stubPlan({
				setup = function(path: string): Landing.Refusal?
					setupPath = path
					return nil
				end,
			}),
		})
		context:expect(outcome.ok):toBeTruthy()
		context:expect(addedBranch):toBe("train-abcdef1-abcdef1")
		context:expect(setupPath):toBe("/repo/.worktrees/train-abcdef1-abcdef1")
	end)

	suite:case("resets and removes the members of a failed train", function(context)
		local resets: { string } = {}
		local outcome = Landing.landTrain({ "one", "two" }, {
			git = stubGit({
				worktreeList = function(): Landing.CommandResult
					return ok(table.concat({
						"worktree /repo/.worktrees/one",
						"branch refs/heads/one",
						"",
						"worktree /repo/.worktrees/two",
						"branch refs/heads/two",
						"",
					}, "\n"))
				end,
				resetHard = function(path: string): Landing.CommandResult
					table.insert(resets, path)
					return ok("")
				end,
			}),
			plan = stubPlan({
				verify = function(): Landing.Refusal?
					return { ok = false, reason = "test_red", detail = "specs failed", failingLines = {} }
				end,
			}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("test_red")
		context:expect(#resets):toBe(2)
		context:expect((outcome :: Landing.Refusal).detail):toContain("was reset and removed")
	end)

	suite:case("bounds resolver attempts", function(context)
		local resolveCalls = 0
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				rebase = function(): Landing.CommandResult
					return bad(1, "conflict")
				end,
				conflictedFiles = function(): Landing.CommandResult
					return ok("generated/lock.luau\n")
				end,
				rebaseContinue = function(): Landing.CommandResult
					return bad(1, "still conflicted")
				end,
			}),
			plan = stubPlan({
				conflicts = {
					resolvers = {
						["generated/lock.luau"] = {
							resolve = function(): (boolean, string?)
								resolveCalls += 1
								return true, nil
							end,
							maxAttempts = 1,
						},
					},
					handAuthored = {},
					maxIterations = 50,
				},
			}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("rebase_resolve_failed")
		context:expect(resolveCalls):toBe(1)
		context:expect((outcome :: Landing.Refusal).detail):toContain("after its resolver ran 1 time(s)")
	end)

	suite:case("proves the merge by exact commit", function(context)
		local sha = string.rep("a", 40)
		local moved = string.rep("b", 40)
		for _, output in { "", "Already up to date.\n", "Updating aaa..bbb\n" } do
			local result = Landing.mergeVerified("feature", "main", nil, {
				git = stubGit({
					mergeFastForward = function(): Landing.CommandResult
						return ok(output)
					end,
				}),
				plan = stubPlan({}),
			})
			context:expect(result.status):toBe("ok")
		end
		for _, mode in { "moved", "missing", "failed_read", "failed_merge" } do
			local merged = false
			local result = Landing.mergeVerified("feature", "main", nil, {
				git = stubGit({
					revParse = function(ref: string): Landing.CommandResult
						if mode == "failed_read" then
							return { exitcode = 1, stdout = sha, stderr = "unavailable" }
						end
						return ok(
							if merged
									and (
										(mode == "moved" and ref == "feature") or (mode == "missing" and ref == "main")
									)
								then moved
								else sha
						)
					end,
					mergeFastForward = function(): Landing.CommandResult
						merged = true
						return if mode == "failed_merge" then bad(1, "merge failed") else ok("2 files changed")
					end,
				}),
				plan = stubPlan({}),
			})
			context:expect(result.status).never:toBe("ok")
			if mode == "failed_read" then
				context:expect(merged):toBeFalsy()
			end
		end
	end)

	suite:case("refuses a candidate that moves during verification", function(context)
		local changed = false
		local merged = false
		local outcome = Landing.landOne("feature", {
			git = stubGit({
				revParse = function(): Landing.CommandResult
					return ok(string.rep(if changed then "b" else "a", 40))
				end,
				mergeFastForward = function(): Landing.CommandResult
					merged = true
					return ok("")
				end,
			}),
			plan = stubPlan({
				verify = function(): Landing.Refusal?
					changed = true
					return nil
				end,
			}),
		})
		context:expect(outcome.ok):toBeFalsy()
		context:expect((outcome :: Landing.Refusal).reason):toBe("merge_unproven")
		context:expect(merged):toBeFalsy()
	end)
end
