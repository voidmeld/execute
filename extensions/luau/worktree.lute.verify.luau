--!strict

local fs = require("@std/fs")
local process = require("@lute/process")

local Landing = require("./landing")
local WorkerSetup = require("./worker-setup")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")
local TemporaryDirectory = require("../../tools/lib/temporary-directory")

local function sh(cwd: string, command: { string }): string
	local result = process.run(command, { cwd = cwd })
	assert(result.ok, table.concat(command, " ") .. ": " .. result.stderr)
	return string.gsub(result.stdout, "%s+$", "") :: string
end

local function tempDirectory(own: Bdd.Own): string
	local root = TemporaryDirectory.allocate(TemporaryDirectory.root(), "execute-worktree")
	own(function()
		assert(TemporaryDirectory.remove(root) == nil, "temporary repository cleanup failed: " .. root)
	end)
	return root
end

local function write(path: string, contents: string)
	fs.writeStringToFile(path, contents)
end

local function commit(repo: string, message: string)
	sh(repo, { "git", "add", "-A" })
	sh(repo, { "git", "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", message })
end

local function initRepository(own: Bdd.Own): (string, string)
	local root = tempDirectory(own)
	local origin = root .. "/origin.git"
	local primary = root .. "/primary"
	sh(root, { "git", "init", "-q", "--bare", "-b", "main", origin })
	sh(root, { "git", "init", "-q", "-b", "main", primary })
	sh(primary, { "git", "remote", "add", "origin", origin })
	write(primary .. "/.gitignore", "*.project.json\n!tracked.project.json\nbuild/\n")
	write(primary .. "/source.txt", "one\n")
	write(primary .. "/tracked.project.json", "{}\n")
	write(primary .. "/deps.lock", "lock1\n")
	commit(primary, "base")
	sh(primary, { "git", "push", "-q", "origin", "main" })
	return root, primary
end

type Recorder = {
	calls: { string },
	scripted: { [string]: WorkerSetup.CommandResult | (() -> WorkerSetup.CommandResult) },
}

local function checkoutHost(root: string, recorder: Recorder): WorkerSetup.Host
	local function resolve(path: string): string
		return if string.sub(path, 1, 1) == "/" or string.match(path, "^%a:/") then path else root .. "/" .. path
	end
	return {
		run = function(command: { string }, cwd: string?): WorkerSetup.CommandResult
			local joined = table.concat(command, " ")
			table.insert(recorder.calls, joined)
			local scripted = recorder.scripted[joined]
			if scripted ~= nil then
				return if type(scripted) == "function" then scripted() else scripted
			end
			if command[1] ~= "git" then
				return { exitcode = 127, stdout = "", stderr = "unscripted " .. joined }
			end
			local result = process.run(command, { cwd = if cwd ~= nil then cwd else root })
			return { exitcode = result.exitcode, stdout = result.stdout, stderr = result.stderr }
		end,
		exists = function(path: string): boolean
			return fs.exists(resolve(path))
		end,
		modified = function(path: string): number?
			local ok, metadata = pcall(fs.metadata, resolve(path))
			return if ok then metadata.modified:toSeconds() else nil
		end,
		read = function(path: string): string?
			return if fs.exists(resolve(path)) then fs.readFileToString(resolve(path)) else nil
		end,
		write = function(path: string, contents: string)
			write(resolve(path), contents)
		end,
		copy = function(from: string, to: string)
			fs.copy(resolve(from), resolve(to))
		end,
		remove = function(path: string)
			fs.remove(resolve(path))
		end,
		createDirectory = function(path: string)
			fs.createDirectory(resolve(path), { makeParents = true })
		end,
	}
end

local function recorder(): Recorder
	return { calls = {}, scripted = {} }
end

local function count(calls: { string }, text: string): number
	local total = 0
	for _, call in calls do
		if string.find(call, text, 1, true) ~= nil then
			total += 1
		end
	end
	return total
end

local function age(path: string)
	sh(".", { "touch", "-t", "200001010000", path })
end

