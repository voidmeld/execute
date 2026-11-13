--!strict

local SourceScan = require("./source-scan")

export type Hit = {
	path: string,
	line: number,
	rule: string,
	snippet: string,
}

export type Entry = {
	path: string,
	rule: string,
	snippet: string,
	disposition: "authored" | "pending",
	reason: string,
}

export type Config = {
	label: string,
	displayFields: { string },
	bestEffortWords: { string },
	skipPaths: { string },
	teardownPaths: { string },
}

export type File = { path: string, contents: string }

export type Input = {
	config: Config,
	roots: { string },
	selected: boolean,
	entries: { Entry },
	paths: { string },
	read: (path: string) -> string,
}

local SNIPPET_LIMIT = 160

local function normalize(text: string): string
	return SourceScan.normalize(text, SNIPPET_LIMIT)
end

local function codeLines(contents: string): { { line: number, text: string } }
	local out: { { line: number, text: string } } = {}
	local inBlock = false
	local lineNumber = 0
	for raw in (contents .. "\n"):gmatch("([^\n]*)\n") do
		lineNumber += 1
		local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
		if inBlock then
			if string.find(trimmed, "]]", 1, true) ~= nil then
				inBlock = false
			end
		elseif string.sub(trimmed, 1, 4) == "--[[" then
			if string.find(trimmed, "]]", 5, true) == nil then
				inBlock = true
			end
		elseif string.sub(trimmed, 1, 2) ~= "--" and trimmed ~= "" then
			table.insert(out, { line = lineNumber, text = trimmed })
		end
	end
	return out
end

local function lookupOrLiteral(text: string): boolean
	local from = 1
	while true do
		local start, stop, index = string.find(text, '%[([^%[%]]*)%]%s*or%s*"', from)
		if start == nil or stop == nil or index == nil then
			return false
		end
		from = stop + 1
		local key = string.match(index, "^%s*(.-)%s*$") or ""
		local prefix = string.sub(text, math.max(1, start - 16), start - 1)
		local numeric = string.match(key, "^%d+$") ~= nil
		local arguments = string.match(prefix, "args$") ~= nil
		if not numeric and not arguments and key ~= "" then
			return true
		end
	end
end

local CONTINUATION_TAILS = { "=", ",", "(", "{", "and", "or", "not", "return", "then", "..", "==" }

