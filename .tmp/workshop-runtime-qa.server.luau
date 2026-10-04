-- Temporary isolated Play fixture; no actual player's profile is changed.
local R, S = game.ReplicatedStorage, game.ServerStorage
local H = game:GetService("HttpService")
local Knit = require(R.Packages.Knit)
assert(Knit.OnStart():timeout(20):await())
local Refinery, State, Plot = Knit.GetService("RefineryService"), Knit.GetService("PlayerStateService"), Knit.GetService("PlotService")
local Refining = require(game.ServerScriptService.Server.Lib.Refining)
local Template = require(game.ServerScriptService.Server.Lib.ProfileTemplate)
local function copy(value) if type(value) ~= "table" then return value end; local out = {}; for k, v in value do out[k] = copy(v) end; return out end
local fixture = copy(Template)
local actor = Instance.new("Folder"); actor.Name = "WorkshopQAActor"
local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local plot = workspace.Map.Plots:GetChildren()[20]:Clone()
plot.Name = "WorkshopQAPlot"; plot:SetAttribute("PlotId", 9999); plot:SetAttribute("OwnerUserId", player.UserId)
local oldStations = plot:FindFirstChild("Stations"); if oldStations then oldStations:Destroy() end
plot:PivotTo(CFrame.new(0, 1, 600) * plot.Pad.CFrame:Inverse() * plot:GetPivot())
local stations = S.Assets.PlotStations:Clone(); stations.Name = "Stations"; stations:PivotTo(plot.Pad.CFrame * CFrame.new(0, plot.Pad.Size.Y / 2, 0)); stations.Parent = plot
plot.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
plot.Parent = workspace.Map.Plots
local result = { success = false, assertions = 0, restored = false }
local function check(condition, message) result.assertions += 1; assert(condition, message) end
local noop = { Fire = function() end }
local function isolated(fn)
	local old = { get = State.Get, stations = Plot.GetStations, replicate = State.ReplicateNow, deposited = Refinery.Client.Deposited, collected = Refinery.Client.Collected, ore = Refinery.OreDeposited, bars = Refinery.BarsCollected }
	State.Get = function(self, who) if who == actor then return fixture end; return old.get(self, who) end
	Plot.GetStations = function(self, who) if who == actor then return stations end; return old.stations(self, who) end
	State.ReplicateNow = function(self, who) if who ~= actor then old.replicate(self, who) end end
	Refinery.Client.Deposited, Refinery.Client.Collected, Refinery.OreDeposited, Refinery.BarsCollected = noop, noop, noop, noop
	local ok, value = xpcall(fn, debug.traceback)
	State.Get, Plot.GetStations, State.ReplicateNow = old.get, old.stations, old.replicate
	Refinery.Client.Deposited, Refinery.Client.Collected, Refinery.OreDeposited, Refinery.BarsCollected = old.deposited, old.collected, old.ore, old.bars
	result.restored = State.Get == old.get and Plot.GetStations == old.stations and State.ReplicateNow == old.replicate
	assert(ok, value)
	return value
end
local ok, errorMessage = xpcall(function()
	isolated(function()
		fixture.stations = { hopper = 2, conveyor = 4, refinery = 4, collector = 2 }
		fixture.backpack, fixture.hopper, fixture.bin, fixture.bars = { iron = 20, frost = 10, crystal = 5 }, {}, { iron = 2 }, {}
		check(Refinery:Deposit(actor) == 35, "deposit changed")
		check(next(fixture.backpack) == nil and stations:GetAttribute("Ore_iron") == 20, "deposit stock not published")
		check(Refinery:SetPriority(actor, { "crystal", "frost", "iron" }), "priority failed")
		check(stations:GetAttribute("ActiveOre") == "crystal", "selected ore not published")
		local made, total = Refining.run(fixture, 1)
		check(total == 8 and made.crystal == 5 and made.frost == 3, "priority refining changed")
		Refinery:RefreshPlot(actor)
		check(stations:GetAttribute("Ore_crystal") == 0 and stations:GetAttribute("Bars_crystal") == 5, "depletion attributes stale")
		check(stations:GetAttribute("ActiveOre") == "frost", "depletion fallback wrong")
		check(Refinery:Collect(actor) == 10, "collection changed")
		check(stations:GetAttribute("Bars_crystal") == 0 and fixture.bars.crystal == 5, "collection display stale")
		check(stations:GetAttribute("StationLevel_conveyor") == 4, "shared belt level missing")
		check(stations:FindFirstChild("Upgrade", true) == nil, "station upgrade prompt remains")
		Refinery:_connectStations(actor, stations)
		local prompt = stations.Hopper:FindFirstChild("ManageRefinery", true)
		check(prompt and prompt:IsA("ProximityPrompt") and prompt.ActionText == "Refining order", "hopper order prompt missing")
		check(not stations.Refinery:FindFirstChild("ManageRefinery", true), "old refinery prompt remains")
		fixture.hopper = { iron = 64, frost = 12, crystal = 3 }; fixture.bin = { iron = 8, crystal = 20 }
		fixture.stations = { hopper = 4, conveyor = 4, refinery = 4, collector = 4 }
		Refinery:RefreshPlot(actor)
	end)
	result.success = true
end, debug.traceback)
result.error = not ok and tostring(errorMessage) or nil
R:SetAttribute("WorkshopServerQAResult", H:JSONEncode(result))
assert(ok, errorMessage)
local command = Instance.new("BindableFunction"); command.Name = "WorkshopQACommand"; command.Parent = R
local function actionHandler(action)
	if action == "remove" then plot:Destroy(); actor:Destroy(); return true end
	return isolated(function()
		if action == "empty" then fixture.hopper, fixture.bin = {}, {}
		elseif action == "max" then fixture.stations = { hopper = 7, conveyor = 8, refinery = 8, collector = 7 }
		elseif action == "mixed" then fixture.hopper, fixture.bin = { iron = 64, frost = 12, crystal = 3 }, { iron = 8, crystal = 20 }
		else error("Unknown fixture action") end
		Refinery:RefreshPlot(actor)
		return true
	end)
end
command.OnInvoke = actionHandler
local remote = Instance.new("RemoteFunction"); remote.Name = "WorkshopQAAction"; remote.Parent = R
remote.OnServerInvoke = function(who, action) assert(who == player, "QA owner only"); return actionHandler(action) end
R:SetAttribute("WorkshopQAReady", true)
