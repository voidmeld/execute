--!strict

return {
	package = {
		name = "voidmeld/execute",
		version = "0.1.1",
		files = {
			"/AGENTS.template.md",
			"/adapters/**",
			"/docs/**",
			"/extensions/**",
			"/.agents/**",
			"/.claude/**",
			"/README.md",
			"/CHANGELOG.md",
			"/LICENSE",
			"!*.verify.luau",
		},
		metadata = {
			description = "Reusable project instructions and Luau workflow tools for coding agents.",
			license = "MIT",
			repository = "https://github.com/voidmeld/execute",
			exports = {
				CallScanner = "extensions/luau/call-scanner.luau",
				CommitPolicy = "extensions/luau/commit-policy.luau",
				GuardedSurface = "extensions/luau/guarded-surface.luau",
				Landing = "extensions/luau/landing.luau",
				RegisterLimit = "extensions/luau/register-limit.luau",
				Retention = "extensions/luau/retention.luau",
				ScopedChecks = "extensions/luau/scoped-checks.luau",
				SilentFallbacks = "extensions/luau/silent-fallbacks.luau",
				SourceScan = "extensions/luau/source-scan.luau",
				WorkerSetup = "extensions/luau/worker-setup.luau",
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
