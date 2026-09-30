--!strict
-- Shared look for the Fusion UI: warm frames, dark cards, chunky headings and
-- clean supporting text. Resource icons use native shapes so they load instantly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local Sfx = require(script.Parent.Sfx)

local Children = Fusion.Children

export type Scope = Fusion.Scope<typeof(Fusion)>

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.BODY_FONT = Enum.Font.GothamMedium
UI.WHITE = Color3.fromRGB(255, 255, 255)
UI.SUBTEXT = Color3.fromRGB(225, 207, 184)
UI.ORANGE = Color3.fromRGB(255, 174, 52)
UI.SHARD = Color3.fromRGB(66, 190, 255)
UI.RED = Color3.fromRGB(235, 70, 70)
UI.GREEN = Color3.fromRGB(105, 240, 103)
UI.CASH = Color3.fromRGB(255, 207, 55)
UI.BAR = Color3.fromRGB(232, 171, 89)
UI.OUTLINE = Color3.fromRGB(31, 22, 19)
UI.PANEL = Color3.fromRGB(164, 114, 76)
-- Gradient colors multiply the frame color; keep the top bright enough to read.
UI.PANEL_TOP = Color3.fromRGB(255, 246, 229)
UI.PANEL_BOTTOM = Color3.fromRGB(197, 174, 149)
UI.PANEL_DARK = Color3.fromRGB(48, 36, 31)
UI.CARD = Color3.fromRGB(73, 54, 43)
UI.DISABLED = Color3.fromRGB(99, 81, 66)
UI.MUTED = UI.DISABLED

function UI.corner(scope: Scope, radius: number)
	return scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) })
end

function UI.stroke(scope: Scope, transparency: number?)
	return scope:New("UIStroke")({
		Color = UI.OUTLINE,
		Thickness = 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.label(scope: Scope, props: { [any]: any })
	local base = {
		BackgroundTransparency = 1,
		Font = UI.FONT,
		TextColor3 = UI.WHITE,
		TextStrokeColor3 = UI.OUTLINE,
		TextStrokeTransparency = 0,
		TextScaled = false,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base)
end

-- Descriptions and secondary stats stay readable at small sizes.
function UI.body(scope: Scope, props: { [any]: any })
	local base = {
		Font = UI.BODY_FONT,
		TextSize = 14,
		TextColor3 = UI.SUBTEXT,
		TextStrokeTransparency = 1,
	}
	for key, value in props do
		base[key] = value
	end
	return UI.label(scope, base)
end

-- The warm outer frame behind panels (results, while you were away, shop).
function UI.panelFill(scope: Scope)
	return {
		UI.corner(scope, 16),
		UI.stroke(scope),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(UI.PANEL_TOP, UI.PANEL_BOTTOM),
		}),
	}
end

-- Use with BackgroundColor3 = UI.CARD for the panels' lighter inset cards.
function UI.cardFill(scope: Scope)
	return {
		UI.corner(scope, 10),
		scope:New("UIStroke")({
			Color = Color3.fromRGB(139, 105, 79),
			Thickness = 1,
			Transparency = 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(UI.WHITE, Color3.fromRGB(222, 214, 203)),
		}),
	}
end

local function iconPiece(
	scope: Scope,
	name: string,
	position: UDim2,
	size: UDim2,
	color: Color3,
	rotation: number,
	radius: number,
	children: { any }?
)
	return scope:New("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rotation,
		[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(radius, 0) }), children },
	})
end

