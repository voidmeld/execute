--!strict

local fs = require("@std/fs")
local process = require("@lute/process")

local Landing = require("./landing")
local WorkerSetup = require("./worker-setup")
local Verify = require("../../.lute/dependencies/verify/src/core")

local function sh(cwd: string, command: { string }): string
	local result = process.run(command, { cwd = cwd })
	assert(result.ok, table.concat(command, " ") .. ": " .. result.stderr)
	return string.gsub(result.stdout, "%s+$", "") :: string
end

local function tempDirectory(context: Verify.Context): string
	local root = sh(".", { "mktemp", "-d" })
	context:defer(function()
		fs.removeDirectory(root, { recursive = true })
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

local function initRepository(context: Verify.Context): (string, string)
	local root = tempDirectory(context)
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
		return if string.sub(path, 1, 1) == "/" then path else root .. "/" .. path
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
	suite:case("creates, reuses and refuses worktrees and reports a moved base", function(context)
		local root, primary = initRepository(context)
		local host = checkoutHost(primary, recorder())
		local path = root .. "/helper"
		local spec: WorkerSetup.WorktreeSpec = { repo = primary, path = path, branch = "helper/a", base = "main" }

		local created = WorkerSetup.ensureWorktree(spec, host)
		context:expect(created.status):toBe("PASS")
		context:expect(created.detail):toContain("new branch helper/a from main")
		context:expect(sh(path, { "git", "rev-parse", "--abbrev-ref", "HEAD" })):toBe("helper/a")

		local reused = WorkerSetup.ensureWorktree(spec, host)
		context:expect(reused.status):toBe("SKIP")

		local wrong =
			WorkerSetup.ensureWorktree({ repo = primary, path = path, branch = "helper/b", base = "main" }, host)
		context:expect(wrong.status):toBe("FAIL")
		context:expect(wrong.detail):toContain("holds helper/a")

		sh(primary, { "git", "branch", "helper/c", "main" })
		local existing = WorkerSetup.ensureWorktree(
			{ repo = primary, path = root .. "/c", branch = "helper/c", base = "main" },
			host
		)
		context:expect(existing.status):toBe("PASS")
		context:expect(existing.detail):toContain("existing branch")

		local occupied = WorkerSetup.ensureWorktree(
			{ repo = primary, path = root .. "/d", branch = "helper/c", base = "main" },
			host
		)
		context:expect(occupied.status):toBe("FAIL")

		local config: WorkerSetup.Config = { base = "main", inputs = {} }
		context:expect(#WorkerSetup.freshness(config, checkoutHost(path, recorder()))):toBe(0)
		write(primary .. "/source.txt", "two\n")
		commit(primary, "move main")
		local findings = WorkerSetup.freshness(config, checkoutHost(path, recorder()))
		context:expect(#findings):toBe(1)
		context:expect(findings[1].kind):toBe("base_moved")
		context:expect(findings[1].detail):toContain("1 commit(s)")
		context:expect(findings[1].remedy):toContain("git rebase main")
		sh(path, { "git", "rebase", "main" })
		context:expect(#WorkerSetup.freshness(config, checkoutHost(path, recorder()))):toBe(0)
	end)

	suite:case("syncs dependencies only when the lock changes", function(context)
		local _, primary = initRepository(context)
		local rec = recorder()
		local host = checkoutHost(primary, rec)
		local config: WorkerSetup.Config = {
			base = "main",
			lock = { path = "deps.lock", marker = "build/.lock", sync = { "sync-tool" } },
			inputs = {},
		}
		rec.scripted["sync-tool"] = { exitcode = 0, stdout = "synced\n", stderr = "" }

		local stale = WorkerSetup.freshness(config, host)
		context:expect(#stale):toBe(1)
		context:expect(stale[1].kind):toBe("lock_changed")
		context:expect(stale[1].remedy):toBe("sync-tool")
		local first = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(first[1].status):toBe("PASS")
		context:expect(count(rec.calls, "sync-tool")):toBe(1)
		local second = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(second[1].status):toBe("SKIP")
		context:expect(count(rec.calls, "sync-tool")):toBe(1)
		context:expect(#WorkerSetup.freshness(config, host)):toBe(0)

		write(primary .. "/deps.lock", "lock2\n")
		context:expect(WorkerSetup.freshness(config, host)[1].kind):toBe("lock_changed")
		WorkerSetup.prepareCheckout(config, host, {})
		context:expect(count(rec.calls, "sync-tool")):toBe(2)

		rec.scripted["sync-tool"] = { exitcode = 2, stdout = "", stderr = "no network\n" }
		write(primary .. "/deps.lock", "lock3\n")
		local failed = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(failed[1].status):toBe("FAIL")
		context:expect(failed[1].detail):toBe("exit 2: no network")
		context:expect(WorkerSetup.freshness(config, host)[1].kind):toBe("lock_changed")
	end)

	suite:case("creates declared directories", function(context)
		local _, primary = initRepository(context)
		local host = checkoutHost(primary, recorder())
		local config: WorkerSetup.Config = { base = "main", directories = { "build", "build/generated" }, inputs = {} }
		local first = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(first[1].status == "SKIP" or first[1].status == "PASS"):toBeTruthy()
		context:expect(fs.exists(primary .. "/build/generated")):toBeTruthy()
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[2].status):toBe("SKIP")
	end)

	suite:case("hydrates LFS pointer files", function(context)
		local _, primary = initRepository(context)
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
		context:expect(#findings):toBe(1)
		context:expect(findings[1].kind):toBe("lfs_pointer")
		context:expect(findings[1].subject):toBe("art/a.rbxm")
		local outcomes = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(outcomes[1].status):toBe("PASS")
		context:expect(outcomes[1].detail):toBe("hydrated 1 LFS file(s)")
		context:expect(count(rec.calls, "git lfs pull")):toBe(1)
		local again = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(again[1].status):toBe("SKIP")
		context:expect(count(rec.calls, "git lfs pull")):toBe(1)
		context:expect(#WorkerSetup.freshness(config, host)):toBe(0)

		rec.scripted["git lfs pull"] = { exitcode = 1, stdout = "", stderr = "smudge error\n" }
		hydrated = false
		local failed = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(failed[1].status):toBe("FAIL")
		context:expect(failed[1].detail):toContain("smudge error")
	end)

	suite:case("removes undeclared generated manifests", function(context)
		local _, primary = initRepository(context)
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
		context:expect(#findings):toBe(1)
		context:expect(findings[1].kind):toBe("stale_manifest")
		context:expect(findings[1].subject):toBe("staging.project.json")
		local outcomes = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(outcomes[1].status):toBe("PASS")
		context:expect(outcomes[1].detail):toBe("removed staging.project.json")
		context:expect(fs.exists(primary .. "/staging.project.json")):toBeFalsy()
		context:expect(fs.exists(primary .. "/declared.project.json")):toBeTruthy()
		context:expect(fs.exists(primary .. "/tracked.project.json")):toBeTruthy()
		context:expect(fs.exists(primary .. "/other.txt")):toBeTruthy()
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
	end)

	suite:case("ignores a collapsed ignored directory", function(context)
		local _, primary = initRepository(context)
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
		context:expect(#WorkerSetup.freshness(config, host)):toBe(0)
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
	end)

	suite:case("regenerates, copies and verifies generated inputs", function(context)
		local root, primary = initRepository(context)
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
		context:expect(#missing):toBe(1)
		context:expect(missing[1].kind):toBe("input_missing")
		context:expect(missing[1].remedy):toBe("generate")
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("PASS")
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("SKIP")
		context:expect(count(rec.calls, "generate")):toBe(1)
		context:expect(#WorkerSetup.freshness(config, host)):toBe(0)

		age(primary .. "/build/out.txt")
		local stale = WorkerSetup.freshness(config, host)
		context:expect(#stale):toBe(1)
		context:expect(stale[1].kind):toBe("input_stale")
		context:expect(stale[1].detail):toContain("older than source source.txt")
		context
			:expect((string.find(WorkerSetup.describeFinding(stale[1]), "STALE input_stale generated", 1, true)))
			:toBe(1)
		context:expect(WorkerSetup.prepareCheckout(config, host, {})[1].status):toBe("PASS")
		context:expect(count(rec.calls, "generate")):toBe(2)

		rec.scripted["generate"] = { exitcode = 0, stdout = "", stderr = "" }
		fs.remove(primary .. "/build/out.txt")
		local silent = WorkerSetup.prepareCheckout(config, host, {})
		context:expect(silent[1].status):toBe("FAIL")
		context:expect(silent[1].detail):toContain("absent")

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
		context:expect(copied.status):toBe("PASS")
		context:expect(copied.detail):toContain("copied from")
		context:expect(fs.readFileToString(helperPath .. "/build/out.txt")):toBe("reference build\n")
		context:expect(count(rec.calls, "generate")):toBe(before)

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
		context:expect(regenerated.status):toBe("PASS")
		context:expect(regenerated.detail):toBe("")
		context:expect(fs.readFileToString(helperPath .. "/build/out.txt")):toBe("regenerated\n")
	end)

	suite:case("lands a candidate through real git and refuses a red gate", function(context)
		local root, primary = initRepository(context)
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
		context:expect(absent.ok):toBeFalsy()
		context:expect((absent :: Landing.Refusal).reason):toBe("worktree_missing")
		context:expect((absent :: Landing.Refusal).detail):toContain("git worktree add <path> no-worktree")

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
		context:expect(failed.ok):toBeFalsy()
		context:expect(gateRuns):toBe(1)
		local refusal = failed :: Landing.Refusal
		context:expect(refusal.reason):toBe("test_red")
		context:expect(#refusal.failingLines):toBe(2)
		context:expect(refusal.failingLines[1]):toBe("✗ Inventory stacks items")
		context:expect(refusal.detail):toContain("✗ Quest resets")
		context:expect(refusal.logPath):toBe(root .. "/scoped-specs.log")
		assert(
			string.find(fs.readFileToString(refusal.logPath :: string), "noise", 1, true) ~= nil,
			"the full output is retained"
		)
		context
			:expect(sh(primary, { "git", "rev-parse", "main" }))
			:toBe(sh(primary, { "git", "rev-parse", "origin/main" }))
		context:expect(fs.exists(candidate)):toBeTruthy()

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
		context:expect(landed.ok):toBeTruthy()
		context:expect(gateRuns):toBe(2)
		context:expect(sh(primary, { "git", "rev-parse", "origin/main" })):toBe((landed :: Landing.Success).sha)
		context:expect(sh(primary, { "git", "rev-list", "--count", "main" })):toBe("3")
		context:expect(fs.exists(candidate)):toBeFalsy()

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
		context:expect(unreadable):toBeTruthy()
		context:expect((unreadable :: Landing.Refusal).detail):toContain("last output: a | b")
		context:expect((unreadable :: Landing.Refusal).detail):toContain("no log could be written")
		context:expect((unreadable :: Landing.Refusal).logPath):toBeNil()
	end)
end
