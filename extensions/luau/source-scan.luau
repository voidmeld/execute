--!strict

export type Host = {
	exists: (path: string) -> boolean,
	kind: (path: string) -> string,
	children: (path: string) -> { string },
}

export type Reconciled<Hit, Entry> = { hits: { Hit }, stale: { Entry } }

local function normalize(text: string, limit: number): string
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	local collapsed = string.gsub(trimmed, "%s+", " ")
	return if #collapsed <= limit then collapsed else string.sub(collapsed, 1, limit)
end

local function inRoots(path: string, roots: { string }): boolean
	for _, root in roots do
		if path == root or string.sub(path, 1, #root + 1) == root .. "/" then
			return true
		end
	end
	return false
end

local function collect(roots: { string }, host: Host, pattern: string): { string }
	local files: { string } = {}
	local function walk(path: string)
		local kind = host.kind(path)
		if kind == "file" then
			if string.match(path, pattern) ~= nil then
				table.insert(files, path)
			end
			return
		end
		if kind ~= "dir" then
			return
		end
		local names = table.clone(host.children(path))
		table.sort(names)
		for _, name in names do
			walk(path .. "/" .. name)
		end
	end
	for _, root in roots do
		if host.exists(root) then
			walk(root)
		end
	end
	return files
end

local function reconcile<Hit, Entry>(
	hits: { Hit },
	entries: { Entry },
	hitKey: (hit: Hit) -> string,
	entryKey: (entry: Entry) -> string
): Reconciled<Hit, Entry>
	local allowed: { [string]: boolean } = {}
	for _, entry in entries do
		allowed[entryKey(entry)] = true
	end
	local open: { Hit } = {}
	local matched: { [string]: boolean } = {}
	for _, hit in hits do
		local identity = hitKey(hit)
		if allowed[identity] then
			matched[identity] = true
		else
			table.insert(open, hit)
		end
	end
	local stale: { Entry } = {}
	for _, entry in entries do
		if not matched[entryKey(entry)] then
			table.insert(stale, entry)
		end
	end
	return { hits = open, stale = stale }
end

return {
	normalize = normalize,
	inRoots = inRoots,
	collect = collect,
	reconcile = reconcile,
}
