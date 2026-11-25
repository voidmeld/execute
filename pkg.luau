--!strict

return {
	package = {
		name = "voidmeld/execute",
		version = "0.2.0",
		files = {
			"/AGENTS.template.md",
			"/BACKLOG.template.md",
			"/adapters/**",
			"/docs/OPERATING.md",
			"/docs/helper-brief.md",
			"/docs/api.md",
			"/extensions/**",
			"/tools/check-links.luau",
			"/.agents/**",
			"/.claude/**",
			"/README.md",
			"/CHANGELOG.md",
			"/LICENSE",
			"!*.verify.luau",
		},
		metadata = {
			description = "A backlog, guardrails and optional Luau tools for agents working on a game.",
			license = "MIT",
			repository = "https://github.com/voidmeld/execute",
			exports = {
				CallScanner = "extensions/luau/call-scanner.luau",
				RegisterLimit = "extensions/luau/register-limit.luau",
				ScopedChecks = "extensions/luau/scoped-checks.luau",
				SilentFallbacks = "extensions/luau/silent-fallbacks.luau",
				SourceScan = "extensions/luau/source-scan.luau",
				WorkerSetup = "extensions/luau/worker-setup.luau",
			},
			commands = {
				CheckLinks = "tools/check-links.luau",
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
