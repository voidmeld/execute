--!strict
local Checks = require("../.lute/dependencies/verify/src/checks")
local Config = require("./checks-config")
local Finish = require("./lib/check-result")
local process = require("@std/process")
local config = table.clone(Config.manifest)
local write = false
for index = 2, #process.args do
	assert(process.args[index] == "--write", "expected no arguments or --write")
	write = true
end
Finish(
	"test-manifest",
	Checks.testManifest({
		path = config.path,
		rules = config.rules,
		write = write,
		entries = if write then nil else require("./test-manifest"),
		format = function(path)
			local result = process.run({ "stylua", path })
			assert(result.ok, result.stderr)
		end,
	})
)
