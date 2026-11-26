--!strict

local Lanes = require("../extensions/luau/lanes")

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
	}, host)
end

return landDocs
