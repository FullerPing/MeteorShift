--!strict
-- The touch MINE button (spec §10). On touch-only devices, while a pickaxe is in your
-- hands, a big round MINE button sits above Roblox's jump button, right edges aligned.
-- Holding it swings continuously at the pickaxe's speed at the nearest mineable target in
-- reach and in front of the character (MiningController:SetTouchHold, which uses
-- Shared.Aim). It is presentation only: every swing still goes through NodeService,
-- which checks range, swing speed and everything else on the server.
--
-- Where it goes, and how big, comes from Shared.HudLayout (Config.Hud.Mine), the same
-- place that keeps the HUD buttons clear of it. It hides while a panel is open, the
-- same flags the HUD buttons use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UI = require(script.Parent.Parent.UI)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer

local MobileControlsController = Knit.CreateController({ Name = "MobileControlsController" })

function MobileControlsController:KnitStart()
	local MiningController = Knit.GetController("MiningController")
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)

	-- A pickaxe tool is in the character's hands
	local equipped = scope:Value(false)
	local characterConnections: { RBXScriptConnection } = {}
	local function refreshEquipped()
		local has = MiningController:GetEquippedPickaxe() ~= nil
		equipped:set(has)
		if not has then
			MiningController:SetTouchHold(false)
		end
	end
	local function watchCharacter(character: Model)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)
		table.insert(characterConnections, character.ChildAdded:Connect(refreshEquipped))
		table.insert(characterConnections, character.ChildRemoved:Connect(refreshEquipped))
		refreshEquipped()
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	table.insert(scope, player.CharacterAdded:Connect(watchCharacter))

	-- Panels other controllers open on the local player
	local function playerFlag(name: string)
		local flag = scope:Value(player:GetAttribute(name) == true)
		table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function()
			flag:set(player:GetAttribute(name) == true)
		end))
		return flag
	end
	local shopOpen = playerFlag("ShopOpen")
	local indexOpen = playerFlag("IndexOpen")
	local rebirthOpen = playerFlag("RebirthOpen")
	local storeOpen = playerFlag("StoreOpen")

	local visible = scope:Computed(function(use)
		return use(hud).mine ~= nil
			and use(equipped)
			and not use(shopOpen)
			and not use(indexOpen)
			and not use(rebirthOpen)
			and not use(storeOpen)
	end)
	-- A hidden button cannot be released, so stop swinging when it goes away
	scope:Observer(visible):onChange(function()
		if not Fusion.peek(visible) then
			MiningController:SetTouchHold(false)
		end
	end)

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end

	scope:New("ScreenGui")({
		Name = "MobileControls",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			scope:New("TextButton")({
				Name = "MineButton",
				Font = UI.FONT,
				TextColor3 = UI.OUTLINE,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.zero,
				Position = scope:Computed(function(use)
					local rect = use(hud).mine
					return if rect then UDim2.fromOffset(rect.x, rect.y) else UDim2.new()
				end),
				Size = scope:Computed(function(use)
					local rect = use(hud).mine
					return if rect then UDim2.fromOffset(rect.w, rect.h) else UDim2.new()
				end),
				Text = "MINE",
				TextSize = 24,
				BackgroundColor3 = UI.ORANGE,
				AutoButtonColor = false,
				Visible = visible,
				[Children] = {
					-- Fully round, with the same outline as the other buttons
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					UI.stroke(scope),
				},
				-- Held, not tapped: Activated only fires on release
				[OnEvent("InputBegan")] = function(input: InputObject)
					if isPress(input) then
						task.spawn(function()
							MiningController:SetTouchHold(true)
						end)
					end
				end,
				[OnEvent("InputEnded")] = function(input: InputObject)
					if isPress(input) then
						MiningController:SetTouchHold(false)
					end
				end,
			}),
		},
	})
end

return MobileControlsController