local function continues(previous: string): boolean
	for _, tail in CONTINUATION_TAILS do
		if string.sub(previous, -#tail) == tail then
			return true
		end
	end
	return false
end

local function discardedPcall(text: string, previous: string, config: Config): boolean
	if string.sub(text, 1, 6) ~= "pcall(" then
		return false
	end
	if continues(previous) then
		return false
	end
	local callee = string.match(text, "^pcall%(([^,%)]*)") or ""
	local lowered = string.lower(callee)
	for _, word in config.bestEffortWords do
		if string.find(lowered, word, 1, true) ~= nil then
			return false
		end
	end
	return true
end

local function displayEmptyFallback(text: string, fields: { [string]: boolean }): boolean
	if string.find(text, '""', 1, true) == nil then
		return false
	end
	for field in string.gmatch(text, '([%a][%w]*)%s*=%s*[^=]-%s+or%s*""') do
		if fields[field] then
			return true
		end
	end
	return false
end

local function matchesAny(path: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.match(path, pattern) ~= nil then
			return true
		end
	end
	return false
end

local function lintFile(path: string, contents: string, config: Config): { Hit }
	local hits: { Hit } = {}
	if matchesAny(path, config.skipPaths) then
		return hits
	end
	local fields: { [string]: boolean } = {}
	for _, field in config.displayFields do
		fields[field] = true
	end
	local teardown = matchesAny(path, config.teardownPaths)
	local previous = ""
	for _, entry in codeLines(contents) do
		local found: { string } = {}
		if lookupOrLiteral(entry.text) then
			table.insert(found, "lookup-or-literal")
		end
		if not teardown and discardedPcall(entry.text, previous, config) then
			table.insert(found, "discarded-pcall")
		end
		if displayEmptyFallback(entry.text, fields) then
			table.insert(found, "display-empty-fallback")
		end
		for _, rule in found do
			table.insert(hits, { path = path, line = entry.line, rule = rule, snippet = normalize(entry.text) })
		end
		previous = entry.text
	end
	return hits
end

local function hitKey(hit: Hit): string
	return hit.path .. "\0" .. hit.rule .. "\0" .. hit.snippet
end

local function entryKey(entry: Entry): string
	return entry.path .. "\0" .. entry.rule .. "\0" .. entry.snippet
end

local function lint(files: { File }, entries: { Entry }, config: Config): ({ Hit }, { Entry })
	local found: { Hit } = {}
	for _, file in files do
		for _, hit in lintFile(file.path, file.contents, config) do
			table.insert(found, hit)
		end
	end
	local reconciled = SourceScan.reconcile(found, entries, hitKey, entryKey)
	local hits = reconciled.hits
	table.sort(hits, function(left: Hit, right: Hit): boolean
		if left.path ~= right.path then
			return left.path < right.path
		end
		if left.line ~= right.line then
			return left.line < right.line
		end
		return left.rule < right.rule
	end)
	return hits, reconciled.stale
end

local function unreasoned(entries: { Entry }): { Entry }
	local out: { Entry } = {}
	for _, entry in entries do
		local reason = string.match(entry.reason, "^%s*(.-)%s*$") or ""
		local known = entry.disposition == "authored" or entry.disposition == "pending"
		if #reason < 20 or not known then
			table.insert(out, entry)
		end
	end
	return out
end

local function pending(entries: { Entry }): { Entry }
	local out: { Entry } = {}
	for _, entry in entries do
		if entry.disposition == "pending" then
			table.insert(out, entry)
		end
	end
	return out
end

local function selectEntries(entries: { Entry }, roots: { string }, selected: boolean): { Entry }
	if not selected then
		return entries
	end
	local out: { Entry } = {}
	for _, entry in entries do
		if SourceScan.inRoots(entry.path, roots) then
			table.insert(out, entry)
		end
	end
	return out
end

local function check(input: Input, report: (line: string) -> ()): number
	local label = input.config.label
	local entries = selectEntries(input.entries, input.roots, input.selected)
	local missing = unreasoned(entries)
	if #missing > 0 then
		report(("%s: %d allowlist entry(s) carry no disposition or reason"):format(label, #missing))
		for _, entry in missing do
			report(("  %s [%s] %s"):format(entry.path, entry.rule, entry.snippet))
		end
		return 1
	end

	local files: { File } = {}
	for _, path in input.paths do
		table.insert(files, { path = path, contents = input.read(path) })
	end
	local hits, stale = lint(files, entries, input.config)
	if #stale > 0 then
		report(("%s: %d allowlist entry(s) match nothing"):format(label, #stale))
		for _, entry in stale do
			report(("  %s [%s] %s"):format(entry.path, entry.rule, entry.snippet))
		end
		return 1
	end
	if #hits > 0 then
		report(("%s: %d silent fallback(s)"):format(label, #hits))
		for _, hit in hits do
			report(("  %s:%d [%s] %s"):format(hit.path, hit.line, hit.rule, hit.snippet))
		end
		return 1
	end
	local open = pending(entries)
	for _, entry in open do
		report(("%s: pending %s [%s] %s -- %s"):format(label, entry.path, entry.rule, entry.snippet, entry.reason))
	end
	report(("%s: clean (%d root(s), %d authored, %d pending)"):format(label, #input.roots, #entries - #open, #open))
	return 0
end

return {
	normalize = normalize,
	lintFile = lintFile,
	lint = lint,
	unreasoned = unreasoned,
	pending = pending,
	selectEntries = selectEntries,
	check = check,
}
