--!strict

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local Lanes = require("../../extensions/luau/lanes")
local WorkerSetup = require("../../extensions/luau/worker-setup")

local function output(argv: { string }): string
	local result = process.run(argv, { timeout = 60 })
	assert(result.ok, argv[1] .. ": " .. result.stderr)
	return result.stdout
end

local function canonical(directory: string): string
	local absolute = path.format(path.resolve(directory))
	if fs.exists(absolute) then
		return (output({ "realpath", absolute }):gsub("\n$", ""))
	end
	local parent, name = absolute:match("^(.*)/([^/]+)$")
	assert(parent and name, "invalid directory: " .. absolute)
	return canonical(if parent == "" then "/" else parent) .. "/" .. name
end

local function hygiene(config: Lanes.Hygiene, active: (name: string) -> boolean, notify: (string) -> ())
	local root = canonical(config.lanesRoot)
	local spelling = path.format(path.resolve(config.lanesRoot))
	local openPaths: { string } = {}
	local commands = ""
	local function mentions(directory: string): boolean
		local at = 1
		while true do
			local _, last = commands:find(directory, at, true)
			if not last then
				return false
			end
			local nextByte = commands:sub(last + 1, last + 1)
			if nextByte == "" or nextByte:match("[/%s'\"]") then
				return true
			end
			at = last + 1
		end
	end
	local function busy(directory: string?, branch: string?, refresh: boolean): boolean
		if branch and (active(branch) or active(assert(branch:match("[^/]+$")))) then
			return true
		end
		if not directory then
			return false
		end
		if active(assert(directory:match("[^/]+$"))) then
			return true
		end
		if commands == "" or refresh then
			local files = output({ "lsof", "-nP", "-F0n" })
			assert(files:find("p" .. process.pid() .. "\0", 1, true), "incomplete open file inventory")
			table.clear(openPaths)
			for file in files:gmatch("%zn(/[^%z]*)%z") do
				table.insert(openPaths, file)
			end
			commands = output({ "ps", "-Aww", "-o", "command=" })
			assert(commands:find("%S"), "empty process inventory")
		end
		for _, file in openPaths do
			if file == directory or file:sub(1, #directory + 1) == directory .. "/" then
				return true
			end
		end
		if mentions(directory) then
			return true
		end
		return directory:sub(1, #root + 1) == root .. "/" and mentions(spelling .. directory:sub(#root + 1))
	end

	local scratch: string? = nil
	local env: { [string]: string } = {}
	for key, value in process.env do
		env[key] = value
	end
	env.GIT_TERMINAL_PROMPT = "0"
	env.GIT_NO_REPLACE_OBJECTS = "1"
	if config.dryRun then
		env.GIT_NO_LAZY_FETCH = "1"
	end
	local mergeEnv = table.clone(env)
	mergeEnv.GIT_CONFIG_NOSYSTEM = "1"
	mergeEnv.GIT_CONFIG_GLOBAL = "/dev/null"
	local function run(argv: { string }, cwd: string): WorkerSetup.CommandResult
		if argv[2] == "merge-tree" and not scratch then
			local objects = output({ "git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-path", "objects" })
			local format = output({ "git", "-C", cwd, "rev-parse", "--show-object-format" }):gsub("\n$", "")
			local directory = output({ "mktemp", "-d" }):gsub("\n$", "")
			scratch = directory
			mergeEnv.GIT_DIR = directory
			local init = process.run(
				{ "git", "init", "--bare", "--template=", "--object-format=" .. format, directory },
				{ env = mergeEnv }
			)
			assert(init.ok, init.stderr)
			fs.createDirectory(directory .. "/info", { makeParents = true })
			fs.writeStringToFile(directory .. "/info/attributes", "* !merge\n")
			fs.writeStringToFile(directory .. "/objects/info/alternates", objects)
		end
		local result =
			process.run(argv, { cwd = cwd, env = if argv[2] == "merge-tree" then mergeEnv else env, timeout = 120 })
		return { exitcode = result.exitcode, stdout = result.stdout, stderr = result.stderr }
	end
	local ok, problem = pcall(Lanes.hygiene, config, {
		run = run,
		canonical = canonical,
		busy = busy,
		now = function()
			return os.time()
		end,
		notify = notify,
	})
	if scratch then
		fs.removeDirectory(scratch, { recursive = true })
	end
	if not ok then
		error(problem, 0)
	end
end

return hygiene
