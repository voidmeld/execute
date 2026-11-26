--!strict

local fs = require("@std/fs")
local process = require("@lute/process")
local Bdd = require("@verify/src/bdd")
local Verify = require("@verify/src/core")
local TemporaryDirectory = require("@verify/src/checks").temporaryDirectory
local Lanes = require("./lanes")
local WorkerSetup = require("./worker-setup")

local function git(cwd: string, ...: string): string
	local result = process.run({ "git", ... }, { cwd = cwd })
	assert(result.ok, result.stderr)
	return (string.gsub(result.stdout, "%s+$", ""))
end

local function commitFile(cwd: string, file: string, contents: string)
	fs.writeStringToFile(cwd .. "/" .. file, contents)
	git(cwd, "add", "--", file)
	git(cwd, "commit", "-qm", contents)
end

local function checkout(root: string): Lanes.Landing
	local repo, worktree = root .. "/primary", root .. "/lane one"
	git(root, "init", "-q", "-b", "trunk", repo)
	git(repo, "config", "user.name", "Test")
	git(repo, "config", "user.email", "test@example.com")
	commitFile(repo, "shared", "base")
	git(repo, "worktree", "add", "-qb", "topic", worktree)
	commitFile(worktree, "feature", "change")
	commitFile(repo, "shared", "new base")
	return {
		repo = repo,
		worktree = worktree,
		branch = "topic",
		main = "trunk",
		remote = ".",
		setup = { "project", "setup" },
		check = { "project", "check" },
		release = { "project", "release" },
		otherPids = { 11, 12, 13 },
	}
end

type Hooks = { [string]: () -> number? }

