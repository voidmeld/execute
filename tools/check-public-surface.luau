--!strict

local fs = require("@std/fs")
local process = require("@lute/process")

local PACKAGES: { { prefix: string, path: string, directory: string } } = {
	{
		prefix = "CommitPolicy",
		path = "../extensions/luau/commit-policy",
		directory = "extensions/luau/commit-policy.luau",
	},
	{
		prefix = "GuardedSurface",
		path = "../extensions/luau/guarded-surface",
		directory = "extensions/luau/guarded-surface.luau",
	},
	{ prefix = "Landing", path = "../extensions/luau/landing", directory = "extensions/luau/landing.luau" },
	{ prefix = "Retention", path = "../extensions/luau/retention", directory = "extensions/luau/retention.luau" },
	{
		prefix = "ScopedChecks",
		path = "../extensions/luau/scoped-checks",
		directory = "extensions/luau/scoped-checks.luau",
	},
	{
		prefix = "WorkerSetup",
		path = "../extensions/luau/worker-setup",
		directory = "extensions/luau/worker-setup.luau",
	},
}

local UNDOCUMENTED_BY_DESIGN: { [string]: string } = {}

local function exportsOf(path: string): ({ string }, string?)
	local ok, moduleOrError: unknown = pcall(require, path)
	if not ok then
		return {}, tostring(moduleOrError)
	end
	if type(moduleOrError) ~= "table" then
		return {}, ("%s does not return a table"):format(path)
	end
	local names: { string } = {}
	for key in moduleOrError :: { [string]: unknown } do
		table.insert(names, key)
	end
	table.sort(names)
	return names, nil
end

local function documented(): { [string]: true }
	local text = fs.readFileToString("docs/api.md")
	local found: { [string]: true } = {}
	for line in string.gmatch(text, "[^\n]+") do
		local entry = string.match(line, "^###%s+`([%w_]+%.[%w_]+)`")
		if entry ~= nil then
			found[entry] = true
		end
	end
	return found
end

local function main(): number
	if not fs.exists("docs/api.md") then
		print("check-public-surface: required docs/api.md is absent")
		return 1
	end

	local problems: { string } = {}
	local docs = documented()
	local checked = 0

	local seenInDocs: { [string]: true } = {}

	for _, package in PACKAGES do
		if not fs.exists(package.directory) then
			table.insert(problems, package.directory .. " is required but absent")
			continue
		end
		local names, loadError = exportsOf(package.path)
		if loadError ~= nil then
			table.insert(problems, ("%s: could not load: %s"):format(package.prefix, loadError))
			continue
		end
		for _, name in names do
			local qualified = package.prefix .. "." .. name
			seenInDocs[qualified] = true
			checked += 1
			if docs[qualified] == nil and UNDOCUMENTED_BY_DESIGN[qualified] == nil then
				table.insert(
					problems,
					("%s is exported but docs/api.md has no `### %s` entry"):format(qualified, qualified)
				)
			end
		end
	end

	for entry in docs do
		if not seenInDocs[entry] then
			table.insert(problems, ("docs/api.md documents %s but no package exports it"):format(entry))
		end
	end

	if #problems > 0 then
		table.sort(problems)
		print(("check-public-surface: %d problem(s)"):format(#problems))
		for _, problem in problems do
			print("  " .. problem)
		end
		return 1
	end

	print(("check-public-surface: ok (%d exports, all documented)"):format(checked))
	return 0
end

local code = main()
if code ~= 0 then
	process.exit(code)
end
return nil
