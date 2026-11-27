--!strict

local WorkerSetup = require("./worker-setup")

export type Config = {
	repo: string,
	trunk: string,
	lanesRoot: string,
	extraManagedRoots: { string }?,
	lanePath: ((branch: string) -> string?)?,
	dryRun: boolean?,
}
export type Host = {
	run: (argv: { string }, cwd: string) -> WorkerSetup.CommandResult,
	canonical: (path: string) -> string,
	busy: (path: string?, branch: string?, refresh: boolean) -> boolean,
	now: () -> number,
	notify: (line: string) -> (),
}

type Tree = { path: string, physical: string, ref: string?, head: string?, held: boolean, missing: boolean }
type Branch = { tip: string, date: number, tree: string }

local function checked(argv: { string }, result: WorkerSetup.CommandResult): string
	assert(result.exitcode == 0, table.concat(argv, " ") .. ": " .. result.stderr)
	return result.stdout
end

local function worktrees(raw: string, canonical: (string) -> string): { Tree }
	local trees: { Tree } = {}
	for record in raw:gmatch("(.-)%z%z") do
		local fields = record:split("\0")
		local path = assert(fields[1]:match("^worktree (.+)$"), "invalid worktree list")
		local tree: Tree = { path = path, physical = canonical(path), held = false, missing = false }
		for _, field in fields do
			if field:sub(1, 7) == "branch " then
				tree.ref = field:sub(8)
			elseif field:sub(1, 5) == "HEAD " then
				tree.head = field:sub(6)
			elseif field:match("^locked") or field == "bare" then
				tree.held = true
			elseif field:match("^prunable") then
				tree.missing = true
			end
		end
		table.insert(trees, tree)
	end
	assert(#trees > 0, "empty worktree list")
	return trees
end

local function inside(path: string, directory: string): boolean
	return path:sub(1, #directory + 1) == directory .. "/"
end

local function hygiene(config: Config, host: Host)
	local repo = config.repo
	local root = host.canonical(config.lanesRoot)
	assert(root:sub(1, 1) == "/" and root ~= "/", "supply an absolute lanes directory")
	local extraRoots: { string } = {}
	for _, directory in config.extraManagedRoots or {} do
		assert(directory ~= "", "empty managed directory")
		local physical = host.canonical(if directory:sub(1, 1) == "/" then directory else repo .. "/" .. directory)
		assert(physical:sub(1, 1) == "/" and physical ~= "/", "supply an absolute managed directory")
		table.insert(extraRoots, physical)
	end
	local function externallyManaged(physical: string): boolean
		for _, directory in extraRoots do
			if physical == directory or inside(physical, directory) then
				return true
			end
		end
		return false
	end
	local trunkRef = "refs/heads/" .. config.trunk
	local function git(cwd: string, ...: string): string
		local argv = { "git", ... }
		return checked(argv, host.run(argv, cwd))
	end
	local function inventory(): { Tree }
		return worktrees(git(repo, "worktree", "list", "--porcelain", "-z"), host.canonical)
	end
	local function attempt(label: string, operation: () -> ())
		local ok, problem = pcall(operation)
		if not ok then
			host.notify("HYGIENE ERROR " .. label .. " " .. tostring(problem))
		end
	end
	git(repo, "check-ref-format", trunkRef)
	if not config.dryRun then
		attempt("prune", function()
			if #extraRoots > 0 then
				for _, tree in inventory() do
					if tree.missing and externallyManaged(tree.physical) then
						return
					end
				end
			end
			git(repo, "worktree", "prune")
		end)
		attempt("fetch", function()
			git(repo, "fetch", "--prune", "--all", "--no-auto-maintenance")
		end)
	end

	local branches: { [string]: Branch } = {}
	local ordered: { string } = {}
	local remoteTrunks: { [string]: boolean } = {}
	for remote in git(repo, "remote"):gmatch("[^\n]+") do
		remoteTrunks[remote .. "/" .. config.trunk] = true
	end
	local refs = git(
		repo,
		"for-each-ref",
		"--format=%(refname)%09%(objectname)%09%(committerdate:unix)%09%(tree)%09%(symref)",
		"refs/heads",
		"refs/remotes"
	)
	for line in refs:gmatch("[^\n]+") do
		local ref, tip, date, tree, symbolic = table.unpack(line:split("\t"))
		local remote = ref:match("^refs/remotes/(.+)$")
		if remote then
			if symbolic == "" and not remoteTrunks[remote] then
				host.notify("REMOTE " .. remote)
			end
		else
			branches[ref] = { tip = tip, date = assert(tonumber(date)), tree = tree }
			table.insert(ordered, ref)
		end
	end
	local trunk = assert(branches[trunkRef], "missing trunk " .. trunkRef)
	local trees = inventory()
	local coordinator = host.canonical(repo)
	local attached: { [string]: boolean } = {}
	local detached: { [string]: boolean } = {}
	for _, tree in trees do
		if tree.ref then
			attached[tree.ref] = true
		elseif
			tree.head
			and not tree.missing
			and inside(tree.physical, root)
			and not externallyManaged(tree.physical)
		then
			detached[tree.physical] = true
		end
	end

	local function inspect(tree: Tree?, branch: string?, ref: Branch, removable: boolean)
		local path = if tree then tree.physical else nil
		local name = branch or assert(path)
		if host.busy(path, branch, false) then
			return
		end
		local count = assert(tonumber(git(repo, "rev-list", "--count", trunk.tip .. ".." .. ref.tip)))
		local dirty = tree ~= nil
			and not tree.missing
			and git(
					tree.path,
					"--no-optional-locks",
					"status",
					"--porcelain=v1",
					"--untracked-files=normal",
					"--ignore-submodules=none"
				)
				~= ""
		local landed = count == 0
		if not landed and not dirty then
			local args = {
				"git",
				"merge-tree",
				"--write-tree",
				"--no-messages",
				"--allow-unrelated-histories",
				trunk.tip,
				ref.tip,
			}
			local result = host.run(args, repo)
			landed = result.exitcode ~= 1 and checked(args, result):match("^([%x]+)\n$") == trunk.tree
		end
		if dirty or not landed then
			host.notify(("UNLANDED %s %d %ds"):format(name, count, math.max(0, host.now() - ref.date)))
			if dirty and tree then
				host.notify("DIRTY " .. tree.path)
			end
			return
		end
		if not tree or not branch or not removable then
			return
		end
		local fullRef = "refs/heads/" .. branch
		local function available(list: { Tree }): boolean
			for _, directory in extraRoots do
				if inside(directory, tree.physical) then
					return false
				end
			end
			local found = false
			for _, other in list do
				if other.physical == tree.physical then
					if found or other.ref ~= fullRef or other.head ~= ref.tip or other.held or other.missing then
						return false
					end
					found = true
				elseif other.ref == fullRef or inside(other.physical, tree.physical) then
					return false
				end
			end
			return found
		end
		if not available(trees) then
			host.notify("HELD " .. tree.path)
			return
		end
		assert(
			available(inventory()) and git(repo, "rev-parse", "--verify", trunkRef) == trunk.tip .. "\n",
			"worktree or trunk moved"
		)
		if host.busy(tree.physical, branch, true) then
			return
		end
		if config.dryRun then
			host.notify("WOULD REMOVE " .. branch .. " " .. tree.path)
			return
		end
		git(repo, "worktree", "remove", "--", tree.physical)
		for _, remaining in inventory() do
			assert(remaining.ref ~= fullRef, "branch is checked out")
		end
		git(repo, "update-ref", "--no-deref", "-d", fullRef, ref.tip)
		host.notify("REMOVED " .. branch .. " " .. tree.path)
	end

	for index, tree in trees do
		if externallyManaged(tree.physical) then
			continue
		end
		local managed = inside(tree.physical, root)
		if index ~= 1 and not managed then
			host.notify("STRAY " .. tree.path)
		end
		if tree.ref == trunkRef or not tree.head then
			continue
		end
		attempt(tree.path, function()
			local name = if tree.ref then tree.ref:match("^refs/heads/(.+)$") else nil
			local branch = if tree.ref then branches[tree.ref] else nil
			if tree.ref then
				assert(branch and branch.tip == tree.head, "branch changed during inventory")
			else
				local date = assert(tonumber(git(repo, "show", "-s", "--format=%ct", assert(tree.head))))
				branch = { tip = assert(tree.head), date = date, tree = "" }
			end
			inspect(tree, name, assert(branch), index ~= 1 and managed and tree.physical ~= coordinator)
		end)
	end
	for _, ref in ordered do
		if not attached[ref] then
			local branch = ref:sub(#"refs/heads/" + 1)
			local expected = config.lanePath and config.lanePath(branch)
			local physical = expected and host.canonical(expected)
			if physical and detached[physical] then
				if host.busy(physical, branch, false) then
					continue
				end
			else
				host.notify("NO_WORKTREE " .. branch)
			end
			if ref ~= trunkRef then
				attempt(branch, function()
					inspect(nil, branch, branches[ref], false)
				end)
			end
		end
	end
end

return { run = hygiene }