local function realGit(primary: string): Landing.Git
	local function git(arguments: { string }, cwd: string?): Landing.CommandResult
		local command: { string } = { "git" }
		for _, argument in arguments do
			table.insert(command, argument)
		end
		local result = process.run(command, { cwd = cwd or primary })
		return { exitcode = result.exitcode, stdout = result.stdout, stderr = result.stderr }
	end
	return {
		commonDir = function()
			return git({ "rev-parse", "--git-common-dir" })
		end,
		branchRef = function(branch)
			return git({ "rev-parse", "--verify", "--quiet", "refs/heads/" .. branch })
		end,
		worktreeList = function()
			return git({ "worktree", "list", "--porcelain" })
		end,
		worktreeAdd = function(path, branch, startPoint)
			return git({ "worktree", "add", path, "-b", branch, startPoint })
		end,
		worktreeRemove = function(path)
			return git({ "worktree", "remove", "--force", path })
		end,
		branchDelete = function(branch)
			return git({ "branch", "-D", branch })
		end,
		rebase = function(worktreePath, onto)
			return git({ "rebase", onto }, worktreePath)
		end,
		rebaseContinue = function(worktreePath)
			return git({ "-c", "core.editor=true", "rebase", "--continue" }, worktreePath)
		end,
		conflictedFiles = function(worktreePath)
			return git({ "diff", "--name-only", "--diff-filter=U" }, worktreePath)
		end,
		add = function(worktreePath, path)
			return git({ "add", path }, worktreePath)
		end,
		mergeFastForward = function(branch, cwd)
			return git({ "merge", "--ff-only", branch }, cwd)
		end,
		mergeBase = function(a, b)
			return git({ "merge-base", a, b })
		end,
		pathsBetween = function(from, to)
			return git({ "diff", "--name-only", from .. ".." .. to })
		end,
		changedPaths = function(worktreePath)
			return git({ "diff", "--name-only", "main..HEAD" }, worktreePath)
		end,
		resetHard = function(worktreePath, sha)
			return git({ "reset", "--hard", sha }, worktreePath)
		end,
		push = function()
			return git({ "push", "origin", "main" })
		end,
		fetch = function()
			return git({ "fetch", "origin", "main" })
		end,
		revParse = function(ref)
			return git({ "rev-parse", ref })
		end,
	}
end

