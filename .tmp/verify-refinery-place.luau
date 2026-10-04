local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local basePath = ".tmp/refinery-native-baseline.rbxl"
local targetPath = assert(process.args[1], "Pass the native-saved HUD place path")
local baseBytes = fs.readFile(basePath)
local base = roblox.deserializePlace(baseBytes)
local saved = roblox.deserializePlace(fs.readFile(targetPath))
local expected = roblox.deserializePlace(fs.readFile(".tmp/refinery-source-build.rbxl"))
local report = { base = basePath, target = targetPath, baseSha256 = serde.hash("sha256", baseBytes), targetSha256 = serde.hash("sha256", fs.readFile(targetPath)), sources = {}, preservation = {}, errors = {} }

local function get(root, path)
	local item = root
	for _, name in path do
		item = item and item:FindFirstChild(name)
	end
	return item
end

local function paths(root)
	local result = {}
	local function walk(item, key)
		result[key] = item
		local duplicates = {}
		for _, child in item:GetChildren() do
			local label = child.Name .. ":" .. child.ClassName
			duplicates[label] = (duplicates[label] or 0) + 1
			walk(child, key .. "/" .. label .. "#" .. duplicates[label])
		end
	end
	walk(root, "")
	return result
end

local sourceCount = 0
-- Rojo normalizes CRLF on import; the Source-only patch retains disk bytes.
-- Compare the build with only that newline conversion applied. The patcher's
-- separate raw checks still require every replacement to match disk exactly.
local function buildSource(source)
	return (source:gsub("\r\n", "\n"))
end
for _, path in {
	{"ReplicatedStorage", "Shared"},
	{"ServerScriptService", "Server"},
	{"ServerStorage", "Tests"},
	{"StarterPlayer", "StarterPlayerScripts", "Client"},
} do
	local label = table.concat(path, "/")
	local actualRoot = get(saved, path)
	local desiredRoot = assert(get(expected, path), "Missing build mapping " .. label)
	assert(actualRoot, "Missing saved source mapping " .. label)
	local actual = paths(actualRoot)
	local desired = paths(desiredRoot)
	local matched = 0
	for key, wanted in desired do
		if wanted:IsA("LuaSourceContainer") and wanted.Name ~= "BarSaleRuntimeQA" then
			local got = actual[key]
			if not got or got.ClassName ~= wanted.ClassName or buildSource(got.Source) ~= buildSource(wanted.Source) then
				table.insert(report.errors, "Source mismatch: " .. label .. key)
			else
				matched += 1
				sourceCount += 1
			end
		end
	end
	for key, got in actual do
		if got:IsA("LuaSourceContainer") and (not desired[key] or got.Name == "BarSaleRuntimeQA") then
			table.insert(report.errors, "Unexpected saved source: " .. label .. key)
		end
	end
	report.sources[label] = matched
end
report.sourceCount = sourceCount

for _, path in {
	{"Workspace", "Map"},
	{"ReplicatedStorage", "Packages"},
	{"ServerStorage", "Assets"},
	{"ServerStorage", "ArtImports"},
	{"StarterPack"},
	{"Lighting"},
} do
	local label = table.concat(path, "/")
	local original, current = get(base, path), get(saved, path)
	if original then
		assert(current, "Missing preserved subtree " .. label)
		local originalModel = roblox.serializeModel({ original })
		local savedModel = roblox.serializeModel({ current })
		local equal = originalModel == savedModel
		report.preservation[label] = { equal = equal, baseCount = #original:GetDescendants() + 1, targetCount = #current:GetDescendants() + 1, baseSha256 = serde.hash("sha256", originalModel), targetSha256 = serde.hash("sha256", savedModel) }
		if not equal then table.insert(report.errors, "Subtree properties changed: " .. label) end
	else
		report.preservation[label] = { present = false }
	end
end

for _, descendant in saved:GetDescendants() do
	if (descendant.Name:match("BarSaleRuntimeQA") or descendant.Name:match("Refinery.*QA") or descendant.Name:match("RefPriorityRuntimeQA") or descendant.Name:match("RefineryUIFixture")) then table.insert(report.errors, "Temporary QA script present: " .. descendant:GetFullName()) end
end
report.success = #report.errors == 0
fs.writeFile(".tmp/refinery-native-source-verification.json", serde.encode("json", report, true))
print(serde.encode("json", report, true))
assert(report.success, "Native-saved source or preservation verification failed")


