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
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local player = Players.LocalPlayer
local PerksController = Knit.CreateController({ Name = "PerksController" })

-- What a perk does at `value`, for its card text
local function effectText(id: string, value: number): string
	if id == "stationMemory" or id == "efficientLine" or id == "critChance" or id == "critPower" or id == "fieldExpert" or id == "shardSense" then
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end
	return tostring(value)
end

function PerksController:KnitStart()
	local PerkService = Knit.GetService("PerkService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.getFresh("ColonyPerks", PerksMenu.build, PerksMenu.LAYOUT)
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitCentred(panel, PerksMenu.SIZE)
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local wallet = panel:WaitForChild("Wallet") :: TextLabel
	local footer = panel:WaitForChild("Footer") :: TextLabel
	local back = panel:WaitForChild("Back") :: TextButton
	local function tint(color: Color3, text: string): string
		return string.format("<font color=\"#%s\">%s</font>", color:ToHex(), text)
	end
	local state: any = nil
	local busy: string? = nil

	local function update()
		local owned = if state then state.perks else nil
		local unlocked = state ~= nil and PerksRules.unlocked(state.rebirths)
		wallet.Text = if state then Format.number(state.shards) else "..."
		footer.Text = if unlocked then "" else string.format("Opens at rebirth %d.", Config.Perks.UnlockRebirths)
		for _, id in Config.Perks.Order do
			local def = Config.Perks.List[id]
			local card = body:FindFirstChild(id .. "Row") :: Frame?
			if card then
				local level = PerksRules.level(owned, id)
				local max = PerksRules.maxLevel(id)
				local cost = PerksRules.nextCost(owned, id)
				-- a dot per level, lime once bought
				local dots = card:FindFirstChild("Dots")
				for step = 1, max do
					local dot = dots and dots:FindFirstChild("Dot" .. step) :: Frame?
					if dot then dot.BackgroundColor3 = if step <= level then Palette.LIME_BOTTOM else Palette.BAR_TRACK end
				end
				-- what it does: now -> next (only next before the first level, only now at the top)
				local now = if level > 0 then effectText(id, def.Effect[level]) else nil
				local nextUp = if level < max then effectText(id, def.Effect[level + 1]) else nil
				local shown = if now and nextUp then tint(Palette.SECOND, now) .. " " .. tint(Palette.UP, "→ " .. nextUp)
					elseif nextUp then tint(Palette.UP, nextUp) else tint(Palette.UP, now or "")
				local line = string.format(def.Text, shown)
				if cost and state and state.shards < cost and unlocked then
					line ..= "\n" .. tint(Palette.UNMET, Format.number(cost - state.shards) .. " more shards needed")
				end
				;(card:FindFirstChild("Text") :: TextLabel).Text = line
				-- the button carries the price in shards; grey while you cannot buy it
				local buy = card:FindFirstChild("Buy") :: TextButton
				local enabled = unlocked and cost ~= nil and state ~= nil and state.shards >= cost and busy == nil
				MenuTheme.state(buy, enabled, "lime")
				buy.Text = if not cost then "MAX" elseif busy == id then "..." else Format.number(cost)
				local icon = buy:FindFirstChild("Face") and (buy :: any).Face:FindFirstChild("Icon")
				if icon then icon.Visible = cost ~= nil end
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
	-- back to the Rebirth panel this menu opens from
	back.Activated:Connect(function()
		player:SetAttribute("PerksOpen", false)
		Knit.GetController("RebirthController"):Open()
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
		local rebirthGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Rebirth", math.huge) -- slow devices: no 5 s warning
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
