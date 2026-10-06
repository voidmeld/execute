--!strict

export type Row = {
	path: string,
	group: string,
	rank: number,
	retained: boolean,
	terminal: boolean,
	detail: string,
}

export type FamilyKind = "newest-per-group" | "retained-terminal"

export type Family = {
	category: string,
	kind: FamilyKind,
	supersededReason: string,
	nonTerminalReason: string,
	rows: { Row },
}

export type Deletion = {
	path: string,
	category: string,
	reason: string,
}

export type Outcome = { ok: true, deletions: { Deletion } } | { ok: false, reason: string, deletions: { Deletion } }

export type CommandResult = {
	exitcode: number,
	stdout: string,
	stderr: string,
}

local function newestPerGroup(category: string, reason: string, rows: { Row }): { Deletion }
	local newest: { [string]: Row } = {}
	for _, row in rows do
		local held = newest[row.group]
		if
			held == nil
			or row.rank > (held :: Row).rank
			or (row.rank == (held :: Row).rank and row.path > held.path)
		then
			newest[row.group] = row
		end
	end
	local deletions: { Deletion } = {}
	for _, row in rows do
		local kept = newest[row.group] :: Row
		if kept.path ~= row.path then
			table.insert(deletions, {
				path = row.path,
				category = category,
				reason = ("%s group=%s retained=%s%s"):format(reason, row.group, kept.path, row.detail),
			})
		end
	end
	return deletions
end

local function retainedTerminal(
	category: string,
	supersededReason: string,
	nonTerminalReason: string,
	rows: { Row }
): { Deletion }
	local deletions: { Deletion } = {}
	for _, row in rows do
		if not row.retained then
			table.insert(deletions, {
				path = row.path,
				category = category,
				reason = ("%s group=%s%s"):format(supersededReason, row.group, row.detail),
			})
		elseif not row.terminal then
			table.insert(deletions, {
				path = row.path,
				category = category,
				reason = ("%s group=%s%s"):format(nonTerminalReason, row.group, row.detail),
			})
		end
	end
	return deletions
end

local function plan(families: { Family }): { Deletion }
	local deletions: { Deletion } = {}
	for _, family in families do
		local produced = if family.kind == "newest-per-group"
			then newestPerGroup(family.category, family.supersededReason, family.rows)
			else retainedTerminal(family.category, family.supersededReason, family.nonTerminalReason, family.rows)
		for _, deletion in produced do
			table.insert(deletions, deletion)
		end
	end
	table.sort(deletions, function(left: Deletion, right: Deletion): boolean
		return left.path < right.path
	end)
	return deletions
end

local function run(mode: string, families: { Family }, remove: ({ string }) -> CommandResult): Outcome
	local deletions = plan(families)
	if mode == "plan" then
		return { ok = true, deletions = deletions }
	end
	if mode == "check" then
		if #deletions > 0 then
			return { ok = false, reason = "retention_violation", deletions = deletions }
		end
		return { ok = true, deletions = deletions }
	end
	if mode == "apply" then
		if #deletions == 0 then
			return { ok = true, deletions = deletions }
		end
		local paths: { string } = {}
		for _, deletion in deletions do
			table.insert(paths, deletion.path)
		end
		local result = remove(paths)
		if result.exitcode ~= 0 then
			return { ok = false, reason = "remove_failed:" .. tostring(result.exitcode), deletions = deletions }
		end
		return { ok = true, deletions = deletions }
	end
	return { ok = false, reason = "usage", deletions = deletions }
end

return {
	newestPerGroup = newestPerGroup,
	retainedTerminal = retainedTerminal,
	plan = plan,
	run = run,
}
