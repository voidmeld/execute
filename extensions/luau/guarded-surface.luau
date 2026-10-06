--!strict

export type Tier = {
	name: string,
	exactFiles: { string },
	prefixes: { string },
}

export type MixedRule = {
	path: string,
	sectionPattern: string,
}

export type Authority = {
	actual: string?,
	recorded: string?,
	reason: string?,
}

export type Policy = {
	tiers: { Tier },
	mixed: MixedRule?,
	reason: string,
	passDetail: string,
	authorizedDetail: (actual: string) -> string,
	refusalDetail: (offending: { string }, authority: Authority) -> string,
}

export type Dependencies = {
	mixedDiff: (path: string) -> string?,
	mixedBase: (path: string) -> string?,
	mixedHead: (path: string) -> string?,
}

export type Pass = { status: "pass", detail: string }
export type PassOverride = { status: "pass_override", bypassed: string, warning: string, banking: string }
export type Refuse = { status: "refuse", reason: string, detail: string, paths: { string } }
export type Verdict = Pass | PassOverride | Refuse

export type Hunk = {
	oldStart: number,
	oldCount: number,
	newStart: number,
	newCount: number,
}

export type Heading = {
	line: number,
	heading: string,
}

local function trimmed(value: string): string
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function pushUnique(into: { string }, seen: { [string]: boolean }, value: string)
	if value == "" or seen[value] then
		return
	end
	seen[value] = true
	table.insert(into, value)
end

local function sectionText(document: string, headingPattern: string): string?
	local collected: { string } = {}
	local capturing = false
	for line in (document .. "\n"):gmatch("([^\n]*)\n") do
		if string.match(line, "^##%s") ~= nil then
			if string.match(line, headingPattern) ~= nil then
				capturing = true
			elseif capturing then
				break
			end
		end
		if capturing then
			table.insert(collected, line)
		end
	end
	if not capturing then
		return nil
	end
	return table.concat(collected, "\n")
end

local function withoutAsides(text: string): string
	local stripped = text
	for _ = 1, 8 do
		local reduced = (string.gsub(stripped, "%b()", " "))
		if reduced == stripped then
			break
		end
		stripped = reduced
	end
	return stripped
end

local function pathsFromSection(section: string): ({ string }, { string })
	local body = withoutAsides(section)
	local prefixes: { string } = {}
	local prefixSeen: { [string]: boolean } = {}
	for token in string.gmatch(body, "[%w%.][%w%.%-_/]*/%*%*") do
		pushUnique(prefixes, prefixSeen, token)
	end
	local remainder = (string.gsub(body, "[%w%.][%w%.%-_/]*/%*%*", " "))
	local exactFiles: { string } = {}
	local exactSeen: { [string]: boolean } = {}
	for token in string.gmatch(remainder, "[%w][%w%.%-_/]*%.[%w]+") do
		pushUnique(exactFiles, exactSeen, token)
	end
	return exactFiles, prefixes
end

