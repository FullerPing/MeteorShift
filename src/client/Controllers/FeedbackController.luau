--!strict
-- Sound and effect feedback for the game's events, in one place: refinery deposits and
-- collections, upgrades, gear evolutions, level ups, pet moments, bonuses, refusals, a full
-- backpack, menus opening and closing, and tutorial steps. The HUD keeps the toasts; this
-- adds what you hear and the burst around your character (client/RewardFX).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)

local player = Players.LocalPlayer
local colors = Config.RewardFX.Colors

local FeedbackController = Knit.CreateController({ Name = "FeedbackController" })

-- The menus whose opening and closing swoosh (player attributes set by each menu)
local MENU_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "OreFieldsOpen", "OfferPreviewOpen", "SettingsOpen", "RefineryOpen", "BackpackOpen", "QuestsOpen" }

function FeedbackController:KnitStart()
	local RefineryService = Knit.GetService("RefineryService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local ShopService = Knit.GetService("ShopService")
	local PetService = Knit.GetService("PetService")
	local LevelService = Knit.GetService("LevelService")
	local RewardService = Knit.GetService("RewardService")
	local IndexService = Knit.GetService("IndexService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local TutorialService = Knit.GetService("TutorialService")

	RefineryService.Deposited:Connect(function()
		Sfx.play("Deposit")
	end)
	RefineryService.Collected:Connect(function()
		Sfx.play("Collect")
		Sfx.play("CollectCoins")
		RewardFX.burst(colors.Evolve, 0.6)
	end)
	UpgradeService.Upgraded:Connect(function()
		Sfx.play("Upgrade")
		RewardFX.burst(colors.Upgrade)
	end)
	ShopService.Upgraded:Connect(function()
		Sfx.play("Upgrade")
		RewardFX.burst(colors.Upgrade)
	end)
	ShopService.Purchased:Connect(function()
		Sfx.play("Evolve") -- one short sting (Config.Sounds FadeAfter), no riser under it
		RewardFX.pillar(colors.Evolve)
	end)
	LevelService.LevelUp:Connect(function()
		Sfx.play("LevelUp")
		RewardFX.pillar(colors.LevelUp, 0.85)
		RewardFX.popText("LEVEL UP!", colors.LevelUp)
	end)
	PetService.Leveled:Connect(function()
		Sfx.play("PetChime")
		RewardFX.burst(colors.Pet, 0.7)
	end)
	PetService.Bought:Connect(function()
		Sfx.play("RevealRare")
		RewardFX.burst(colors.Pet)
	end)
	IndexService.Discovered:Connect(function()
		Sfx.play("PetChime", nil, nil, 1.15)
	end)
	RewardService.Bonus:Connect(function()
		Sfx.play("Bonus")
		RewardFX.burst(colors.Bonus, 0.8)
	end)
	PlayerStateService.BackpackFull:Connect(function()
		if Sfx.play("BackpackFull") then
			RewardFX.popText("FULL!", colors.Full)
		end
	end)
	-- Refusals ("Need $X", "Move closer", "already at max") get a soft deny
	for _, name in { "RefineryService", "UpgradeService", "ShopService", "PetService", "EconomyService", "PerkService", "WorldService" } do
		local ok, service = pcall(function() return Knit.GetService(name) end)
		if ok and service and service.Notice then
			service.Notice:Connect(function() Sfx.play("Deny") end)
		end
	end

	-- Menus: a swoosh in when one opens, a softer one out when it closes
	for _, flag in MENU_FLAGS do
		local was = player:GetAttribute(flag) == true
		player:GetAttributeChangedSignal(flag):Connect(function()
			local now = player:GetAttribute(flag) == true
			if now == was then return end
			was = now
			Sfx.play(if now then "MenuOpen" else "MenuClose")
		end)
	end

	-- Tutorial: a gentle ding and a word of praise over your head each time a step completes
	local PRAISE = { "NICE!", "GREAT!", "AWESOME!", "SUPER!", "WOW!" }
	local lastStep: number? = nil
	TutorialService.Step:Observe(function(step)
		local index = if typeof(step) == "table" then step.index else nil
		if lastStep and (index == nil or index > lastStep) then
			Sfx.play("TutorialStep")
			RewardFX.burst(colors.LevelUp, 0.5)
			RewardFX.popText(if index == nil then "ALL DONE!" else PRAISE[(lastStep - 1) % #PRAISE + 1], colors.LevelUp)
		end
		lastStep = index
	end)
end

return FeedbackController