local function driver(lane: Lanes.Landing, calls: { string }, hooks: Hooks): Lanes.Host
	local function step(name: string): number
		table.insert(calls, name)
		local hook = hooks[name]
		return if hook then hook() or 0 else 0
	end

	local polls = 0
	local checked = ""
	return {
		releaseRunning = function()
			polls += 1
			return polls <= 2
		end,
		waitForPoll = function()
			step("wait")
		end,
		pause = function(pid)
			step("pause " .. pid)
			if pid == 12 then
				return nil
			end
			return function()
				step("resume " .. pid)
			end
		end,
		run = function(command, cwd)
			local name = command[2]
			if command[1] == "project" or name == "push" then
				if name == "release" then
					assert(cwd == lane.repo and command[3] == checked)
				else
					assert(cwd == lane.worktree)
				end
				if name == "check" then
					checked = git(cwd, "rev-parse", "HEAD")
					git(cwd, "merge-base", "--is-ancestor", "trunk", checked)
				elseif name == "push" then
					assert(
						table.concat(command, " ")
							== "git push --no-follow-tags -- . " .. checked .. ":refs/heads/trunk"
					)
				end
				return { exitcode = step(name), stdout = "", stderr = "injected " .. name }
			end
			assert(command[1] == "git")
			if name == "fetch" or name == "rebase" or name == "worktree" or name == "update-ref" then
				step(if command[3] == "--abort" then "abort" else name)
			end
			return process.run(command, { cwd = cwd })
		end,
	}
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("supervising lanes", function()
		it("distinguishes a report, an exit and a live lane at its deadline", function()
			local lane = { startedAt = 10, reported = false, alive = true }
			expect(Lanes.classify(lane, 14, 5)):toBe("running")
			expect(Lanes.classify(lane, 15, 5)):toBe("over the cap")
			lane.alive = false
			expect(Lanes.classify(lane, 16, 5)):toBe("exited without a report")
			lane.reported = true
			expect(Lanes.classify(lane, 16, 5)):toBe("reported")
			lane.alive = true
			expect(Lanes.classify(lane, 16, 5)):toBe("reported")
		end)
	end)

	describe("running a lane queue", function()
		it("fills free slots in order and skips names that already started", function()
			local pending = {
				{ name = "done", brief = "one" },
				{ name = "docs", brief = "two" },
				{ name = "api", brief = "three" },
				{ name = "style", brief = "four" },
			}
			local known = { done = false, api = true, external = true }
			local starts = Lanes.selectStarts(pending, known, 3)
			expect(#starts):toBe(1)
			expect(starts[1].brief):toBe("two")
			expect(#Lanes.selectStarts(pending, known, 1)):toBe(0)
			expect(#Lanes.selectStarts(pending, {}, 0)):toBe(0)
			expect(Lanes.selectStarts(pending, known, 4)[2].name):toBe("style")
			expect(#pending):toBe(4)
			expect(known.docs):toBe(nil)
		end)

		it("rejects duplicate names and fractional slot limits", function()
			local lane = { name = "api", brief = "brief" }
			expect(pcall(Lanes.selectStarts, { lane, lane }, {}, 1)):toBeFalsy()
			expect(pcall(Lanes.selectStarts, { lane }, {}, 1.5)):toBeFalsy()
		end)

		it("reports each change once and keeps a live lane in its slot", function()
			local queue: Lanes.Queue = {
				pending = { { name = "docs", brief = "first brief" }, { name = "api", brief = "second" } },
				slots = 1,
				capSeconds = 5,
				start = { "launch", "--local" },
			}
			local runs: { Lanes.Run } = {}
			local events: { string } = {}
			local commands: { string } = {}
			local now, alive, reported = 10, true, false
			local host: Lanes.QueueHost = {
				now = function()
					return now
				end,
				alive = function(pid)
					return pid ~= 11 or alive
				end,
				reported = function(file)
					return file == "docs/report" and reported
				end,
				start = function(command)
					table.insert(commands, table.concat(command, "|"))
					return 10 + #commands, command[3] .. "/report"
				end,
				save = function(updated)
					runs = table.clone(updated)
				end,
				notify = function(name, status)
					table.insert(events, name .. " " .. status)
				end,
			}
			local function advance()
				table.clear(events)
				Lanes.runTick(queue, runs, host)
				return table.concat(events, ",")
			end
			expect(advance()):toBe("docs started")
			expect(commands[1]):toBe("launch|--local|docs|first brief")
			now = 15
			expect(advance()):toBe("docs over the cap")
			expect(advance()):toBe("")
			alive = false
			expect(advance()):toBe("docs exited without a report,api started")
			expect(runs[1].pid):toBe(nil)
			reported = true
			expect(advance()):toBe("docs reported")
			reported = false
			expect(advance()):toBe("")
			expect(runs[1].status):toBe("reported")
			expect(#commands):toBe(2)
		end)
	end)

	local function case(name: string, body: (Lanes.Landing, Lanes.Host, { string }, Hooks) -> ())
		it(name, function()
			TemporaryDirectory.run(TemporaryDirectory.root(), "execute-lanes", function(root)
				local lane = checkout(root)
				local calls: { string } = {}
				local hooks: Hooks = {}
				body(lane, driver(lane, calls, hooks), calls, hooks)
				return nil
			end)
		end)
	end

	local function kept(lane: Lanes.Landing)
		expect(git(lane.worktree, "symbolic-ref", "--short", "HEAD")):toBe(lane.branch)
	end

	local function fails(lane: Lanes.Landing, host: Lanes.Host, message: string)
		local ok, reason = pcall(Lanes.land, lane, host)
		expect(ok):toBeFalsy()
		expect(tostring(reason)):toContain(message)
	end

	describe("landing a lane", function()
		case("waits, checks the rebased commit, pushes it, cleans up and releases it", function(lane, host, calls)
			local before = git(lane.worktree, "rev-parse", "HEAD")
			local landed = Lanes.land(lane, host)
			expect(landed == before):toBeFalsy()
			expect(table.concat(calls, ",")):toBe(
				"wait,wait,fetch,rebase,setup,pause 11,pause 12,pause 13,check,resume 13,resume 11,push,worktree,update-ref,release"
			)
			expect(fs.exists(lane.worktree)):toBeFalsy()
			expect(git(lane.repo, "branch", "--list", lane.branch)):toBe("")
		end)

		case("aborts a conflicting rebase and restores the original branch", function(lane, host, calls)
			commitFile(lane.worktree, "shared", "conflict")
			local before = git(lane.worktree, "rev-parse", "HEAD")
			fails(lane, host, "rebase")
			expect(table.concat(calls, ",")):toBe("wait,wait,fetch,rebase,abort")
			kept(lane)
			expect(git(lane.worktree, "rev-parse", "HEAD")):toBe(before)
			expect(git(lane.worktree, "status", "--porcelain")):toBe("")
		end)

		case("pauses matching peers before and during the check and restores only acquired pauses", function(lane, host)
			lane.otherPids = {}
			lane.pausePatterns = { "^builder ", "^formatter " }
			local paused: { [number]: boolean } = { [14] = true }
			local resumes: { number } = {}
			local polls = 0
			host.pause = function(pid): (() -> ())?
				if paused[pid] then
					return nil
				end
				paused[pid] = true
				return function()
					table.insert(resumes, pid)
					paused[pid] = nil
				end
			end
			host.polling = {
				processes = function()
					local peers = {
						{ pid = 11, command = "builder docs" },
						{ pid = 12, command = "unrelated job" },
						{ pid = 14, command = "builder api" },
					}
					if polls == 2 then
						table.insert(peers, { pid = 13, command = "formatter api" })
					end
					return peers
				end,
				startCheck = function(command, cwd)
					expect(paused[11]):toBeTruthy()
					expect(paused[13]):toBe(nil)
					local result = host.run(command, cwd)
					return function(seconds): WorkerSetup.CommandResult?
						expect(seconds):toBe(3)
						expect(paused[12]):toBe(nil)
						polls += 1
						if polls < 3 then
							return nil
						end
						expect(paused[13]):toBeTruthy()
						return result
					end
				end,
			}
			Lanes.land(lane, host)
			expect(table.concat(resumes, ",")):toBe("13,11")
			expect(paused[14]):toBeTruthy()
		end)

		case("finishes the check and resumes peers after a later scan fails", function(lane, host, calls, hooks)
			lane.pausePatterns = { "worker" }
			local scans, waits = 0, 0
			host.polling = {
				processes = function()
					scans += 1
					if scans == 2 then
						error("inspection failed")
					end
					return { { pid = 14, command = "worker" } }
				end,
				startCheck = function()
					return function(): WorkerSetup.CommandResult?
						waits += 1
						if waits == 3 then
							return { exitcode = 1, stdout = "", stderr = "check failed" }
						end
						return nil
					end
				end,
			}
			hooks["resume 14"] = function(): number?
				assert(waits == 3, "resumed before the check finished")
				error("resume failed")
			end
			local ok, reason = pcall(Lanes.land, lane, host)
			expect(ok):toBeFalsy()
			expect(tostring(reason)):toContain("inspection failed")
			expect(tostring(reason)):toContain("check failed")
			expect(tostring(reason)):toContain("resume failed")
			expect(calls[#calls]):toBe("resume 11")
			expect(table.find(calls, "push")):toBe(nil)
		end)

		case("keeps the worktree and branch after a rejected push and can retry", function(lane, host, calls, hooks)
			hooks.push = function()
				return 1
			end
			fails(lane, host, "injected push")
			expect(calls[#calls]):toBe("push")
			kept(lane)
			hooks.push = nil
			lane.release = nil
			Lanes.land(lane, host)
			expect(calls[#calls]):toBe("update-ref")
		end)

		case("resumes earlier peers when pausing a later peer throws", function(lane, host, calls, hooks)
			hooks["pause 13"] = function(): number?
				error("pause failed")
			end
			fails(lane, host, "pause failed")
			expect(table.concat(calls, ",")):toBe("wait,wait,fetch,rebase,setup,pause 11,pause 12,pause 13,resume 11")
			kept(lane)
		end)

		case("tries every resume and reports both check and resume errors", function(lane, host, calls, hooks)
			hooks.check = function(): number?
				error("check failed")
			end
			hooks["resume 13"] = function(): number?
				error("resume failed")
			end
			local ok, reason = pcall(Lanes.land, lane, host)
			expect(ok):toBeFalsy()
			expect(tostring(reason)):toContain("check failed")
			expect(tostring(reason)):toContain("resume failed")
			expect(calls[#calls]):toBe("resume 11")
			kept(lane)
		end)

		case("stops if setup leaves uncommitted changes", function(lane, host, calls, hooks)
			hooks.setup = function()
				fs.writeStringToFile(lane.worktree .. "/shared", "changed")
				return 0
			end
			fails(lane, host, "worktree has changes")
			expect(table.find(calls, "check")):toBe(nil)
			kept(lane)
		end)

		case("refuses to push when the check moves the branch", function(lane, host, calls, hooks)
			hooks.check = function()
				commitFile(lane.worktree, "feature", "unchecked")
				return 0
			end
			fails(lane, host, "check changed the lane commit")
			expect(table.find(calls, "push")):toBe(nil)
			kept(lane)
		end)
	end)
end
