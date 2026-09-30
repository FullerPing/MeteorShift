--!strict
-- Tiny test harness for pure logic modules (Task 1 of the improvement pass).
--
-- Why cloning: Roblox's `require` caches a module's result by ModuleScript
-- instance for the lifetime of the running place. Editing a script's Source
-- on disk (picked up by rojo serve) does NOT invalidate an existing require
-- cache for that instance, so re-running tests against the real
-- ReplicatedStorage.Shared or ServerScriptService.Server.Lib would silently
-- keep testing whatever was first required in this Studio session, not
-- what is on disk now. Requiring a *clone* of a ModuleScript is a different
-- Instance, so it is never in the cache and always re-executes its current
-- Source.
--
-- This runner clones ReplicatedStorage.Shared, ServerScriptService.Server.Lib
-- and this tests/ folder into a scratch Folder (parented under
-- ReplicatedStorage so relative `script.Parent...` lookups inside the clones
-- still land on siblings that exist), requires every "*.spec" ModuleScript
-- from the cloned tests folder, and destroys the scratch folder when done.
--
-- Lib modules (e.g. Refining) require ReplicatedStorage.Shared.Config with an
-- ABSOLUTE path (`require(ReplicatedStorage.Shared.Config)`), not a relative
-- one, so a cloned Lib.Refining still resolves Config against the real,
-- live-synced ReplicatedStorage.Shared.Config -- no reparenting is needed for
-- that particular require to work. The one caveat this leaves: if something
-- else in this Studio session already required the real Config (or another
-- Shared module reached the same way) before your last edit, that specific
-- require is still cached and won't see the edit until the session restarts
-- (stop and re-enter Edit, or reload the place). Only requires that go
-- through the clones handed to specs (`t.shared`, `t.lib`) are guaranteed
-- fresh every run.
--
-- Spec modules are ModuleScripts named "<Name>.spec" directly under tests/.
-- Each returns `function(t) ... end` and calls t.test(name, fn) once per
-- case. Inside a case, use t.eq/t.near/t.ok, and require modules from
-- t.shared / t.lib (the cloned Shared and Lib folders) rather than the real
-- ones, so the specs exercise fresh code every run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

type TestResult = {
	spec: string,
	name: string,
	ok: boolean,
	message: string?,
}

local function makeT(results: { TestResult }, specName: string)
	local t: any = {}

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			table.insert(results, { spec = specName, name = name, ok = true })
		else
			table.insert(results, { spec = specName, name = name, ok = false, message = tostring(err) })
		end
	end

	function t.eq(a: any, b: any, msg: string?)
		if a ~= b then
			error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 0)
		end
	end

	function t.near(a: number, b: number, eps: number, msg: string?)
		if math.abs(a - b) > eps then
			error(string.format("%s: expected %s +/- %s, got %s", msg or "near", tostring(b), tostring(eps), tostring(a)), 0)
		end
	end

	function t.ok(cond: any, msg: string?)
		if not cond then
			error(msg or "expected a truthy value", 0)
		end
	end

	return t
end

local function summarize(results: { TestResult }): string
	local passed = 0
	local failed: { TestResult } = {}
	for _, r in results do
		if r.ok then
			passed += 1
		else
			table.insert(failed, r)
		end
	end

	local lines = { string.format("%d passed, %d failed", passed, #failed) }
	for _, r in failed do
		table.insert(lines, string.format("%s > %s: %s", r.spec, r.name, r.message or "failed"))
	end
	return table.concat(lines, "\n")
end

return function(filter: string?): string
	local scratch = Instance.new("Folder")
	scratch.Name = "TestRunnerScratch"
	scratch.Parent = ReplicatedStorage

	local ok, resultOrErr = pcall(function()
		local sharedClone = ReplicatedStorage.Shared:Clone()
		sharedClone.Name = "Shared"
		sharedClone.Parent = scratch

		local libClone = ServerScriptService.Server.Lib:Clone()
		libClone.Name = "Lib"
		libClone.Parent = scratch

		local testsClone = script.Parent:Clone()
		testsClone.Name = "Tests"
		testsClone.Parent = scratch

		local results: { TestResult } = {}
		for _, child in testsClone:GetChildren() do
			if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") then
				local specName = child.Name
				if not filter or string.find(specName, filter, 1, true) then
					local okRequire, specFn = pcall(require, child)
					if okRequire and type(specFn) == "function" then
						local t = makeT(results, specName)
						t.shared = sharedClone
						t.lib = libClone
						local okRun, err = pcall(specFn, t)
						if not okRun then
							table.insert(results, { spec = specName, name = "(module)", ok = false, message = tostring(err) })
						end
					else
						table.insert(results, { spec = specName, name = "(require)", ok = false, message = tostring(specFn) })
					end
				end
			end
		end

		return summarize(results)
	end)

	scratch:Destroy()

	if not ok then
		return "Runner error: " .. tostring(resultOrErr)
	end
	return resultOrErr :: string
end
