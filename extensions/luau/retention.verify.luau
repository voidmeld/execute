--!strict

local Retention = require("./retention")
local Verify = require("../../.lute/dependencies/verify/src/core")

local function row(path: string, group: string, rank: number, retained: boolean, terminal: boolean): Retention.Row
	return { path = path, group = group, rank = rank, retained = retained, terminal = terminal, detail = "" }
end

local FAMILIES: { Retention.Family } = {
	{
		category = "runs",
		kind = "newest-per-group",
		supersededReason = "superseded",
		nonTerminalReason = "stale",
		rows = { row("runs/z.json", "one", 1, true, true), row("runs/a.json", "one", 2, true, true) },
	},
	{
		category = "journal",
		kind = "retained-terminal",
		supersededReason = "superseded_attempt",
		nonTerminalReason = "stale_nonterminal_attempt",
		rows = { row("journal/m.json", "target", 0, false, true) },
	},
}

return function(suite: Verify.Harness)
	suite:case("keeps the newest record per group", function(context)
		local deletions = Retention.newestPerGroup("runs", "superseded", {
			row("runs/a-v1.json", "place:green", 1, true, true),
			row("runs/a-v3.json", "place:green", 3, true, true),
			row("runs/a-v2.json", "place:green", 2, true, true),
			row("runs/b-v1.json", "place:red", 1, true, true),
		})
		context:expect(#deletions):toBe(2)
		local paths: { [string]: boolean } = {}
		for _, deletion in deletions do
			paths[deletion.path] = true
			context:expect(deletion.category):toBe("runs")
			context:expect(deletion.reason):toContain("retained=runs/a-v3.json")
		end
		context:expect(paths["runs/a-v1.json"]):toBeTruthy()
		context:expect(paths["runs/a-v2.json"]):toBeTruthy()
		context:expect(paths["runs/a-v3.json"]):toBeFalsy()
		context:expect(paths["runs/b-v1.json"]):toBeFalsy()
	end)

	suite:case("breaks rank ties deterministically", function(context)
		local deletions = Retention.newestPerGroup("runs", "superseded", {
			row("runs/a.json", "one", 5, true, true),
			row("runs/b.json", "one", 5, true, true),
		})
		context:expect(#deletions):toBe(1)
		context:expect(deletions[1].path):toBe("runs/a.json")
	end)

	suite:case("keeps a solitary record", function(context)
		local deletions =
			Retention.newestPerGroup("runs", "superseded", { row("runs/solo.json", "one", 1, true, true) })
		context:expect(#deletions):toBe(0)
	end)

	suite:case("deletes superseded and stale nonterminal records", function(context)
		local deletions = Retention.retainedTerminal("journal", "superseded_attempt", "stale_nonterminal_attempt", {
			row("journal/kept.json", "target", 0, true, true),
			row("journal/superseded.json", "target", 0, false, true),
			row("journal/open.json", "target", 0, true, false),
		})
		context:expect(#deletions):toBe(2)
		local reasons: { [string]: string } = {}
		for _, deletion in deletions do
			reasons[deletion.path] = deletion.reason
		end
		context:expect(reasons["journal/superseded.json"]):toContain("superseded_attempt")
		context:expect(reasons["journal/open.json"]):toContain("stale_nonterminal_attempt")
		context:expect(reasons["journal/kept.json"]):toBeNil()
	end)

	suite:case("plans deletions across families in path order", function(context)
		local deletions = Retention.plan(FAMILIES)
		context:expect(#deletions):toBe(2)
		context:expect(deletions[1].path):toBe("journal/m.json")
		context:expect(deletions[2].path):toBe("runs/z.json")
	end)

	suite:case("plans without removing", function(context)
		local outcome = Retention.run("plan", FAMILIES, function(): Retention.CommandResult
			error("plan must not remove anything")
		end)
		context:expect(outcome.ok):toBeTruthy()
		context:expect(#outcome.deletions):toBe(2)
	end)

	suite:case("checks without removing", function(context)
		local outcome = Retention.run("check", FAMILIES, function(): Retention.CommandResult
			error("check must not remove anything")
		end)
		context:expect(outcome.ok):toBeFalsy()
		context
			:expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason)
			:toBe("retention_violation")
	end)

	suite:case("passes the check of an empty plan", function(context)
		local outcome = Retention.run("check", {}, function(): Retention.CommandResult
			error("check must not remove anything")
		end)
		context:expect(outcome.ok):toBeTruthy()
		context:expect(#outcome.deletions):toBe(0)
	end)

	suite:case("applies the plan through the injected remove", function(context)
		local removed: { string }? = nil
		local outcome = Retention.run("apply", FAMILIES, function(paths: { string }): Retention.CommandResult
			removed = paths
			return { exitcode = 0, stdout = "", stderr = "" }
		end)
		context:expect(outcome.ok):toBeTruthy()
		context:expect(removed):toBeTruthy()
		context:expect(#(removed :: { string })):toBe(2)
		context:expect((removed :: { string })[1]):toBe("journal/m.json")
	end)

	suite:case("reports a failed removal", function(context)
		local outcome = Retention.run("apply", FAMILIES, function(): Retention.CommandResult
			return { exitcode = 128, stdout = "", stderr = "failed" }
		end)
		context:expect(outcome.ok):toBeFalsy()
		context
			:expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason)
			:toBe("remove_failed:128")
	end)

	suite:case("does not remove for an empty plan", function(context)
		local calls = 0
		local outcome = Retention.run("apply", {}, function(): Retention.CommandResult
			calls += 1
			return { exitcode = 0, stdout = "", stderr = "" }
		end)
		context:expect(outcome.ok):toBeTruthy()
		context:expect(calls):toBe(0)
	end)

	suite:case("refuses an unknown mode", function(context)
		local outcome = Retention.run("nonsense", FAMILIES, function(): Retention.CommandResult
			error("unknown mode must not remove anything")
		end)
		context:expect(outcome.ok):toBeFalsy()
		context
			:expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason)
			:toBe("usage")
	end)

	suite:case("takes reason labels from the family data", function(context)
		local deletions = Retention.plan({
			{
				category = "gallery",
				kind = "retained-terminal",
				supersededReason = "superseded_gallery",
				nonTerminalReason = "stale_gallery",
				rows = { row("gallery/old.json", "quality", 0, false, true) },
			},
		})
		context:expect(#deletions):toBe(1)
		context:expect(deletions[1].reason):toContain("superseded_gallery group=quality")
	end)
end
