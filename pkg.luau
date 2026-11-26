--!strict

return {
	package = {
		name = "voidmeld/execute",
		version = "0.2.1",
		files = {
			"/AGENTS.template.md",
			"/BACKLOG.template.md",
			"/REFERENCE-SHELF.template.md",
			"/REVIEWERS-EYE.template.md",
			"/adapters/**",
			"/docs/OPERATING.md",
			"/docs/helper-brief.md",
			"/docs/expertise-lane.md",
			"/docs/api.md",
			"/extensions/**",
			"/tools/check-links.luau",
			"/tools/supervise-lanes.luau",
			"/tools/tick-lanes.luau",
			"/tools/lib/lane-process.luau",
			"/.agents/**",
			"/.claude/**",
			"/README.md",
			"/CHANGELOG.md",
			"/LICENSE",
			"!*.verify.luau",
		},
		metadata = {
			description = "A backlog, guardrails and optional Luau tools for agents improving a software project.",
			license = "MIT",
			repository = "https://github.com/voidmeld/execute",
			exports = {
				CallScanner = "extensions/luau/call-scanner.luau",
				Lanes = "extensions/luau/lanes.luau",
				RegisterLimit = "extensions/luau/register-limit.luau",
				ScopedChecks = "extensions/luau/scoped-checks.luau",
				SilentFallbacks = "extensions/luau/silent-fallbacks.luau",
				SourceScan = "extensions/luau/source-scan.luau",
				WorkerSetup = "extensions/luau/worker-setup.luau",
			},
			commands = {
				CheckLinks = "tools/check-links.luau",
				SuperviseLanes = "tools/supervise-lanes.luau",
				TickLanes = "tools/tick-lanes.luau",
			},
		},
		dev_dependencies = {
			verify = {
				sourceKind = "github",
				source = "https://github.com/voidmeld/verify",
				rev = "2e8cedeb260dd61d29b6f4be51a5fc250254e80b",
			},
		},
	},
}
