--!strict
-- The ORE button: a menu tile (ExactNavButton.tile, the owner's ore icon) that opens the Ore Fields menu
-- (NativeMenus.OreFields, one card per Config.Debris.Fields) and asks DebrisService to teleport you to the field you
-- pick. Desktop places the tile in the left column under STORE (HudLayout "ore"); elsewhere it sits just above SPRINT
-- (FastWalkController places that). It hides while a menu is open, and the menu closes after a pick.
-- A field still locked to you (Shared.FieldGate) shows its rule ("LEVEL 12") on a grey pill instead of TRAVEL;
-- the server refuses it anyway.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local FieldGate = require(ReplicatedStorage.Shared.FieldGate)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.Parent.UI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local OreFieldsMenu = require(script.Parent.Parent.NativeMenus.OreFields)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)

local player = Players.LocalPlayer
local FieldTravelController = Knit.CreateController({ Name = "FieldTravelController" })

local SIZE = Config.Hud.SideButtons.Size
local GAP = Config.Hud.SideButtons.Gap
local OPEN = "OreFieldsOpen"
local PANEL_FLAGS = require(script.Parent.Parent.MenuFlags).ALL

function FieldTravelController:KnitStart()
	local DebrisService = Knit.GetService("DebrisService")
	local WorldService = Knit.GetService("WorldService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local state: any = nil
	local playerGui = player:WaitForChild("PlayerGui")
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)
	local anchor = playerGui:WaitForChild("FastWalk"):WaitForChild("FastWalkButton") :: GuiButton

	local gui = Instance.new("ScreenGui")
	gui.Name = "OreFields"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2

	-- drawn at the menu buttons' 80 x 80 and scaled to its rect, like the offer tiles
	local button = Instance.new("TextButton")
	button.Name, button.Text, button.AutoButtonColor, button.BackgroundTransparency = "OreButton", "", false, 1
	button.Size = UDim2.fromOffset(80, 80)
	ExactNavButton.tile(button, "ore", "Ore")
	local scale = Instance.new("UIScale")
	scale.Name, scale.Parent = "LayoutScale", button
	button.Parent = gui
	ExactNavButton.bind(button) -- the hover lift, press dip and name tooltip the menu tiles have

	local menu = NativeUI.getFresh("OreFieldsMenu", OreFieldsMenu.build, OreFieldsMenu.LAYOUT)
	local panel = menu:WaitForChild("Panel") :: Frame
	NativeUI.fitWhole(panel, OreFieldsMenu.SIZE)
	local list = panel:WaitForChild("Fields")

	-- mirrors DebrisService:IsFieldOpen: a map without gates (the archived v2 map) has no locked fields
	local function isOpen(field: any): boolean
		if field.Destination then return Worlds.isOpen(field.Destination, if state then state.rebirths or 0 else 0) end
		local map = WorldMap.find()
		if not (map and map:FindFirstChild("Gates")) then return true end
		return FieldGate.isOpen(field, if state then state.level or 1 else 1, if state then state.rebirths or 0 else 0)
	end
	local cards: { [any]: Frame } = {}
	for _, field in OreFieldsMenu.entries(Worlds.here().Id) do
		local card = list:WaitForChild(field.Id) :: Frame
		cards[field] = card
		;(card:WaitForChild("Travel") :: TextButton).Activated:Connect(function()
			if not isOpen(field) then
				Sfx.play("Click")
				return
			end
			player:SetAttribute(OPEN, false)
			if field.Destination then
				-- another world: the server checks the unlock, saves and teleports (WorldService)
				Sfx.play("Teleport")
				WorldService:Travel(field.Destination.Id)
				return
			end
			task.spawn(function()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local from = root and root.Position
				local ok, moved = pcall(function() return DebrisService:TravelTo(field.Id) end)
				if ok and moved then
					-- a puff where you were and one where you land
					Sfx.play("Teleport")
					if from then RewardFX.poof(from, field.Color) end
					RewardFX.poofHere(field.Color)
				end
			end)
		end)
	end

	local function paintCards()
		for field, card in cards do
			local open = isOpen(field)
			local travel = card:FindFirstChild("Travel") :: TextButton
			local lock = card:FindFirstChild("Lock") :: Frame
			travel.Visible = open
			MenuTheme.state(travel, open, "blue")
			lock.Visible = not open
			;(lock:FindFirstChild("Label") :: TextLabel).Text = if field.Destination
				then "REBIRTH " .. ((field.Destination.Unlock or {}).Rebirths or 0)
				else string.upper(FieldGate.label(field))
			card.BackgroundTransparency = if open then 0 else 0.25
		end
	end
	PlayerStateService.State:Observe(function(value)
		state = value
		paintCards()
	end)

	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		-- Config.HudEdit: "Ore" nudges it from its spot above SPRINT, and hides it
		local layout = Fusion.peek(hud)
		-- desktop gives it a tile in the left column under STORE (layout.ore); elsewhere it sits above SPRINT
		local rect = HudLayout.nudged(layout, "Ore", if layout.ore then table.clone(layout.ore) else {
			x = anchor.Position.X.Offset, y = anchor.Position.Y.Offset - SIZE - GAP, w = SIZE, h = SIZE,
		})
		button.Position = UDim2.fromOffset(rect.x, rect.y)
		scale.Scale = math.min(rect.w, rect.h) / 80
		button.Visible = not panelOpen() and not HudLayout.isHidden(layout, "Ore")
	end
	scope:Observer(hud):onChange(refresh)
	button.Activated:Connect(function()
		Sfx.play("Click")
		paintCards()
		player:SetAttribute(OPEN, true)
	end)
	player:SetAttribute(OPEN, false)
	NativeUI.bindOpen(menu, OPEN, function()
		player:SetAttribute(OPEN, false)
	end)
	anchor:GetPropertyChangedSignal("Position"):Connect(refresh)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	gui.Parent = playerGui
	refresh()
end

return FieldTravelController
