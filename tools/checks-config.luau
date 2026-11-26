--!strict

local Policy = require("./checks-policy")
local Repository = require("@verify/src/checks/repository")
local Clone = require("@verify/src/checks/clean-clone")
local Comments = require("@verify/src/checks/comments")
local Manifest = require("@verify/src/checks/manifest")
local Provenance = require("@verify/src/checks/provenance")
local Surface = require("@verify/src/checks/surface")

local config: {
	boundary: Repository.Boundary,
	leakage: Repository.Scan,
	provenance: Provenance.Config,
	comments: Comments.Config,
	manifest: Manifest.Config,
	publicSurface: Surface.Config,
	cleanClone: Clone.Config,
	noAny: Repository.Selection,
	specStyle: Repository.Selection,
} =
	{
		boundary = {
			root = "extensions/luau",
			allowMissing = true,
			exclude = "%.verify%.luau$",
			rules = Policy.boundary,
		},
		leakage = {
			suffixes = { ".luau", ".lua", ".md", ".json", ".toml", ".txt", ".yml", ".yaml" },
			exclude = { [Policy.selfPath] = true, LICENSE = true },
			rules = Policy.leakage,
			allowedLiterals = {},
		},
		provenance = {
			forbiddenPaths = {
				"vendor",
				"third_party",
				"third-party",
				"node_modules",
				"Packages",
				"DevPackages",
				"bench/frameworks",
			},
			license = "LICENSE",
			licensePrefix = "MIT License\n",
			licenseFragments = {
				"Copyright (c) 2026 voidmeld",
				"Permission is hereby granted, free of charge, to any person obtaining a copy",
			},
			lock = "pkg.lock.luau",
			dependencyCommand = { "lute", "pkg", "install", "--locked" },
			root = ".",
			skip = { ".git/", "build/", "bench/results/", ".lute/", ".lpm/" },
			suffixes = { ".luau", ".lua", ".md", ".toml", ".json", ".yml", ".yaml", ".sh", ".py" },
			descriptors = {
				"manifest.json",
				"package.json",
				"package-lock.json",
				"wally.toml",
				"wally.lock",
				"rotriever.toml",
			},
			noticeNames = { "LICENSE", "LICENCE", "LICENSE.md", "LICENCE.md", "COPYING", "NOTICE", "NOTICE.md" },
			expectedNotices = { LICENSE = "Execute's MIT license grant" },
			scriptExceptions = {},
			forbiddenSuffixes = { ".py" },
			justifiedSuffixes = { ".sh" },
		},
		comments = {
			selection = { untracked = true, suffixes = { ".luau", ".lua" } },
			allowed = { "^%-%-![%a]+", "^%-%-%s*lute%-lint%-", "^%-%-#%s*selene" },
			licenseFragments = { "Copyright", "Permission is hereby granted" },
		},
		manifest = {
			path = "tools/test-manifest.luau",
			rules = {
				{ root = "extensions/luau", pattern = "%.verify%.luau$" },
				{ root = "tools", pattern = "%.verify%.luau$" },
			},
		},
		publicSurface = {
			docs = "docs/api.md",
			codeReferences = true,
			includeTypes = true,
			packages = {
				{
					prefix = "CallScanner",
					entry = "extensions/luau/call-scanner.luau",
					load = function(): unknown
						return require("../extensions/luau/call-scanner")
					end,
				},
				{
					prefix = "Lanes",
					entry = "extensions/luau/lanes.luau",
					load = function(): unknown
						return require("../extensions/luau/lanes")
					end,
				},
				{
					prefix = "RegisterLimit",
					entry = "extensions/luau/register-limit.luau",
					load = function(): unknown
						return require("../extensions/luau/register-limit")
					end,
				},
				{
					prefix = "ScopedChecks",
					entry = "extensions/luau/scoped-checks.luau",
					load = function(): unknown
						return require("../extensions/luau/scoped-checks")
					end,
				},
				{
					prefix = "SilentFallbacks",
					entry = "extensions/luau/silent-fallbacks.luau",
					load = function(): unknown
						return require("../extensions/luau/silent-fallbacks")
					end,
				},
				{
					prefix = "SourceScan",
					entry = "extensions/luau/source-scan.luau",
					load = function(): unknown
						return require("../extensions/luau/source-scan")
					end,
				},
				{
					prefix = "WorkerSetup",
					entry = "extensions/luau/worker-setup.luau",
					load = function(): unknown
						return require("../extensions/luau/worker-setup")
					end,
				},
			},
		},
		cleanClone = {
			prefix = "execute-clean-clone",
			command = { "lute", "run", "tools/gate.luau", "--tier", "fast" },
			requiredPaths = { "pkg.lock.luau" },
		},
		noAny = { untracked = true, exclude = { ["pkg.lock.luau"] = true } },
		specStyle = { untracked = true },
	}

return config
