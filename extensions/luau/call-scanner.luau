--!strict

export type Call = { start: number, stop: number, args: { string } }

local ESCAPES: { [string]: string } = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v" }

local function skipQuoted(source: string, index: number): number
	local quote = string.sub(source, index, index)
	local cursor = index + 1
	while cursor <= #source do
		local char = string.sub(source, cursor, cursor)
		if char == "\\" then
			cursor += 2
		elseif char == quote then
			return cursor + 1
		else
			cursor += 1
		end
	end
	return #source + 1
end

local function skipLong(source: string, index: number): number?
	local equals = string.match(source, "^%[(=*)%[", index)
	if equals == nil then
		return nil
	end
	local close = "]" .. equals .. "]"
	local found = string.find(source, close, index + #equals + 2, true)
	return if found == nil then #source + 1 else found + #close
end

local function skipComment(source: string, index: number): number
	local long = skipLong(source, index + 2)
	if long ~= nil then
		return long
	end
	local newline = string.find(source, "\n", index, true)
	return if newline == nil then #source + 1 else newline
end

local function literalBytes(body: string): number
	local count = 0
	local cursor = 1
	while cursor <= #body do
		local char = string.sub(body, cursor, cursor)
		if char ~= "\\" then
			count += 1
			cursor += 1
			continue
		end
		local nextChar = string.sub(body, cursor + 1, cursor + 1)
		local digits = string.match(body, "^%d%d?%d?", cursor + 1)
		local unicode = string.match(body, "^u{(%x+)}", cursor + 1)
		if digits ~= nil then
			count += 1
			cursor += 1 + #digits
		elseif unicode ~= nil then
			count += #utf8.char(tonumber(unicode, 16) or 0)
			cursor += 4 + #unicode
		elseif nextChar == "x" then
			count += 1
			cursor += 4
		elseif nextChar == "z" then
			cursor += 2
		else
			count += if ESCAPES[nextChar] ~= nil or nextChar ~= "" then 1 else 0
			cursor += 2
		end
	end
	return count
end

local function splitTop(text: string): { string }
	local parts: { string } = {}
	local depth = 0
	local from = 1
	local cursor = 1
	while cursor <= #text do
		local char = string.sub(text, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			cursor = skipQuoted(text, cursor)
			continue
		end
		if char == "(" or char == "[" or char == "{" then
			depth += 1
		elseif char == ")" or char == "]" or char == "}" then
			depth -= 1
		elseif char == "," and depth == 0 then
			table.insert(parts, string.sub(text, from, cursor - 1))
			from = cursor + 1
		end
		cursor += 1
	end
	table.insert(parts, string.sub(text, from))
	return parts
end

local function topLevel(expression: string): string
	local out: { string } = {}
	local depth = 0
	local cursor = 1
	while cursor <= #expression do
		local char = string.sub(expression, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			cursor = skipQuoted(expression, cursor)
			if depth == 0 then
				table.insert(out, "S")
			end
			continue
		end
		if char == "(" or char == "[" or char == "{" then
			if depth == 0 then
				table.insert(out, char)
			end
			depth += 1
		elseif char == ")" or char == "]" or char == "}" then
			depth -= 1
			if depth == 0 then
				table.insert(out, char)
			end
		elseif depth == 0 then
			table.insert(out, char)
		end
		cursor += 1
	end
	return table.concat(out)
end

local function wholeCall(expression: string, prefix: string): { string }?
	if string.sub(expression, 1, #prefix) ~= prefix then
		return nil
	end
	local depth = 0
	local cursor = #prefix
	while cursor <= #expression do
		local char = string.sub(expression, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			cursor = skipQuoted(expression, cursor)
			continue
		end
		if char == "(" then
			depth += 1
		elseif char == ")" then
			depth -= 1
			if depth == 0 then
				if cursor ~= #expression then
					return nil
				end
				return splitTop(string.sub(expression, #prefix + 1, cursor - 1))
			end
		end
		cursor += 1
	end
	return nil
end

local function functionDefinitions(source: string): { [number]: boolean }
	local positions: { [number]: boolean } = {}
	local header = false
	local named = false
	local cursor = 1
	while cursor <= #source do
		local char = string.sub(source, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			header = false
			cursor = skipQuoted(source, cursor)
		elseif char == "[" and skipLong(source, cursor) ~= nil then
			header = false
			cursor = (skipLong(source, cursor))
		elseif string.sub(source, cursor, cursor + 1) == "--" then
			cursor = skipComment(source, cursor)
		elseif string.match(char, "[%a_]") ~= nil then
			local token = string.match(source, "^[%a_][%w_]*", cursor) or ""
			if token == "function" then
				header, named = true, false
			elseif header and not named then
				named = true
			else
				header = false
			end
			cursor += #token
		else
			if header and named and (char == "." or char == ":") then
				positions[cursor] = true
				named = false
			elseif string.match(char, "%s") == nil then
				header = false
			end
			cursor += 1
		end
	end
	return positions
end

local function findCalls(source: string, needle: string): { Call }
	local calls: { Call } = {}
	local definitions = functionDefinitions(source)
	local name = string.sub(needle, 2, -2)
	local pattern = "^" .. string.sub(needle, 1, 1) .. "%s*" .. name .. "%s*%("
	if string.find(source, name, 1, true) == nil then
		return calls
	end
	local cursor = 1
	while cursor <= #source do
		local char = string.sub(source, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			cursor = skipQuoted(source, cursor)
		elseif char == "[" and skipLong(source, cursor) ~= nil then
			cursor = (skipLong(source, cursor))
		elseif char == "-" and string.sub(source, cursor, cursor + 1) == "--" then
			cursor = skipComment(source, cursor)
		elseif string.match(source, pattern, cursor) ~= nil then
			local opening = (string.match(source, pattern, cursor))
			if definitions[cursor] then
				cursor += #opening
				continue
			end
			local depth = 1
			local scan = cursor + #opening
			while scan <= #source and depth > 0 do
				local inner = string.sub(source, scan, scan)
				if inner == '"' or inner == "'" or inner == "`" then
					scan = skipQuoted(source, scan)
					continue
				end
				if inner == "(" or inner == "[" or inner == "{" then
					depth += 1
				elseif inner == ")" or inner == "]" or inner == "}" then
					depth -= 1
				end
				scan += 1
			end
			table.insert(calls, {
				start = cursor,
				stop = scan - 1,
				args = splitTop(string.sub(source, cursor + #opening, scan - 2)),
			})
			cursor = scan
		else
			cursor += 1
		end
	end
	return calls
end

local function lineOf(source: string, position: number): number
	local _, newlines = string.gsub(string.sub(source, 1, position - 1), "\n", "")
	return newlines + 1
end

local function findReferences(source: string, member: string): { number }
	local positions: { number } = {}
	local definitions = functionDefinitions(source)
	local pattern = "^%.%s*" .. member .. "%f[^%w_]"
	if string.find(source, member, 1, true) == nil then
		return positions
	end
	local cursor = 1
	while cursor <= #source do
		local char = string.sub(source, cursor, cursor)
		if char == '"' or char == "'" or char == "`" then
			cursor = skipQuoted(source, cursor)
		elseif char == "[" and skipLong(source, cursor) ~= nil then
			cursor = (skipLong(source, cursor))
		elseif char == "-" and string.sub(source, cursor, cursor + 1) == "--" then
			cursor = skipComment(source, cursor)
		elseif string.match(source, pattern, cursor) ~= nil then
			local reference = string.match(source, pattern, cursor) or ""
			local before = string.sub(source, math.max(1, cursor - 80), cursor - 1)
			local compact = string.gsub(before, "%s", "")
			local declaration = definitions[cursor] == true
				and string.match(source, "^%s*%(", cursor + #reference) ~= nil
			if
				not declaration
				and string.match(compact, "type%([%w_%.:]*$") == nil
				and string.match(compact, "typeof%([%w_%.:]*$") == nil
			then
				table.insert(positions, cursor)
			end
			cursor += #reference
		else
			cursor += 1
		end
	end
	return positions
end

return {
	skipQuoted = skipQuoted,
	skipLong = skipLong,
	skipComment = skipComment,
	literalBytes = literalBytes,
	splitTop = splitTop,
	topLevel = topLevel,
	wholeCall = wholeCall,
	functionDefinitions = functionDefinitions,
	findCalls = findCalls,
	lineOf = lineOf,
	findReferences = findReferences,
}
