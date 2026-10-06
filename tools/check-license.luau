--!strict

local fs = require("@std/fs")

local MIT_LICENSE = [[MIT License

Copyright (c) 2026 voidmeld

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local function fail(message: string): never
	error("execute license: " .. message, 0)
end

local function main()
	if not fs.exists("AGENTS.md") or not fs.exists("README.md") then
		fail("run from the Execute repository root")
	end
	if not fs.exists("LICENSE") or fs.readFileToString("LICENSE") ~= MIT_LICENSE then
		fail("LICENSE must preserve the exact MIT license and copyright notice")
	end
end

main()
print("license: MIT license checked")
