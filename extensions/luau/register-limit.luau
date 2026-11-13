--!strict

local SourceScan = require("./source-scan")

export type Config = {
	label: string,
	roots: { string },
	include: { string },
	exclude: { string },
	compile: (source: string) -> (),
}

local UNOPTIMIZED = "--!optimize 0\n"

local function matchesAny(name: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.match(name, pattern) ~= nil then
			return true
		end
	end
	return false
end

local function shipped(config: Config, host: SourceScan.Host): { string }
	local out: { string } = {}
	for _, path in SourceScan.collect(config.roots, host, "") do
		if matchesAny(path, config.include) and not matchesAny(path, config.exclude) then
			table.insert(out, path)
		end
	end
	table.sort(out)
	return out
end

local function check(
	files: { string },
	read: (path: string) -> string,
	config: Config,
	report: (line: string) -> ()
): number
	local failures = 0
	for _, path in files do
		local ok, problem = pcall(config.compile, UNOPTIMIZED .. read(path))
		if not ok then
			failures += 1
			local detail = string.match(tostring(problem), "^[^\n]+") or tostring(problem)
			report(config.label .. ": FAIL " .. path .. ": " .. string.gsub(detail, "^syntax error: ", ""))
		end
	end
	report(("%s: %d module(s) compiled at optimization level 0, %d refused"):format(config.label, #files, failures))
	return if failures == 0 then 0 else 1
end

return {
	UNOPTIMIZED = UNOPTIMIZED,
	shipped = shipped,
	check = check,
}
