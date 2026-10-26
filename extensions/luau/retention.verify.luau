--!strict

local Retention = require("./retention")
local Verify = require("../../.lute/dependencies/verify/src/core")
local Bdd = require("../../.lute/dependencies/verify/src/bdd")

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
	local test = Bdd.create(suite)
	local describe, it, expect = test.describe, test.it, test.expect

	describe("retention", function()
		it("keeps the newest record per group", function()
			local deletions = Retention.newestPerGroup("runs", "superseded", {
				row("runs/a-v1.json", "place:green", 1, true, true),
				row("runs/a-v3.json", "place:green", 3, true, true),
				row("runs/a-v2.json", "place:green", 2, true, true),
				row("runs/b-v1.json", "place:red", 1, true, true),
			})
			expect(#deletions):toBe(2)
			local paths: { [string]: boolean } = {}
			for _, deletion in deletions do
				paths[deletion.path] = true
				expect(deletion.category):toBe("runs")
				expect(deletion.reason):toContain("retained=runs/a-v3.json")
			end
			expect(paths["runs/a-v1.json"]):toBeTruthy()
			expect(paths["runs/a-v2.json"]):toBeTruthy()
			expect(paths["runs/a-v3.json"]):toBeFalsy()
			expect(paths["runs/b-v1.json"]):toBeFalsy()
		end)

		it("breaks rank ties deterministically", function()
			local deletions = Retention.newestPerGroup("runs", "superseded", {
				row("runs/a.json", "one", 5, true, true),
				row("runs/b.json", "one", 5, true, true),
			})
			expect(#deletions):toBe(1)
			expect(deletions[1].path):toBe("runs/a.json")
		end)

		it("keeps a solitary record", function()
			local deletions =
				Retention.newestPerGroup("runs", "superseded", { row("runs/solo.json", "one", 1, true, true) })
			expect(#deletions):toBe(0)
		end)

		it("deletes superseded and stale nonterminal records", function()
			local supersededOpen = row("journal/superseded-open.json", "target", 0, false, false)
			supersededOpen.detail = " receipt=original"
			local deletions = Retention.retainedTerminal("journal", "superseded_attempt", "stale_nonterminal_attempt", {
				row("journal/kept.json", "target", 0, true, true),
				row("journal/superseded.json", "target", 0, false, true),
				row("journal/open.json", "target", 0, true, false),
				supersededOpen,
			})
			expect(#deletions):toBe(3)
			local reasons: { [string]: string } = {}
			for _, deletion in deletions do
				reasons[deletion.path] = deletion.reason
			end
			expect(reasons["journal/superseded.json"]):toContain("superseded_attempt")
			expect(reasons["journal/open.json"]):toContain("stale_nonterminal_attempt")
			expect(reasons["journal/superseded-open.json"]):toBe("superseded_attempt group=target receipt=original")
			expect(reasons["journal/kept.json"]):toBeNil()
		end)

		it("plans deletions across families in path order", function()
			local deletions = Retention.plan(FAMILIES)
			expect(#deletions):toBe(2)
			expect(deletions[1].path):toBe("journal/m.json")
			expect(deletions[2].path):toBe("runs/z.json")
		end)

		it("plans without removing", function()
			local outcome = Retention.run("plan", FAMILIES, function(): Retention.CommandResult
				error("plan must not remove anything")
			end)
			expect(outcome.ok):toBeTruthy()
			expect(#outcome.deletions):toBe(2)
		end)

		it("checks without removing", function()
			local outcome = Retention.run("check", FAMILIES, function(): Retention.CommandResult
				error("check must not remove anything")
			end)
			expect(outcome.ok):toBeFalsy()
			expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason):toBe(
				"retention_violation"
			)
		end)

		it("passes the check of an empty plan", function()
			local outcome = Retention.run("check", {}, function(): Retention.CommandResult
				error("check must not remove anything")
			end)
			expect(outcome.ok):toBeTruthy()
			expect(#outcome.deletions):toBe(0)
		end)

		it("applies the plan through the injected remove", function()
			local removed: { string }? = nil
			local outcome = Retention.run("apply", FAMILIES, function(paths: { string }): Retention.CommandResult
				removed = paths
				return { exitcode = 0, stdout = "", stderr = "" }
			end)
			expect(outcome.ok):toBeTruthy()
			expect(removed):toBeTruthy()
			expect(#(removed :: { string })):toBe(2)
			expect((removed :: { string })[1]):toBe("journal/m.json")
		end)

		it("reports a failed removal", function()
			local outcome = Retention.run("apply", FAMILIES, function(): Retention.CommandResult
				return { exitcode = 128, stdout = "", stderr = "failed" }
			end)
			expect(outcome.ok):toBeFalsy()
			expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason):toBe(
				"remove_failed:128"
			)
		end)

		it("does not remove for an empty plan", function()
			local calls = 0
			local outcome = Retention.run("apply", {}, function(): Retention.CommandResult
				calls += 1
				return { exitcode = 0, stdout = "", stderr = "" }
			end)
			expect(outcome.ok):toBeTruthy()
			expect(calls):toBe(0)
		end)

		it("refuses an unknown mode", function()
			local outcome = Retention.run("nonsense", FAMILIES, function(): Retention.CommandResult
				error("unknown mode must not remove anything")
			end)
			expect(outcome.ok):toBeFalsy()
			expect((outcome :: { ok: false, reason: string, deletions: { Retention.Deletion } }).reason):toBe("usage")
		end)

		it("takes reason labels from the family data", function()
			local deletions = Retention.plan({
				{
					category = "gallery",
					kind = "retained-terminal",
					supersededReason = "superseded_gallery",
					nonTerminalReason = "stale_gallery",
					rows = { row("gallery/old.json", "quality", 0, false, true) },
				},
			})
			expect(#deletions):toBe(1)
			expect(deletions[1].reason):toContain("superseded_gallery group=quality")
		end)
	end)
end
