--!strict

local Bdd = require("@verify/src/bdd")
local Verify = require("@verify/src/core")
local Lanes = require("./lanes")

local function fixture()
	local config: Lanes.Hygiene = { repo = "/primary", lanesRoot = "/alias", trunk = "release/current" }
	local paths: { [string]: string } = {}
	local refs: { [string]: string } = {}
	local tips: { [string]: string } = {}
	local output: { string } = {}
	local writes: { string } = {}
	local dirty: { [string]: boolean } = {}
	local locked: { [string]: boolean } = {}
	local missing: { [string]: boolean } = {}
	local workers: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	local merged: { [string]: string } = {}
	local function add(branch: string, tip: string, path: string?)
		refs[branch] = tip
		if path then
			paths[path] = branch
			tips[path] = tip
		end
	end
	add(config.trunk, "aa", "/primary")
	local function record(path: string): string
		return "worktree "
			.. path
			.. "\0HEAD "
			.. tips[path]
			.. "\0"
			.. (if paths[path] == "" then "detached" else "branch refs/heads/" .. paths[path])
			.. (if locked[path] then "\0locked user reservation" else "")
			.. (if missing[path] then "\0prunable missing gitdir" else "")
			.. "\0\0"
	end
	local function canonical(path: string): string
		return (path:gsub("^/alias", "/lanes"))
	end
	local host: Lanes.HygieneHost = {
		now = function()
			return 250
		end,
		canonical = canonical,
		busy = function(path, branch)
			return workers[path or branch or ""] == true
		end,
		notify = function(line)
			table.insert(output, line)
		end,
		run = function(args, cwd)
			assert(args[1] == "git")
			local verb, stdout, code = args[2], "", 0
			if verb == "worktree" and args[3] == "list" then
				stdout = record("/primary")
				for path in paths do
					if path ~= "/primary" then
						stdout ..= record(path)
					end
				end
			elseif verb == "remote" then
				stdout = "up\n"
			elseif verb == "for-each-ref" then
				for name, tip in refs do
					stdout ..= "refs/heads/" .. name .. "\t" .. tip .. "\t150\tcc\t\n"
				end
				stdout ..= "refs/remotes/up/release/current\taa\t150\tcc\t\nrefs/remotes/up/topic\tdd\t150\tde\t\nrefs/remotes/up/HEAD\taa\t150\tcc\trefs/remotes/up/release/current\n"
			elseif verb == "rev-list" then
				stdout = tostring(counts[assert(args[4]:match("^aa%.%.(.+)$"))] or 0) .. "\n"
			elseif verb == "merge-tree" then
				local tree = merged[args[#args]]
				code = if tree then 0 else 1
				stdout = tree or "cc"
				stdout ..= "\n"
			elseif verb == "rev-parse" then
				stdout = refs[config.trunk] .. "\n"
			elseif verb == "show" then
				stdout = "150\n"
			elseif verb == "--no-optional-locks" then
				assert(args[3] == "status")
				stdout = if dirty[cwd] then "?? unsaved\n" else ""
			elseif verb == "worktree" and args[3] == "remove" then
				assert(#args == 5 and args[4] == "--")
				for path in paths do
					if canonical(path) == args[5] then
						paths[path] = nil
						break
					end
				end
				table.insert(writes, table.concat(args, " "))
			elseif verb == "update-ref" then
				local branch = assert(args[5]:match("^refs/heads/(.+)$"))
				assert(args[3] == "--no-deref" and args[4] == "-d" and refs[branch] == args[6])
				refs[branch] = nil
				table.insert(writes, table.concat(args, " "))
			elseif verb == "fetch" or (verb == "worktree" and args[3] == "prune") then
				table.insert(writes, table.concat(args, " "))
			else
				assert(verb == "check-ref-format", table.concat(args, " "))
			end
			return { exitcode = code, stdout = stdout, stderr = "" }
		end,
	}
	local function run()
		table.clear(output)
		table.clear(writes)
		Lanes.hygiene(config, host)
		table.sort(output)
		return table.concat(output, "\n")
	end
	return {
		add = add,
		run = run,
		paths = paths,
		tips = tips,
		refs = refs,
		workers = workers,
		config = config,
		locked = locked,
		missing = missing,
		dirty = dirty,
		counts = counts,
		merged = merged,
		writes = writes,
		host = host,
	}
end

return function(suite: Verify.Harness)
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect
	describe("lane hygiene", function()
		it("matches detached lane paths through directory aliases and still reports idle branch work", function()
			local f = fixture()
			f.config.lanePath = function(branch: string): string?
				local name = branch:match("^topic/(.+)$")
				return if name then "/alias/" .. name else nil
			end
			f.add("topic/data", "bb", nil)
			f.add("topic/data-old", "dd", nil)
			f.paths["/lanes/data"], f.tips["/lanes/data"] = "", "aa"
			f.counts.bb = 1
			local expected = "NO_WORKTREE topic/data-old\nREMOTE up/topic"
			expect(f.run()):toBe(expected .. "\nUNLANDED topic/data 1 100s")
			f.workers["/lanes/data"] = true
			expect(f.run()):toBe(expected)
			expect(f.refs["topic/data"]):toBe("bb")
			expect(f.paths["/lanes/data"]):toBe("")
		end)

		it("prunes and removes only idle, clean, landed lane pairs", function()
			local f = fixture()
			f.add("contained", "bb", "/alias/contained")
			f.add("squash", "dd", "/lanes/squash")
			f.add("working", "aa", "/lanes/working")
			f.add("reserved", "aa", "/lanes/reserved")
			f.locked["/lanes/reserved"] = true
			f.workers["/lanes/working"] = true
			f.counts.dd, f.merged.dd = 2, "cc"
			local output = f.run()
			expect(output):toContain("REMOVED contained /alias/contained")
			expect(output):toContain("REMOVED squash /lanes/squash")
			expect(f.writes[1]):toBe("git worktree prune")
			expect(f.writes[2]):toBe("git fetch --prune --all --no-auto-maintenance")
			expect(#f.writes):toBe(6)
			expect(f.refs.working):toBe("aa")
			expect(f.refs.reserved):toBe("aa")
			expect(f.refs[f.config.trunk]):toBe("aa")
		end)

		it("leaves extra managed roots and their stale registrations to their owner", function()
			local f = fixture()
			f.config.extraManagedRoots = { "/primary/releases", "/alias/builds" }
			local release = "/primary/releases/dev/aa"
			f.paths[release], f.tips[release] = "", "aa"
			f.dirty[release] = true
			f.add("owned", "bb", "/lanes/builds/publish")
			f.add("ordinary", "bb", "/lanes/builds-old/publish")
			f.add("foreign", "bb", "/primary/releases-old/dev/bb")
			local expected = "REMOTE up/topic\nSTRAY /primary/releases-old/dev/bb"
			f.config.dryRun = true
			expect(f.run()):toBe(expected .. "\nWOULD REMOVE ordinary /lanes/builds-old/publish")
			expect(#f.writes):toBe(0)
			f.config.dryRun = false
			f.missing[release] = true
			expect(f.run()):toBe(
				"REMOTE up/topic\nREMOVED ordinary /lanes/builds-old/publish\nSTRAY /primary/releases-old/dev/bb"
			)
			expect(#f.writes):toBe(3)
			expect(f.writes[1]):toBe("git fetch --prune --all --no-auto-maintenance")
			expect(f.refs.owned):toBe("bb")
			expect(f.paths[release]):toBe("")
		end)

		it("repeats dirty, divergent, detached and unattached findings every tick", function()
			local f = fixture()
			f.add("topic", "bb", "/alias/topic")
			f.add("orphan", "dd", nil)
			f.add("local-edits", "aa", "/lanes/drafts")
			f.add("elsewhere", "aa", "/lanes-old/elsewhere")
			f.paths["/ship copy"], f.tips["/ship copy"] = "", "bb"
			f.dirty["/lanes/drafts"] = true
			f.counts.bb, f.counts.dd, f.merged.bb = 1, 3, "ab"
			local expected = table.concat({
				"DIRTY /lanes/drafts",
				"NO_WORKTREE orphan",
				"REMOTE up/topic",
				"STRAY /lanes-old/elsewhere",
				"STRAY /ship copy",
				"UNLANDED /ship copy 1 100s",
				"UNLANDED local-edits 0 100s",
				"UNLANDED orphan 3 100s",
				"UNLANDED topic 1 100s",
			}, "\n")
			expect(f.run()):toBe(expected)
			expect(f.run()):toBe(expected)
			expect(#f.writes):toBe(2)
		end)

		it("previews without mutation and keeps parents of registered nested worktrees", function()
			local f = fixture()
			f.config.dryRun = true
			f.add("landed", "bb", "/alias/landed")
			f.add("parent", "aa", "/alias/parent")
			f.paths["/lanes/parent/build/review"], f.tips["/lanes/parent/build/review"] = "", "aa"
			local preview = f.run()
			expect(preview):toContain("WOULD REMOVE landed /alias/landed")
			expect(preview):toContain("HELD /alias/parent")
			expect(#f.writes):toBe(0)
			expect(f.paths["/alias/landed"]):toBe("landed")
		end)

		it("rechecks ownership and retains the branch if worktree removal fails", function()
			local f = fixture()
			f.add("started", "aa", "/lanes/started")
			f.add("changed", "bb", "/lanes/changed")
			f.host.busy = function(_, branch, refresh)
				return branch == "started" and refresh
			end
			f.config.dryRun = true
			expect(f.run()):toBe("REMOTE up/topic\nWOULD REMOVE changed /lanes/changed")
			expect(#f.writes):toBe(0)
			f.config.dryRun = false
			local run = f.host.run
			f.host.run = function(args, cwd)
				if args[3] == "remove" then
					return { exitcode = 128, stdout = "", stderr = "worktree has changes" }
				end
				return run(args, cwd)
			end
			expect(f.run()):toContain("worktree has changes")
			expect(#f.writes):toBe(2)
			expect(f.refs.changed):toBe("bb")
			expect(f.paths["/lanes/started"]):toBe("started")
		end)
	end)
end
