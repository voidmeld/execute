--!strict

export type Group = {
	name: string,
	paths: { string },
	specs: { string },
	checks: { { string } },
}

export type Selection = {
	groups: { Group },
	specs: { string },
	checks: { { string } },
}

local function matches(path: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.match(path, pattern) ~= nil then
			return true
		end
	end
	return false
end

local function touched(paths: { string }, groups: { Group }): { Group }
	local out: { Group } = {}
	for _, group in groups do
		for _, path in paths do
			if matches(path, group.paths) then
				table.insert(out, group)
				break
			end
		end
	end
	return out
end

local function unowned(paths: { string }, groups: { Group }): { string }
	local out: { string } = {}
	for _, path in paths do
		local owned = false
		for _, group in groups do
			if matches(path, group.paths) then
				owned = true
				break
			end
		end
		if not owned then
			table.insert(out, path)
		end
	end
	return out
end

local function select(
	paths: { string },
	groups: { Group },
	candidateSpecs: { string },
	keep: ((spec: string, group: Group) -> boolean)?
): Selection
	local owners = touched(paths, groups)
	local specs: { string } = {}
	for _, spec in candidateSpecs do
		for _, group in owners do
			if matches(spec, group.specs) and (keep == nil or keep(spec, group)) then
				table.insert(specs, spec)
				break
			end
		end
	end
	table.sort(specs)
	local checks: { { string } } = {}
	local seen: { [string]: boolean } = {}
	for _, group in owners do
		for _, check in group.checks do
			if not seen[check[1]] then
				seen[check[1]] = true
				table.insert(checks, check)
			end
		end
	end
	return { groups = owners, specs = specs, checks = checks }
end

return {
	matches = matches,
	touched = touched,
	unowned = unowned,
	select = select,
}