-- A consistent badge built from crisp, scalable native shapes, not emoji.
function UI.icon(scope: Scope, kind: string, props: { [any]: any }?)
	local artwork: { any } = {}
	if kind == "cash" then
		artwork = {
			iconPiece(scope, "CoinEdge", UDim2.fromScale(0.54, 0.55), UDim2.fromScale(0.65, 0.65), Color3.fromRGB(153, 97, 28), 0, 0.5),
			iconPiece(scope, "Coin", UDim2.fromScale(0.48, 0.46), UDim2.fromScale(0.65, 0.65), UI.CASH, 0, 0.5, {
				scope:New("UIStroke")({ Color = Color3.fromRGB(255, 233, 138), Thickness = 1.5 }),
				UI.label(scope, {
					Name = "CurrencyMark",
					Size = UDim2.fromScale(1, 1),
					Text = "$",
					TextColor3 = Color3.fromRGB(145, 90, 23),
					TextStrokeTransparency = 1,
					TextScaled = true,
				}),
			}),
		}
	elseif kind == "shard" then
		artwork = {
			iconPiece(scope, "CrystalEdge", UDim2.fromScale(0.54, 0.54), UDim2.fromScale(0.45, 0.61), Color3.fromRGB(18, 100, 164), 36, 0.08),
			iconPiece(scope, "Crystal", UDim2.fromScale(0.47, 0.46), UDim2.fromScale(0.42, 0.60), UI.SHARD, 36, 0.08),
			iconPiece(scope, "CrystalFacet", UDim2.fromScale(0.42, 0.38), UDim2.fromScale(0.16, 0.39), Color3.fromRGB(162, 236, 255), 36, 0.06),
			iconPiece(scope, "CrystalSpark", UDim2.fromScale(0.79, 0.22), UDim2.fromScale(0.12, 0.12), Color3.fromRGB(219, 250, 255), 45, 0),
		}
	elseif kind == "ore" then
		artwork = {
			iconPiece(scope, "RockLeft", UDim2.fromScale(0.34, 0.61), UDim2.fromScale(0.38, 0.37), Color3.fromRGB(134, 97, 70), -20, 0.16),
			iconPiece(scope, "RockRight", UDim2.fromScale(0.67, 0.59), UDim2.fromScale(0.39, 0.40), Color3.fromRGB(159, 112, 74), 17, 0.16),
			iconPiece(scope, "RockTop", UDim2.fromScale(0.48, 0.40), UDim2.fromScale(0.44, 0.44), Color3.fromRGB(200, 146, 91), -12, 0.16),
			iconPiece(scope, "OreVein", UDim2.fromScale(0.44, 0.35), UDim2.fromScale(0.15, 0.23), Color3.fromRGB(255, 206, 118), -12, 0.06),
			iconPiece(scope, "OreFleck", UDim2.fromScale(0.67, 0.59), UDim2.fromScale(0.13, 0.11), UI.ORANGE, 17, 0.05),
		}
	elseif kind == "bar" then
		artwork = {
			iconPiece(scope, "IngotEdge", UDim2.fromScale(0.51, 0.57), UDim2.fromScale(0.72, 0.39), Color3.fromRGB(139, 85, 39), -12, 0.12),
			iconPiece(scope, "Ingot", UDim2.fromScale(0.48, 0.46), UDim2.fromScale(0.68, 0.33), UI.BAR, -12, 0.12, {
				iconPiece(scope, "IngotShine", UDim2.fromScale(0.50, 0.20), UDim2.fromScale(0.80, 0.16), Color3.fromRGB(255, 224, 166), 0, 0.1),
			}),
		}
	end
	local base: { [any]: any } = {
		Name = kind .. "Icon",
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = UI.PANEL_DARK,
		BorderSizePixel = 0,
	}
	local extraChildren = if props then props[Children] else nil
	if props then
		for key, value in props do
			if key ~= Children then
				base[key] = value
			end
		end
	end
	base[Children] = {
		UI.corner(scope, 8),
		scope:New("UIStroke")({
			Color = Color3.fromRGB(153, 116, 85),
			Transparency = 0.55,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		artwork,
		extraChildren,
	}
	return scope:New("Frame")(base)
end

-- A chunky outlined button. The neutral gradient follows reactive fill colors.
function UI.button(scope: Scope, props: { [any]: any })
	local base = {
		BackgroundColor3 = UI.CASH,
		AutoButtonColor = true,
		Font = UI.FONT,
		TextSize = 20,
		TextColor3 = UI.OUTLINE,
		BorderSizePixel = 0,
	}
	local children = props[Children]
	for key, value in props do
		if key ~= Children then
			base[key] = value
		end
	end
	base[Children] = {
		UI.corner(scope, 10),
		UI.stroke(scope),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, UI.WHITE),
				ColorSequenceKeypoint.new(0.48, Color3.fromRGB(248, 244, 233)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(224, 213, 192)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(189, 171, 144)),
			}),
		}),
		children,
	}
	local button = scope:New("TextButton")(base)
	table.insert(scope, button.Activated:Connect(function()
		Sfx.play("Click")
	end))
	return button
end


-- The HUD layout for the current screen (Shared.HudLayout): a Computed that follows the
-- camera viewport and whether this is a touch-only device (spec §10). Every controller
-- that places a HUD button or sizes a panel reads it, so the geometry lives in one place.
function UI.hud(scope: Scope): Fusion.Computed<HudLayout.Layout>
	local viewport = scope:Value(Vector2.new(1280, 720))
	local function isTouch(): boolean
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end
	local touch = scope:Value(isTouch())
	local inset = scope:Value(GuiService:GetGuiInset().Y)
	local function refreshInset()
		inset:set(GuiService:GetGuiInset().Y)
	end
	local cameraConnection: RBXScriptConnection? = nil
	local function bindCamera()
		refreshInset()
		if cameraConnection then
			cameraConnection:Disconnect()
			cameraConnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			viewport:set(camera.ViewportSize)
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				refreshInset()
				viewport:set(camera.ViewportSize)
			end)
		end
	end
	bindCamera()
	table.insert(scope, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(scope, UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
		touch:set(isTouch())
	end))
	table.insert(scope, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
		touch:set(isTouch())
	end))
	-- The top bar's height can change (rotation, a different top bar), so it is re-read whenever
	-- the viewport changes and when Roblox reports a new inset
	local insetSignal = select(2, pcall(function()
		return GuiService:GetPropertyChangedSignal("TopbarInset")
	end))
	if typeof(insetSignal) == "RBXScriptSignal" then
		table.insert(scope, insetSignal:Connect(refreshInset))
	end
	return scope:Computed(function(use)
		return HudLayout.compute(use(viewport), use(touch), use(inset))
	end)
end

-- A HUD button (SHOP, INDEX, REBIRTH, STORE): placed, sized and scaled by the layout, for
-- a ScreenGui with IgnoreGuiInset = true. `textSize` is used unless the touch row sets its
-- own. `props` are the usual UI.button props (Name, Text, colours, events, Visible).
function UI.hudButton(
	scope: Scope,
	hud: Fusion.Computed<HudLayout.Layout>,
	name: string,
	textSize: number,
	props: { [any]: any }
)
	local merged: { [any]: any } = {
		AnchorPoint = Vector2.zero,
		Position = scope:Computed(function(use)
			local rect = use(hud).buttons[name]
			return UDim2.fromOffset(rect.x, rect.y)
		end),
		Size = scope:Computed(function(use)
			local base = use(hud).buttonBase
			return UDim2.fromOffset(base.X, base.Y)
		end),
		TextSize = scope:Computed(function(use)
			return use(hud).buttonTextSize or textSize
		end),
	}
	for key, value in props do
		if key ~= Children then
			merged[key] = value
		end
	end
	merged[Children] = {
		scope:New("UIScale")({
			Scale = scope:Computed(function(use)
				return use(hud).buttonScale
			end),
		}),
		props[Children],
	}
	return UI.button(scope, merged)
end

return UI