local function matchedRule(path: string, tier: Tier): string?
	for _, exact in tier.exactFiles do
		if path == exact then
			return exact
		end
	end
	for _, prefix in tier.prefixes do
		local root = string.sub(prefix, 1, #prefix - 2)
		if string.sub(path, 1, #root) == root then
			return prefix
		end
	end
	return nil
end

local function parseHunks(diffText: string): { Hunk }
	local hunks: { Hunk } = {}
	for line in (diffText .. "\n"):gmatch("([^\n]*)\n") do
		local oldStart, oldCount, newStart, newCount = string.match(line, "^@@%s+%-(%d+),?(%d*)%s+%+(%d+),?(%d*)%s+@@")
		if oldStart ~= nil then
			table.insert(hunks, {
				oldStart = tonumber(oldStart) :: number,
				oldCount = if oldCount == "" then 1 else tonumber(oldCount) :: number,
				newStart = tonumber(newStart) :: number,
				newCount = if newCount == "" then 1 else tonumber(newCount) :: number,
			})
		end
	end
	return hunks
end

local function headingIndex(text: string): { Heading }
	local index: { Heading } = {}
	local number = 0
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		number += 1
		if string.match(line, "^##%s") ~= nil then
			table.insert(index, { line = number, heading = trimmed(line) })
		end
	end
	return index
end

local function headingAt(index: { Heading }, lineNumber: number): string?
	local current: string? = nil
	for _, entry in index do
		if entry.line > lineNumber then
			break
		end
		current = entry.heading
	end
	return current
end

local function sectionsTouched(diffText: string, baseText: string, headText: string, headingPattern: string): { string }
	local baseIndex = headingIndex(baseText)
	local headIndex = headingIndex(headText)
	local hits: { string } = {}
	local seen: { [string]: boolean } = {}
	local function consider(index: { Heading }, first: number, count: number)
		if count <= 0 then
			return
		end
		for line = first, first + count - 1 do
			local heading = headingAt(index, line)
			if heading ~= nil and string.match(heading, headingPattern) ~= nil then
				pushUnique(hits, seen, heading)
			end
		end
	end
	for _, hunk in parseHunks(diffText) do
		consider(baseIndex, hunk.oldStart, hunk.oldCount)
		consider(headIndex, hunk.newStart, hunk.newCount)
	end
	return hits
end

local function mixedOffence(mixed: MixedRule, deps: Dependencies): string?
	local diffText = deps.mixedDiff(mixed.path)
	local baseText = deps.mixedBase(mixed.path)
	local headText = deps.mixedHead(mixed.path)
	if diffText == nil or baseText == nil or headText == nil then
		return ("%s (guarded-section membership UNPROVABLE: the diff, the base revision, or the head"):format(
			mixed.path
		) .. " revision of the file could not be read, so the guard refuses closed)"
	end
	local touched = sectionsTouched(diffText :: string, baseText :: string, headText :: string, mixed.sectionPattern)
	if #touched == 0 then
		return nil
	end
	return ("%s (guarded sections touched: %s)"):format(mixed.path, table.concat(touched, " | "))
end

local function offendingPaths(changedPaths: { string }, policy: Policy, deps: Dependencies): { string }
	local offending: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, path in changedPaths do
		for _, tier in policy.tiers do
			local rule = matchedRule(path, tier)
			if rule ~= nil then
				pushUnique(offending, seen, ("%s (%s rule: %s)"):format(path, tier.name, rule :: string))
				break
			end
		end
	end
	local mixed = policy.mixed
	if mixed ~= nil then
		for _, path in changedPaths do
			if path == (mixed :: MixedRule).path then
				local offence = mixedOffence(mixed :: MixedRule, deps)
				if offence ~= nil then
					pushUnique(offending, seen, offence :: string)
				end
			end
		end
	end
	return offending
end

local function evaluate(changedPaths: { string }, policy: Policy, authority: Authority, deps: Dependencies): Verdict
	local offending = offendingPaths(changedPaths, policy, deps)
	if #offending == 0 then
		return { status = "pass", detail = policy.passDetail }
	end
	if authority.actual ~= nil and authority.recorded == authority.actual then
		return { status = "pass", detail = policy.authorizedDetail(authority.actual :: string) }
	end
	return {
		status = "refuse",
		reason = policy.reason,
		detail = policy.refusalDetail(offending, authority),
		paths = offending,
	}
end

local function withOverride(verdict: Verdict, requested: boolean, label: string, banking: string): Verdict
	if not requested or verdict.status ~= "refuse" then
		return verdict
	end
	local refused = verdict :: Refuse
	return {
		status = "pass_override",
		bypassed = refused.reason,
		warning = ("WARNING: %s BYPASSED refusal %s -- %s"):format(
			label,
			refused.reason,
			if #refused.paths == 0 then refused.detail else table.concat(refused.paths, "; ")
		),
		banking = banking,
	}
end

return {
	sectionText = sectionText,
	withoutAsides = withoutAsides,
	pathsFromSection = pathsFromSection,
	matchedRule = matchedRule,
	parseHunks = parseHunks,
	headingIndex = headingIndex,
	headingAt = headingAt,
	sectionsTouched = sectionsTouched,
	offendingPaths = offendingPaths,
	evaluate = evaluate,
	withOverride = withOverride,
}
