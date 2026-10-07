--!strict

local process = require("@std/process")

local synced = process.run({ "lute", "run", "tools/sync-dependencies.luau" })
if not synced.ok then
	error(synced.stdout .. synced.stderr, 0)
end

local fs = require("@std/fs")

local Gate = require("../.lute/dependencies/verify/src/gate")
local Lute = require("../.lute/dependencies/verify/src/lute")

local USAGE =
	"usage: lute run tools/gate.luau [--only producer]... [--case id]... [--file spec]... [--name text] [--rerun] [--explain id] [--list]"
local DIRECTORY = ".lute/tmp/execute-gate"
local flags: { string } = {}
for index = 2, #process.args do
	table.insert(flags, process.args[index])
end

local listed = process.run({ "git", "ls-files", "--cached", "--others", "--exclude-standard", "--", "*.luau" })
assert(listed.ok, listed.stderr)
local luauFiles: { string } = {}
for path in string.gmatch(listed.stdout, "[^\r\n]+") do
	if fs.exists(path) then
		table.insert(luauFiles, path)
	end
end
table.sort(luauFiles)

local specs = Lute.corpus.discover({
	listDir = fs.listDirectory,
	rules = {
		{ root = "extensions/luau", pattern = "%.verify%.luau$" },
		{ root = "tools", pattern = "%.verify%.luau$" },
	},
})
assert(#specs > 0, "test corpus is empty")

local analyze: { string } =
	{ "luau-lsp", "analyze", "--platform=standard", "--flag:LuauSolverV2=true", "--ignore=**/.lute/**" }
local format: { string } = { "stylua", "--check" }
local lint: { string } = { "lute", "lint" }
for _, path in luauFiles do
	table.insert(analyze, path)
	table.insert(format, path)
	table.insert(lint, path)
end

local function command(id: string, argv: { string }): Gate.ProducerDraft
	return { id = id, kind = "command", argv = argv }
end

local function script(id: string, path: string): Gate.ProducerDraft
	return command(id, { "lute", "run", path })
end

local producers: { Gate.ProducerDraft } = {
	script("license", "tools/check-license.luau"),
	script("links", "tools/check-links.luau"),
	script("type-policy", "tools/check-no-any.luau"),
	command("types", analyze),
	{
		id = "specs",
		kind = "tests",
		worker = "tools/worker.luau",
		locators = specs,
		why = "the specifications of the extension and the tools",
		deadlineSeconds = 1800,
	},
	script("comments", "tools/check-comments.luau"),
	command("format", format),
	command("lint", lint),
}
for _, path in luauFiles do
	if string.match(path, "^examples/") ~= nil then
		table.insert(producers, script("example-" .. (string.match(path, "([^/]+)%.luau$") or path), path))
	end
end

local exitCode = Lute.gate.cli({
	id = "execute-gate",
	producers = producers,
	policy = { commandDeadlineSeconds = 900, deadlineSeconds = 3600 },
}, flags, { usage = USAGE, options = { directory = DIRECTORY } })
if exitCode ~= 0 then
	process.exit(exitCode)
end
