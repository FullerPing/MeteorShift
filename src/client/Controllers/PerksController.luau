--!strict
-- Colony Perks panel (Config.Perks, Shared.Perks): shows each perk's level and the next level's price and
-- buys it with PerkService. It opens from a PERKS button on the header of the Rebirth panel (open from
-- rebirth 1). The ColonyPerks prefab comes from StarterGui when one was exported
-- (tools/build-native-ui.luau); without it the panel is built from NativeMenus.Perks when the game starts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PerksRules = require(ReplicatedStorage.Shared.Perks)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local PerksMenu = require(script.Parent.Parent.NativeMenus.Perks)
local RebirthMenu = require(script.Parent.Parent.NativeMenus.Rebirth)
local player = Players.LocalPlayer
local PerksController = Knit.CreateController({ Name = "PerksController" })

-- What a perk does at `value`, for its card text
local function effectText(id: string, value: number): string
	if id == "stationMemory" or id == "efficientLine" then
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end
	return tostring(value)
end

function PerksController:KnitStart()
	local PerkService = Knit.GetService("PerkService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui:FindFirstChild("ColonyPerks") then
		PerksMenu.build().Parent = playerGui
	end
	local gui = NativeUI.get("ColonyPerks")
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitCentred(panel, Vector2.new(430, 560))
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local wallet = panel:WaitForChild("Wallet") :: TextLabel
	local footer = panel:WaitForChild("Footer") :: TextLabel
	local state: any = nil
	local busy: string? = nil

	local function update()
		local owned = if state then state.perks else nil
		local unlocked = state ~= nil and PerksRules.unlocked(state.rebirths)
		wallet.Text = if state then Format.number(state.shards) .. " Core Shards" else "Loading..."
		footer.Text = if unlocked then "Perks are permanent and survive every rebirth." else string.format("Colony Perks open at rebirth %d.", Config.Perks.UnlockRebirths)
		for _, id in Config.Perks.Order do
			local def = Config.Perks.List[id]
			local card = body:FindFirstChild(id .. "Row") :: Frame?
			if card then
				local level = PerksRules.level(owned, id)
				local max = PerksRules.maxLevel(id)
				local cost = PerksRules.nextCost(owned, id)
				local shownEffect = def.Effect[math.min(level + 1, max)]
				;(card:FindFirstChild("Level") :: TextLabel).Text = string.format("Level %d / %d", level, max)
				;(card:FindFirstChild("Text") :: TextLabel).Text = string.format(def.Text, effectText(id, shownEffect))
				local buy = card:FindFirstChild("Buy") :: TextButton
				local enabled = unlocked and cost ~= nil and state ~= nil and state.shards >= cost and busy == nil
				NativeUI.enable(buy, enabled, NativeUI.GREEN)
				buy.Text = if not cost then "MAX" elseif busy == id then "..." else "BUY\n" .. cost .. " ◆"
			end
		end
	end

	for _, id in Config.Perks.Order do
		local card = body:WaitForChild(id .. "Row") :: Frame
		;(card:WaitForChild("Buy") :: TextButton).Activated:Connect(function()
			if busy then return end
			busy = id
			update()
			task.spawn(function()
				local ok, bought = pcall(function() return PerkService:Buy(id) end)
				if ok and bought then
					Sfx.play("Upgrade", nil, nil, 1.1)
					RewardFX.burst(Config.RewardFX.Colors.Rebirth, 0.8)
				end
				busy = nil
				update()
			end)
		end)
	end

	NativeUI.bindOpen(gui, "PerksOpen", function()
		player:SetAttribute("PerksOpen", false)
	end)
	PlayerStateService.State:Observe(function(value)
		state = value
		update()
	end)
	PerkService.Notice:Connect(function(message: string)
		HUDController:Toast(message)
	end)
	PerkService.Bought:Connect(function(perkId: string, level: number)
		local def = Config.Perks.List[perkId]
		if def then
			HUDController:Toast(def.Name .. " is now level " .. level .. "!")
		end
	end)

	-- The PERKS button sits in the Rebirth panel header, next to its close button. NativeMenus.Rebirth builds it;
	-- RebirthController swaps that panel into the saved menu and marks it, so wait for the mark.
	task.spawn(function()
		local rebirthGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Rebirth")
		-- the saved menu can carry an older mark (and an older button) until the swap
		while rebirthGui:GetAttribute("RebirthLayout") ~= RebirthMenu.LAYOUT do rebirthGui:GetAttributeChangedSignal("RebirthLayout"):Wait() end
		local button = rebirthGui:WaitForChild("Panel"):WaitForChild("PerksButton") :: TextButton
		button.Activated:Connect(function()
			player:SetAttribute("PerksOpen", true)
		end)
	end)
	update()
end

return PerksController
