--!strict

local ScopedChecks = require("../extensions/luau/scoped-checks")

local groups: { ScopedChecks.Group } = {
	{
		name = "docs",
		paths = { "^docs/", "%.md$" },
		specs = {},
		checks = { { "tools/gate.luau" } },
	},
	{
		name = "tools",
		paths = { "^tools/" },
		specs = { "^tools/.*%.verify%.luau$" },
		checks = { { "tools/check-no-any.luau" } },
	},
}

local changed = { "tools/check-comments.luau", "docs/STATE.md", "notes.txt" }
local candidates = { "tools/check-comments.verify.luau", "tools/other.verify.luau" }

local selection = ScopedChecks.select(changed, groups, candidates, nil)
for _, group in selection.groups do
	print("group:", group.name)
end
for _, spec in selection.specs do
	print("spec:", spec)
end
for _, check in selection.checks do
	print("check:", table.concat(check, " "))
end
for _, path in ScopedChecks.unowned(changed, groups) do
	print("unowned:", path)
end
