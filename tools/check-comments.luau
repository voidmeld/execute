--!strict

local fs = require("@std/fs")
local process = require("@std/process")
local parser = require("@std/syntax/parser")
local visitor = require("@std/syntax/visitor")
local syntax = require("@std/syntax")

local function comments(source: string): { { text: string, line: number } }
	local parsed = (parser.parse(source) :: unknown) :: { root: syntax.CstStatBlock, eof: syntax.CstToken<string> }
	local found = {}
	local walk = visitor.create()
	walk.visitToken = function(token)
		local view = (token :: unknown) :: {
			leadingTrivia: { { tag: string, text: string, location: { beginLine: number } } },
			trailingTrivia: { { tag: string, text: string, location: { beginLine: number } } },
		}
		for _, trivia in { view.leadingTrivia, view.trailingTrivia } do
			for _, item in trivia do
				if item.tag == "whitespace" then
					continue
				end
				local directive = string.match(item.text, "^%-%-![%a]+")
					or string.match(item.text, "^%-%-%s*lute%-lint%-")
					or string.match(item.text, "^%-%-#%s*selene")
				local license = string.find(item.text, "Copyright", 1, true)
					and string.find(item.text, "Permission is hereby granted", 1, true)
				if not directive and not license then
					table.insert(found, { text = item.text, line = item.location.beginLine })
				end
			end
		end
		return true
	end
	visitor.visit(parsed.root, walk)
	walk.visitToken(parsed.eof)
	return found
end

local function added(before: string, after: string): { number }
	local counts: { [string]: number } = {}
	for _, item in comments(before) do
		counts[item.text] = (counts[item.text] or 0) + 1
	end
	local lines = {}
	for _, item in comments(after) do
		local remaining = counts[item.text] or 0
		if remaining > 0 then
			counts[item.text] = remaining - 1
		else
			table.insert(lines, item.line)
		end
	end
	return lines
end

local function main()
	assert(#process.args == 1, "usage: check-comments.luau")

	local changed = process.run({ "git", "ls-files", "--cached", "-z", "--", "*.luau", "*.lua" })
	assert(changed.ok, changed.stderr)
	local fresh = process.run({ "git", "ls-files", "--others", "--exclude-standard", "-z", "--", "*.luau", "*.lua" })
	assert(fresh.ok, fresh.stderr)
	local failures = 0
	local seen: { [string]: boolean } = {}
	for path in string.gmatch(changed.stdout .. fresh.stdout, "[^%z]+") do
		if seen[path] or not fs.exists(path) then
			continue
		end
		seen[path] = true
		local before = ""
		for _, line in added(before, fs.readFileToString(path)) do
			print(
				("%s:%d: remove code comment; keep only tool directives and required license notices"):format(
					path,
					line
				)
			)
			failures += 1
		end
	end
	assert(failures == 0, ("check-comments: %d code comments"):format(failures))
	print("check-comments: PASS no code comments")
end

if string.match(process.args[1] or "", "([^/]+)$") == "check-comments.luau" then
	main()
end

return { added = added }
