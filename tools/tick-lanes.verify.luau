--!strict

local fs = require("@std/fs")
local process = require("@lute/process")
local Bdd = require("@verify/src/bdd")
local Verify = require("@verify/src/core")
local TemporaryDirectory = require("@verify/src/checks").temporaryDirectory

local command = process.cwd() .. "/tools/tick-lanes.luau"

local function run(root: string, slots: number, ...: string): process.ProcessResult
	return process.run(
		{ process.execPath(), "run", command, tostring(slots), "3600", "queue", "state", ... },
		{ cwd = root }
	)
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("the lane tick command", function()
		it("cleans an idle squash landing and keeps live and conflicting lanes in a local repository", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-hygiene", function(root)
				local repo = root .. "/primary"
				local trees = repo .. "-worktrees"
				local function git(cwd: string, ...: string): string
					local result = process.run({ "git", ... }, { cwd = cwd })
					assert(result.ok, result.stderr)
					return result.stdout
				end
				git(root, "init", "-qb", "main", repo)
				git(repo, "config", "user.name", "Test")
				git(repo, "config", "user.email", "test@example.com")
				git(repo, "config", "merge.keep.driver", "true")
				fs.writeStringToFile(repo .. "/.gitattributes", "setting merge=keep\n")
				fs.writeStringToFile(repo .. "/setting", "base\n")
				git(repo, "add", ".")
				git(repo, "commit", "-qm", "base")
				for _, branch in { "squash", "active", "conflict" } do
					git(repo, "worktree", "add", "-qb", branch, trees .. "/" .. branch)
				end
				local squash = trees .. "/squash"
				for _, file in { "one", "two" } do
					fs.writeStringToFile(squash .. "/" .. file, file)
					git(squash, "add", file)
					git(squash, "commit", "-qm", file)
				end
				git(repo, "merge", "--squash", "squash")
				git(repo, "commit", "-qm", "both changes")
				fs.writeStringToFile(repo .. "/setting", "trunk edit\n")
				git(repo, "commit", "-qam", "advance trunk")
				local conflict = trees .. "/conflict"
				fs.writeStringToFile(conflict .. "/setting", "lane edit\n")
				git(conflict, "commit", "-qam", "keep for review")
				fs.writeStringToFile(repo .. "/queue", "")
				fs.writeStringToFile(repo .. "/state", ("active\t1\t%d\t/missing\trunning\n"):format(process.pid()))
				local result = run(repo, 0)
				assert(result.ok, result.stderr)
				expect(result.stdout):toContain("REMOVED squash ")
				expect(result.stdout):toContain("UNLANDED conflict 1 ")
				expect(git(repo, "branch", "--list", "squash")):toBe("")
				expect(fs.exists(squash)):toBeFalsy()
				expect(fs.exists(trees .. "/active")):toBeTruthy()
				expect(fs.readFileToString(conflict .. "/setting")):toBe("lane edit\n")
				return true
			end)
		end)

		it("keeps unqueued helpers using a worktree cwd or a symlinked checkout argument until they exit", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-live-lanes", function(root)
				local repo = root .. "/primary"
				local lanes = root .. "/physical lanes"
				local alias = repo .. "-worktrees"
				fs.createDirectory(lanes)
				fs.symbolicLink(lanes, alias)
				local function git(...: string): string
					local result = process.run({ "git", "-C", repo, ... })
					assert(result.ok, result.stderr)
					return result.stdout
				end
				fs.createDirectory(repo)
				git("init", "-qb", "main")
				git(
					"-c",
					"user.name=Test",
					"-c",
					"user.email=test@example.com",
					"commit",
					"--allow-empty",
					"-qm",
					"base"
				)
				for _, branch in { "fix", "rebase", "idle" } do
					git("worktree", "add", "-qb", branch, lanes .. "/" .. branch)
				end
				fs.writeStringToFile(repo .. "/queue", "")
				fs.createDirectory(alias .. "/fix/subdir")
				local handoff = root .. "/handoff checkout"
				fs.symbolicLink(lanes .. "/rebase", handoff)
				local reserved = lanes .. "/build cache"
				git("worktree", "add", "-qb", "snapshot", reserved .. "/snapshot")
				local env = table.clone(process.env)
				env.EXECUTE_EXTRA_MANAGED_ROOTS = "snapshots:../physical lanes/build cache"
				local running = process.run({
					"sh",
					"-c",
					'(cd "$1" && "$2" run "$3" 0 3600 queue state); exit "$?"',
					"manual-helper",
					repo,
					process.execPath(),
					command,
					"-C",
					"../../../handoff checkout",
				}, { cwd = alias .. "/fix/subdir", env = env })
				assert(running.ok, running.stderr)
				expect(running.stdout):toContain("REMOVED idle ")
				expect(fs.exists(reserved .. "/snapshot/.git")):toBeTruthy()
				for _, branch in { "fix", "rebase" } do
					expect(fs.exists(lanes .. "/" .. branch)):toBeTruthy()
					expect(git("branch", "--list", branch)):toContain(branch)
				end
				local finished = run(repo, 0)
				assert(finished.ok, finished.stderr)
				expect(finished.stdout):toContain("REMOVED fix ")
				expect(finished.stdout):toContain("REMOVED rebase ")
				return true
			end)
		end)

		it("saves each launch, retries the next lane and remembers a report across invocations", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-queue", function(root)
				fs.writeStringToFile(root .. "/queue", "docs\tbrief one\r\napi\tbrief two")
				local launcher = [[
if [ "$1" = api ] && [ ! -f ready ]; then exit 9; fi
printf '%s\t%s\n' "$1" "$2" >> launches
printf '%s\t%s\n' "$0" "$1 report"
]]
				local function launch()
					return run(root, 2, "sh", "-c", launcher, tostring(process.pid()))
				end
				local first = launch()
				expect(first.ok):toBeFalsy()
				expect(first.stderr):toContain("start api exited 9")
				expect(fs.exists(root .. "/state.lock")):toBeFalsy()
				fs.writeStringToFile(root .. "/ready", "")
				local second = launch()
				assert(second.ok, second.stderr)
				expect(second.stdout):toBe("api\tstarted\tbrief two\n")
				expect(fs.readFileToString(root .. "/launches")):toBe("docs\tbrief one\napi\tbrief two\n")
				fs.writeStringToFile(root .. "/docs report", "finished")
				local reported = run(root, 0)
				assert(reported.ok, reported.stderr)
				expect(reported.stdout):toContain("docs\treported\t")
				local quiet = run(root, 0)
				assert(quiet.ok, quiet.stderr)
				expect(quiet.stdout):toBe("")
				return true
			end)
		end)

		it("holds the lock when a successful launcher returns an unreadable receipt", function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-queue-recovery", function(root)
				fs.writeStringToFile(root .. "/queue", "docs\tbrief")
				local first = run(root, 1, "sh", "-c", "echo start >> launches; echo missing-pid")
				expect(first.ok):toBeFalsy()
				expect(first.stderr):toContain("must print PID")
				expect(fs.readFileToString(root .. "/state.lock/starting")):toBe("docs")
				local locked = run(root, 1, "sh", "-c", "echo second >> launches")
				expect(locked.ok):toBeFalsy()
				expect(fs.readFileToString(root .. "/launches")):toBe("start\n")
				fs.writeStringToFile(
					root .. "/state",
					("docs\t1\t%d\t%s/docs.report\trunning\n"):format(process.pid(), root)
				)
				fs.remove(root .. "/state.lock/starting")
				fs.removeDirectory(root .. "/state.lock")
				local resumed = run(root, 1, "sh", "-c", "echo duplicate >> launches")
				assert(resumed.ok, resumed.stderr)
				expect(resumed.stdout):toContain("docs\tover the cap\t")
				expect(fs.readFileToString(root .. "/launches")):toBe("start\n")
				return true
			end)
		end)
	end)
end