local function landingPlan(root: string, verify: (worktree: string) -> Landing.Refusal?): Landing.Plan
	local function none(): Landing.Refusal?
		return nil
	end
	return {
		base = "main",
		remote = "origin",
		trainRoot = root .. "/trains",
		trainBranchPrefix = "train-",
		conflicts = { resolvers = {}, handAuthored = {}, maxIterations = 4 },
		failure = { maxLines = 4, maxLineChars = 80, patterns = { "^✗" } },
		setup = none,
		prepare = none,
		commitGuard = none,
		verify = verify,
		changeGuard = none,
		log = function() end,
	}
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("worktree", function()
		it("creates, reuses and refuses worktrees and reports a moved base", function(own)
			local root, primary = initRepository(own)
			local host = checkoutHost(primary, recorder())
			local path = root .. "/helper"
			local spec: WorkerSetup.WorktreeSpec = { repo = primary, path = path, branch = "helper/a", base = "main" }

			local created = WorkerSetup.ensureWorktree(spec, host)
			expect(created.status):toBe("PASS")
			expect(created.detail):toContain("new branch helper/a from main")
			expect(sh(path, { "git", "rev-parse", "--abbrev-ref", "HEAD" })):toBe("helper/a")

			local reused = WorkerSetup.ensureWorktree(spec, host)
			expect(reused.status):toBe("SKIP")

			local wrong =
				WorkerSetup.ensureWorktree({ repo = primary, path = path, branch = "helper/b", base = "main" }, host)
			expect(wrong.status):toBe("FAIL")
			expect(wrong.detail):toContain("holds helper/a")

			sh(primary, { "git", "branch", "helper/c", "main" })
			local existing = WorkerSetup.ensureWorktree(
				{ repo = primary, path = root .. "/c", branch = "helper/c", base = "main" },
				host
			)
			expect(existing.status):toBe("PASS")
			expect(existing.detail):toContain("existing branch")

			local occupied = WorkerSetup.ensureWorktree(
				{ repo = primary, path = root .. "/d", branch = "helper/c", base = "main" },
				host
			)
			expect(occupied.status):toBe("FAIL")

			local config: WorkerSetup.Config = { base = "main", inputs = {} }
			expect(#WorkerSetup.freshness(config, checkoutHost(path, recorder()))):toBe(0)
			write(primary .. "/source.txt", "two\n")
			commit(primary, "move main")
			local findings = WorkerSetup.freshness(config, checkoutHost(path, recorder()))
			expect(#findings):toBe(1)
			expect(findings[1].kind):toBe("base_moved")
			expect(findings[1].detail):toContain("1 commit(s)")
			expect(findings[1].remedy):toContain("git rebase main")
			sh(path, { "git", "rebase", "main" })
			expect(#WorkerSetup.freshness(config, checkoutHost(path, recorder()))):toBe(0)
		end)

		it("syncs dependencies only when the lock changes", function(own)
			local _, primary = initRepository(own)
			local rec = recorder()
			local host = checkoutHost(primary, rec)
			local config: WorkerSetup.Config = {
				base = "main",
				lock = { path = "deps.lock", marker = "build/.lock", sync = { "sync-tool" } },
				inputs = {},
			}
			rec.scripted["sync-tool"] = { exitcode = 0, stdout = "synced\n", stderr = "" }

			local stale = WorkerSetup.freshness(config, host)
			expect(#stale):toBe(1)
			expect(stale[1].kind):toBe("lock_changed")
			expect(stale[1].remedy):toBe("sync-tool")
			local first = WorkerSetup.prepareCheckout(config, host, {})
			expect(first[1].status):toBe("PASS")
			expect(count(rec.calls, "sync-tool")):toBe(1)
			local second = WorkerSetup.prepareCheckout(config, host, {})
			expect(second[1].status):toBe("SKIP")
			expect(count(rec.calls, "sync-tool")):toBe(1)
			expect(#WorkerSetup.freshness(config, host)):toBe(0)

			write(primary .. "/deps.lock", "lock2\n")
			expect(WorkerSetup.freshness(config, host)[1].kind):toBe("lock_changed")
			WorkerSetup.prepareCheckout(config, host, {})
			expect(count(rec.calls, "sync-tool")):toBe(2)

			rec.scripted["sync-tool"] = { exitcode = 2, stdout = "", stderr = "no network\n" }
			write(primary .. "/deps.lock", "lock3\n")
			local failed = WorkerSetup.prepareCheckout(config, host, {})
			expect(failed[1].status):toBe("FAIL")
			expect(failed[1].detail):toBe("exit 2: no network")
			expect(WorkerSetup.freshness(config, host)[1].kind):toBe("lock_changed")
		end)

		it("creates declared directories", function(own)
			local _, primary = initRepository(own)
			local host = checkoutHost(primary, recorder())
			local config: WorkerSetup.Config =
				{ base = "main", directories = { "build", "build/generated" }, inputs = {} }
			local first = WorkerSetup.prepareCheckout(config, host, {})
			expect(first[1].status == "SKIP" or first[1].status == "PASS"):toBeTruthy()
			expect(fs.exists(primary .. "/build/generated")):toBeTruthy()
			expect(WorkerSetup.prepareCheckout(config, host, {})[2].status):toBe("SKIP")
		end)

		it("runs appended steps after checkout preparation and continues after a failed step", function(own)
			local _, primary = initRepository(own)
			local host = checkoutHost(primary, recorder())
			local config: WorkerSetup.Config = { base = "main", directories = { "build/generated" }, inputs = {} }
			local after: { WorkerSetup.Step } = {}
			local order: { string } = {}
			local statuses: { WorkerSetup.StepStatus } = { "PASS", "FAIL", "WARN" }
			for _, status in statuses do
				table.insert(after, {
					name = status,
					run = function(name: string): WorkerSetup.StepOutcome
						expect(fs.exists(primary .. "/build/generated")):toBeTruthy()
						table.insert(order, name)
						return { name = name, status = status :: WorkerSetup.StepStatus, detail = "appended step" }
					end,
				})
			end
			local outcomes = WorkerSetup.prepareCheckout(config, host, after)
			expect(#outcomes):toBe(5)
			expect(outcomes[1].name):toBe("build/generated")
			expect(outcomes[2].name):toBe("stale generated manifests")
			expect(table.concat(order, ",")):toBe("PASS,FAIL,WARN")
			expect(WorkerSetup.failureCount(outcomes)):toBe(1)
		end)

		it("hydrates LFS pointer files", function(own)
			local _, primary = initRepository(own)
			local rec = recorder()
			local host = checkoutHost(primary, rec)
			local config: WorkerSetup.Config = { base = "main", lfs = true, inputs = {} }
			local hydrated = false
			rec.scripted["git lfs ls-files"] = function(): WorkerSetup.CommandResult
				return {
					exitcode = 0,
					stdout = if hydrated then "abc123 * art/a.rbxm\n" else "abc123 - art/a.rbxm\ndef456 * art/b.mp3\n",
					stderr = "",
				}
			end
			rec.scripted["git lfs pull"] = function(): WorkerSetup.CommandResult
				hydrated = true
				return { exitcode = 0, stdout = "", stderr = "" }
			end
			local findings = WorkerSetup.freshness(config, host)
			expect(#findings):toBe(1)
			expect(findings[1].kind):toBe("lfs_pointer")
			expect(findings[1].subject):toBe("art/a.rbxm")
			local outcomes = WorkerSetup.prepareCheckout(config, host, {})
			expect(outcomes[1].status):toBe("PASS")
			expect(outcomes[1].detail):toBe("hydrated 1 LFS file(s)")
			expect(count(rec.calls, "git lfs pull")):toBe(1)
			local again = WorkerSetup.prepareCheckout(config, host, {})
			expect(again[1].status):toBe("SKIP")
			expect(count(rec.calls, "git lfs pull")):toBe(1)
			expect(#WorkerSetup.freshness(config, host)):toBe(0)

			rec.scripted["git lfs pull"] = { exitcode = 1, stdout = "", stderr = "smudge error\n" }
			hydrated = false
			local failed = WorkerSetup.prepareCheckout(config, host, {})
			expect(failed[1].status):toBe("FAIL")
			expect(failed[1].detail):toContain("smudge error")
		end)

		it("removes undeclared generated manifests", function(own)
			local _, primary = initRepository(own)
			local rec = recorder()
			local host = checkoutHost(primary, rec)
			local config: WorkerSetup.Config = {
				base = "main",
				manifests = { pathspec = ":(glob)*.project.json", keep = { "declared.project.json" } },
				inputs = {},
			}
			write(primary .. "/declared.project.json", "{}\n")
			write(primary .. "/staging.project.json", "{}\n")
			write(primary .. "/other.txt", "kept\n")
			local findings = WorkerSetup.freshness(config, host)
			expect(#findings):toBe(1)
			expect(findings[1].kind):toBe("stale_manifest")
			expect(findings[1].subject):toBe("staging.project.json")
			local outcomes = WorkerSetup.prepareCheckout(config, host, {})
			expect(outcomes[1].status):toBe("PASS")
			expect(outcomes[1].detail):toBe("removed staging.project.json")
			expect(fs.exists(primary .. "/staging.project.json")):toBeFalsy()
			expect(fs.exists(primary .. "/declared.project.json")):toBeTruthy()
			expect(fs.exists(primary .. "/tracked.project.json")):toBeTruthy()
			expect(fs.exists(primary .. "/other.txt")):toBeTruthy()
			expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
		end)

		it("ignores a collapsed ignored directory", function(own)
			local _, primary = initRepository(own)
			local rec = recorder()
			local host = checkoutHost(primary, rec)
			local config: WorkerSetup.Config = {
				base = "main",
				manifests = { pathspec = ":(glob)*.project.json", keep = {} },
				inputs = {},
			}
			rec.scripted["git ls-files --others --ignored --exclude-standard -- :(glob)*.project.json"] = {
				exitcode = 0,
				stdout = "cache/\n",
				stderr = "",
			}
			expect(#WorkerSetup.freshness(config, host)):toBe(0)
			expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
		end)

		it("regenerates, copies and verifies generated inputs", function(own)
			local root, primary = initRepository(own)
			local rec = recorder()
			local host = checkoutHost(primary, rec)
			local input: WorkerSetup.Input = {
				name = "generated",
				outputs = { "build/out.txt" },
				sources = { "source.txt" },
				regenerate = { "generate" },
			}
			local config: WorkerSetup.Config = { base = "main", inputs = { input } }
			rec.scripted["generate"] = function(): WorkerSetup.CommandResult
				fs.createDirectory(primary .. "/build", { makeParents = true })
				write(primary .. "/build/out.txt", "generated\n")
				return { exitcode = 0, stdout = "generated", stderr = "" }
			end

			local missing = WorkerSetup.freshness(config, host)
			expect(#missing):toBe(1)
			expect(missing[1].kind):toBe("input_missing")
			expect(missing[1].remedy):toBe("generate")
			expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("PASS")
			expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
			expect(count(rec.calls, "generate")):toBe(1)
			expect(#WorkerSetup.freshness(config, host)):toBe(0)

			age(primary .. "/build/out.txt")
			local stale = WorkerSetup.freshness(config, host)
			expect(#stale):toBe(1)
			expect(stale[1].kind):toBe("input_stale")
			expect(stale[1].detail):toContain("older than source source.txt")
			expect((string.find(WorkerSetup.describeFinding(stale[1]), "STALE input_stale generated", 1, true))):toBe(1)
			expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("PASS")
			expect(count(rec.calls, "generate")):toBe(2)

			rec.scripted["generate"] = { exitcode = 0, stdout = "", stderr = "" }
			fs.remove(primary .. "/build/out.txt")
			local silent = WorkerSetup.prepareCheckout(config, host, {})
			expect(silent[1].status):toBe("FAIL")
			expect(silent[1].detail):toContain("absent")

			local helperPath = root .. "/helper"
			local helper = checkoutHost(helperPath, rec)
			sh(primary, { "git", "worktree", "add", "-q", "-b", "helper", helperPath, "main" })
			write(primary .. "/build/out.txt", "reference build\n")
			local copying: WorkerSetup.Config = {
				base = "main",
				reference = primary,
				inputs = {
					{
						name = "generated",
						outputs = { "build/out.txt" },
						sources = { "source.txt" },
						regenerate = { "generate" },
						copyFromReference = true,
					},
				},
			}
			local before = count(rec.calls, "generate")
			local copied = WorkerSetup.prepareCheckout(copying, helper, {})[1]
			expect(copied.status):toBe("PASS")
			expect(copied.detail):toContain("copied from")
			expect(fs.readFileToString(helperPath .. "/build/out.txt")):toBe("reference build\n")
			expect(count(rec.calls, "generate")):toBe(before)

			write(helperPath .. "/source.txt", "diverged\n")
			commit(helperPath, "diverge")
			fs.remove(helperPath .. "/build/out.txt")
			write(primary .. "/build/out.txt", "reference build\n")
			rec.scripted["generate"] = function(): WorkerSetup.CommandResult
				fs.createDirectory(helperPath .. "/build", { makeParents = true })
				write(helperPath .. "/build/out.txt", "regenerated\n")
				return { exitcode = 0, stdout = "", stderr = "" }
			end
			local regenerated = WorkerSetup.prepareCheckout(copying, helper, {})[1]
			expect(regenerated.status):toBe("PASS")
			expect(regenerated.detail):toBe("")
			expect(fs.readFileToString(helperPath .. "/build/out.txt")):toBe("regenerated\n")
		end)

		it("lands a candidate through real git and refuses a red gate", function(own)
			local root, primary = initRepository(own)
			local git = realGit(primary)
			local stepHost: Landing.StepHost = {
				run = function(command, cwd)
					local result = process.run(command, { cwd = cwd })
					return { exitcode = result.exitcode, stdout = result.stdout, stderr = result.stderr }
				end,
				writeLog = function(label, output)
					local path = root .. "/" .. string.gsub(label, "%W", "-") .. ".log"
					write(path, output)
					return path
				end,
			}
			local policy = landingPlan(root, function()
				return nil
			end).failure

			sh(primary, { "git", "branch", "no-worktree", "main" })
			local absent = Landing.landOne("no-worktree", {
				git = git,
				plan = landingPlan(root, function(): Landing.Refusal?
					error("the gate must not run without a worktree")
				end),
			})
			expect(absent.ok):toBeFalsy()
			expect((absent :: Landing.Refusal).reason):toBe("worktree_missing")
			expect((absent :: Landing.Refusal).detail):toContain("git worktree add <path> no-worktree")

			local candidate = root .. "/candidate"
			sh(primary, { "git", "worktree", "add", "-q", "-b", "candidate", candidate, "main" })
			write(candidate .. "/feature.txt", "one squashed commit\n")
			commit(candidate, "squashed candidate")
			write(primary .. "/source.txt", "main moved\n")
			commit(primary, "main moves while the candidate is in flight")
			sh(primary, { "git", "push", "-q", "origin", "main" })

			local gateRuns = 0
			local failed = Landing.landOne("candidate", {
				git = git,
				plan = landingPlan(root, function(worktree)
					gateRuns += 1
					return Landing.runStep({
						reason = "test_red",
						label = "scoped specs",
						command = {
							"sh",
							"-c",
							"echo '✗ Inventory stacks items'; echo 'noise'; echo '✗ Quest resets'; exit 1",
						},
						cwd = worktree,
					}, stepHost, policy)
				end),
			})
			expect(failed.ok):toBeFalsy()
			expect(gateRuns):toBe(1)
			local refusal = failed :: Landing.Refusal
			expect(refusal.reason):toBe("test_red")
			expect(#refusal.failingLines):toBe(2)
			expect(refusal.failingLines[1]):toBe("✗ Inventory stacks items")
			expect(refusal.detail):toContain("✗ Quest resets")
			expect(refusal.logPath):toBe(root .. "/scoped-specs.log")
			assert(
				string.find(fs.readFileToString(refusal.logPath :: string), "noise", 1, true) ~= nil,
				"the full output is retained"
			)
			expect(sh(primary, { "git", "rev-parse", "main" })):toBe(sh(primary, { "git", "rev-parse", "origin/main" }))
			expect(fs.exists(candidate)):toBeTruthy()

			local landed = Landing.landOne("candidate", {
				git = git,
				plan = landingPlan(root, function(worktree)
					gateRuns += 1
					return Landing.runStep({
						reason = "test_red",
						label = "scoped specs",
						command = { "sh", "-c", "test -f feature.txt" },
						cwd = worktree,
					}, stepHost, policy)
				end),
			})
			expect(landed.ok):toBeTruthy()
			expect(gateRuns):toBe(2)
			expect(sh(primary, { "git", "rev-parse", "origin/main" })):toBe((landed :: Landing.Success).sha)
			expect(sh(primary, { "git", "rev-list", "--count", "main" })):toBe("3")
			expect(fs.exists(candidate)):toBeFalsy()

			local unreadable = Landing.runStep(
				{ reason = "x", label = "tail", command = { "sh", "-c", "echo a; echo b; exit 3" }, cwd = primary },
				{
					run = stepHost.run,
					writeLog = function()
						return nil
					end,
				},
				policy
			)
			expect(unreadable):toBeTruthy()
			expect((unreadable :: Landing.Refusal).detail):toContain("last output: a | b")
			expect((unreadable :: Landing.Refusal).detail):toContain("no log could be written")
			expect((unreadable :: Landing.Refusal).logPath):toBeNil()
		end)
	end)
end
