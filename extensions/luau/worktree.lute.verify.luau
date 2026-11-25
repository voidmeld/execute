--!strict

local fs = require("@std/fs")
local process = require("@lute/process")

local WorkerSetup = require("./worker-setup")
local Verify = require("@verify/src/core")
local Bdd = require("@verify/src/bdd")
local TemporaryDirectory = require("@verify/src/checks").temporaryDirectory

local function sh(cwd: string, command: { string }): string
	local result = process.run(command, { cwd = cwd })
	assert(result.ok, table.concat(command, " ") .. ": " .. result.stderr)
	return (string.gsub(result.stdout, "%s+$", ""))
end

local function write(path: string, contents: string)
	fs.writeStringToFile(path, contents)
end

local function commit(repo: string, message: string)
	sh(repo, { "git", "add", "-A" })
	sh(repo, { "git", "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", message })
end

local function initRepository(root: string): string
	local primary = root .. "/primary"
	sh(root, { "git", "init", "-q", "-b", "main", primary })
	write(primary .. "/.gitignore", "*.project.json\n!tracked.project.json\nbuild/\n")
	write(primary .. "/source.txt", "one\n")
	write(primary .. "/tracked.project.json", "{}\n")
	write(primary .. "/deps.lock", "lock1\n")
	commit(primary, "base")
	return primary
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

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	local function case(name: string, body: (string) -> ())
		it(name, function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-worktree", function(root)
				body(root)
				return nil
			end)
		end)
	end

	describe("worktree", function()
		case("creates, reuses and refuses worktrees and reports a moved base", function(directory)
			local primary = initRepository(directory)
			local host = checkoutHost(primary, recorder())
			local path = directory .. "/helper"
			local spec: WorkerSetup.WorktreeSpec = { repo = primary, path = path, branch = "helper/a", base = "main" }

			local created = WorkerSetup.ensureWorktree(spec, host)
			assert(created.status == "PASS")
			expect(created.detail):toContain("new branch helper/a from main")
			expect(sh(path, { "git", "rev-parse", "--abbrev-ref", "HEAD" })):toBe("helper/a")

			local reused = WorkerSetup.ensureWorktree(spec, host)
			assert(reused.status == "SKIP")

			local wrong =
				WorkerSetup.ensureWorktree({ repo = primary, path = path, branch = "helper/b", base = "main" }, host)
			assert(wrong.status == "FAIL")
			expect(wrong.detail):toContain("holds helper/a")

			sh(primary, { "git", "branch", "helper/c", "main" })
			local existing = WorkerSetup.ensureWorktree(
				{ repo = primary, path = directory .. "/c", branch = "helper/c", base = "main" },
				host
			)
			assert(existing.status == "PASS")
			expect(existing.detail):toContain("existing branch")

			local occupied = WorkerSetup.ensureWorktree(
				{ repo = primary, path = directory .. "/d", branch = "helper/c", base = "main" },
				host
			)
			assert(occupied.status == "FAIL")

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

		case("syncs dependencies only when the lock changes", function(directory)
			local primary = initRepository(directory)
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

		case("creates declared directories", function(directory)
			local primary = initRepository(directory)
			local host = checkoutHost(primary, recorder())
			local config: WorkerSetup.Config =
				{ base = "main", directories = { "build", "build/generated" }, inputs = {} }
			local first = WorkerSetup.prepareCheckout(config, host, {})
			expect(first[1].status == "SKIP" or first[1].status == "PASS"):toBeTruthy()
			expect(fs.exists(primary .. "/build/generated")):toBeTruthy()
			expect(WorkerSetup.prepareCheckout(config, host, {})[2].status):toBe("SKIP")
		end)

		case("runs appended steps after checkout preparation and continues after a failed step", function(directory)
			local primary = initRepository(directory)
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
						return { name = name, status = status, detail = "appended step" }
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

		case("hydrates LFS pointer files", function(directory)
			local primary = initRepository(directory)
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

		case("removes undeclared generated manifests", function(directory)
			local primary = initRepository(directory)
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

		case("ignores a collapsed ignored directory", function(directory)
			local primary = initRepository(directory)
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

		case("regenerates and verifies generated inputs", function(directory)
			local primary = initRepository(directory)
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
		end)
	end)
end
