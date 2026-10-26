--!strict

export type Identity = {
	name: string,
	email: string,
}

export type Rules = {
	author: Identity,
	committer: Identity,
	forbiddenTrailers: { string },
}

export type Commit = {
	sha: string,
	authorName: string,
	authorEmail: string,
	committerName: string,
	committerEmail: string,
	message: string,
}

export type Pass = { status: "pass", count: number }
export type Refuse = { status: "refuse", reason: string, detail: string }
export type Verdict = Pass | Refuse

local FIELD = string.char(31)
local RECORD = string.char(30)
local LOG_FORMAT = "%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1f%B%x1e"
local FIELD_COUNT = 6

local function trimmed(value: string): string
	return string.match(value, "^%s*(.-)%s*$") or ""
end

local function split(value: string, separator: string): { string }
	local out: { string } = {}
	local start = 1
	while true do
		local first, last = string.find(value, separator, start, true)
		if first == nil then
			table.insert(out, string.sub(value, start))
			break
		end
		table.insert(out, string.sub(value, start, (first :: number) - 1))
		start = (last :: number) + 1
	end
	return out
end

local function parseLog(output: string): ({ Commit }?, string?)
	local commits: { Commit } = {}
	for _, rawRecord in split(output, RECORD) do
		local record = trimmed(rawRecord)
		if record == "" then
			continue
		end
		local fields = split(record, FIELD)
		if #fields ~= FIELD_COUNT then
			return nil, ("commit log record carried %d fields instead of %d"):format(#fields, FIELD_COUNT)
		end
		table.insert(commits, {
			sha = fields[1],
			authorName = fields[2],
			authorEmail = fields[3],
			committerName = fields[4],
			committerEmail = fields[5],
			message = fields[6],
		})
	end
	return commits, nil
end

local function hasTrailer(message: string, trailer: string): boolean
	local normalized = "\n" .. string.lower(message)
	local pattern = "\n%s*" .. string.gsub(string.lower(trailer), "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "%s*:"
	return string.find(normalized, pattern) ~= nil
end

local function evaluate(commits: { Commit }, rules: Rules): Verdict
	if #commits == 0 then
		return { status = "refuse", reason = "candidate_commits_empty", detail = "candidate range contains no commits" }
	end
	for _, commit in commits do
		if commit.authorName ~= rules.author.name or commit.authorEmail ~= rules.author.email then
			return {
				status = "refuse",
				reason = "candidate_author_mismatch",
				detail = ("%s author is %s <%s>"):format(commit.sha, commit.authorName, commit.authorEmail),
			}
		end
		if commit.committerName ~= rules.committer.name or commit.committerEmail ~= rules.committer.email then
			return {
				status = "refuse",
				reason = "candidate_committer_mismatch",
				detail = ("%s committer is %s <%s>"):format(commit.sha, commit.committerName, commit.committerEmail),
			}
		end
		for _, trailer in rules.forbiddenTrailers do
			if hasTrailer(commit.message, trailer) then
				return {
					status = "refuse",
					reason = "candidate_forbidden_trailer",
					detail = ("%s carries a %s trailer"):format(commit.sha, trailer),
				}
			end
		end
	end
	return { status = "pass", count = #commits }
end

export type CommandResult = {
	exitcode: number,
	stdout: string,
	stderr: string,
}

export type Git = ({ string }) -> CommandResult

local function runRange(base: string, head: string, rules: Rules, git: Git): Verdict
	local result = git({ "git", "log", "--format=" .. LOG_FORMAT, base .. ".." .. head })
	if result.exitcode ~= 0 then
		return {
			status = "refuse",
			reason = "candidate_commit_log_unreadable",
			detail = ("git log %s..%s exited %d"):format(base, head, result.exitcode),
		}
	end
	local commits, parseError = parseLog(result.stdout)
	if commits == nil then
		return { status = "refuse", reason = "candidate_commit_log_malformed", detail = parseError :: string }
	end
	return evaluate(commits :: { Commit }, rules)
end

return {
	FIELD = FIELD,
	RECORD = RECORD,
	LOG_FORMAT = LOG_FORMAT,
	parseLog = parseLog,
	hasTrailer = hasTrailer,
	evaluate = evaluate,
	runRange = runRange,
}
