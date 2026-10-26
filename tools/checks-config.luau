--!strict

local process = require("@std/process")
local Policy = require("./checks-policy")
local Repository = require("../.lute/dependencies/verify/src/checks/repository")
local Clone = require("../.lute/dependencies/verify/src/checks/clean-clone")
local Comments = require("../.lute/dependencies/verify/src/checks/comments")
local Manifest = require("../.lute/dependencies/verify/src/checks/manifest")
local Provenance = require("../.lute/dependencies/verify/src/checks/provenance")
local Surface = require("../.lute/dependencies/verify/src/checks/surface")

local config: {
	boundary: Repository.Boundary,
	leakage: Repository.Scan,
	provenance: Provenance.Config,
	comments: Comments.Config,
	manifest: Manifest.Config,
	publicSurface: Surface.Config,
	cleanClone: Clone.Config,
	noAny: Repository.Selection,
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
			lock = "dependencies.lock.luau",
			dependencyCommand = { "lute", "run", "tools/sync-dependencies.luau", "--check" },
			root = ".",
			skip = { ".git/", "build/", "bench/results/", ".lute/" },
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
			packages = {
				{
					prefix = "CommitPolicy",
					entry = "extensions/luau/commit-policy.luau",
					load = function(): unknown
						return require("../extensions/luau/commit-policy")
					end,
				},
				{
					prefix = "GuardedSurface",
					entry = "extensions/luau/guarded-surface.luau",
					load = function(): unknown
						return require("../extensions/luau/guarded-surface")
					end,
				},
				{
					prefix = "Landing",
					entry = "extensions/luau/landing.luau",
					load = function(): unknown
						return require("../extensions/luau/landing")
					end,
				},
				{
					prefix = "Retention",
					entry = "extensions/luau/retention.luau",
					load = function(): unknown
						return require("../extensions/luau/retention")
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
			env = { VERIFY_SOURCE = tostring(process.cwd()) .. "/.lute/dependencies/verify" },
			requiredPaths = { ".lute/dependencies" },
		},
		noAny = { untracked = true },
	}

return config
