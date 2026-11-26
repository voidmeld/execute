--!strict

local Lanes = require("../extensions/luau/lanes")

local pending = { { name = "docs", brief = "briefs/docs.md" }, { name = "api", brief = "briefs/api.md" } }
for _, lane in Lanes.selectStarts(pending, { docs = true }, 2) do
	print("start", lane.name, lane.brief)
end

local status = Lanes.classify({ startedAt = 100, reported = false, alive = true }, 160, 60)
print("docs", status)

local function landDocs(repo: string, worktree: string, otherPids: { number }, host: Lanes.Host): string
	return Lanes.land({
		repo = repo,
		worktree = worktree,
		branch = "docs",
		main = "main",
		remote = "origin",
		setup = { "make", "setup" },
		check = { "make", "check" },
		otherPids = otherPids,
		pausePatterns = if host.polling then { "^make preview$" } else nil,
	}, host)
end

return landDocs
