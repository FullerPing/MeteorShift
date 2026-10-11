--!strict
-- The first-join "How to play" intro: a few one-idea pages (Config.Intro) in a card over a
-- dimmed screen, shown once after the loading screen and before the hands-on tutorial.
-- TutorialService says whether it is due (Shared.Intro) and is told when it closes. While it
-- is open the player attribute IntroOpen is true, which keeps the tutorial's card and
-- guide hidden so nothing points at the world behind it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)
local Sfx = require(script.Parent.Parent.Sfx)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer
local Pages = Config.Intro.Pages

local IntroController = Knit.CreateController({ Name = "IntroController" })

local CARD_W, CARD_H = 520, 330
local DOT_ON, DOT_OFF = Color3.fromRGB(255, 160, 40), Color3.fromRGB(176, 196, 226)

function IntroController:KnitStart()
	local TutorialService = Knit.GetService("TutorialService")
	player:SetAttribute("IntroOpen", false)

	local scope = Fusion.scoped(Fusion)
	local page = scope:Value(1)
	local open = scope:Value(false)
	local viewport = scope:Value(Vector2.new(1280, 720))
	local camera = workspace.CurrentCamera
	if camera then
		viewport:set(camera.ViewportSize)
		table.insert(scope, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			viewport:set(camera.ViewportSize)
		end))
	end

	local function close()
		if not Fusion.peek(open) then return end
		open:set(false)
		player:SetAttribute("IntroOpen", false)
		task.spawn(function() TutorialService:IntroDone() end)
	end
	local function go(delta: number)
		local nextPage = Fusion.peek(page) + delta
		if nextPage > #Pages then
			close()
		elseif nextPage >= 1 then
			page:set(nextPage)
		end
	end

	local current = scope:Computed(function(use) return Pages[use(page)] end)
	local isLast = scope:Computed(function(use) return use(page) == #Pages end)

	local function pill(name: string, kind: string, position: UDim2, size: UDim2, text: Fusion.UsedAs<string>, onClick: () -> (), visible: Fusion.UsedAs<boolean>?)
		return scope:New("TextButton")({
			Name = name, Position = position, Size = size, Text = "", AutoButtonColor = false,
			BackgroundTransparency = 1, Visible = visible or true, ZIndex = 3,
			[OnEvent("Activated")] = function()
				Sfx.play("Click")
				onClick()
			end,
			[Children] = {
				Cartoon.surface(kind, { radius = 14, edge = 3, lip = 4, zIndex = 3 }),
				UI.hudText(scope, {
					Size = UDim2.fromScale(1, 1), Text = text, TextSize = 24, ZIndex = 4,
					TextStrokeTransparency = 0, TextColor3 = UI.WHITE,
				}),
			},
		})
	end

	local dots = {}
	for index = 1, #Pages do
		table.insert(dots, scope:New("Frame")({
			Name = "Dot" .. index, Size = UDim2.fromOffset(12, 12), LayoutOrder = index, BorderSizePixel = 0,
			BackgroundColor3 = scope:Computed(function(use) return if use(page) == index then DOT_ON else DOT_OFF end),
			ZIndex = 3,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				scope:New("UIStroke")({ Color = Cartoon.INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			},
		}))
	end

	scope:New("ScreenGui")({
		Name = "Intro", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = open,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			scope:New("TextButton")({
				Name = "Dim", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false, Active = true,
				BackgroundColor3 = Color3.fromRGB(8, 14, 32), BackgroundTransparency = 0.35, BorderSizePixel = 0,
			}),
			scope:New("Frame")({
				Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(CARD_W, CARD_H), BackgroundTransparency = 1, ZIndex = 2,
				[Children] = {
					scope:New("UIScale")({
						Scale = scope:Computed(function(use)
							local view = use(viewport)
							return math.clamp(math.min(view.X * 0.92 / CARD_W, view.Y * 0.88 / CARD_H), 0.5, 1.4)
						end),
					}),
					Cartoon.surface("white", { radius = 24, edge = 4, lip = 6, studs = 0.9, zIndex = 2 }),
					UI.hudText(scope, {
						Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22),
						Size = UDim2.fromOffset(110, 90), TextSize = 78, ZIndex = 3, TextStrokeTransparency = 1,
						Text = scope:Computed(function(use) return use(current).Icon end),
					}),
					UI.hudText(scope, {
						Name = "Title", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116),
						Size = UDim2.new(1, -60, 0, 44), TextSize = 38, ZIndex = 3, TextStrokeTransparency = 1,
						TextColor3 = Cartoon.INK_BLUE,
						Text = scope:Computed(function(use) return use(current).Title end),
					}),
					UI.hudText(scope, {
						Name = "Body", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 162),
						Size = UDim2.new(1, -80, 0, 70), TextSize = 22, ZIndex = 3, TextStrokeTransparency = 1,
						Font = UI.BODY_FONT, TextWrapped = true, TextColor3 = Cartoon.INK_SOFT,
						TextYAlignment = Enum.TextYAlignment.Top,
						Text = scope:Computed(function(use) return use(current).Body end),
					}),
					scope:New("Frame")({
						Name = "Dots", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 238),
						Size = UDim2.fromOffset(120, 14), BackgroundTransparency = 1, ZIndex = 3,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
								HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							dots,
						},
					}),
					pill("Back", "slate", UDim2.new(0, 28, 1, -62), UDim2.fromOffset(130, 46), "BACK", function() go(-1) end,
						scope:Computed(function(use) return use(page) > 1 end)),
					pill("Next", "green", UDim2.new(1, -28 - 190, 1, -62), UDim2.fromOffset(190, 46),
						scope:Computed(function(use) return if use(isLast) then "START!" else "NEXT" end), function() go(1) end),
					pill("Skip", "blue", UDim2.new(1, -16 - 84, 0, 14), UDim2.fromOffset(84, 34), "SKIP", close,
						scope:Computed(function(use) return not use(isLast) end)),
				},
			}),
		},
	})

	local function sync(due: boolean)
		if due and not Fusion.peek(open) then
			page:set(1)
			-- wait for the loading screen to finish so the intro is not shown behind it
			task.spawn(function()
				while player:GetAttribute("LoadingDone") ~= true do task.wait(0.25) end
				if TutorialService.Intro:Get() then
					open:set(true)
					player:SetAttribute("IntroOpen", true)
				end
			end)
		elseif not due and Fusion.peek(open) then
			open:set(false)
			player:SetAttribute("IntroOpen", false)
		end
	end
	TutorialService.Intro:Observe(sync)
end

return IntroController
