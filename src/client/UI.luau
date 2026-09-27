--!strict
-- Shared look for the Fusion UI (HUD, shop, tutorial): warm palette, thick dark
-- outlines, FredokaOne everywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Children = Fusion.Children

export type Scope = Fusion.Scope<typeof(Fusion)>

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.WHITE = Color3.fromRGB(255, 255, 255)
UI.ORANGE = Color3.fromRGB(255, 174, 52)
UI.SHARD = Color3.fromRGB(66, 190, 255)
UI.RED = Color3.fromRGB(235, 70, 70)
UI.GREEN = Color3.fromRGB(105, 240, 103)
UI.CASH = Color3.fromRGB(255, 207, 55)
UI.BAR = Color3.fromRGB(232, 171, 89)
UI.OUTLINE = Color3.fromRGB(31, 22, 19)
UI.PANEL = Color3.fromRGB(187, 137, 91)
UI.PANEL_TOP = Color3.fromRGB(221, 177, 118)
UI.PANEL_BOTTOM = Color3.fromRGB(133, 94, 64)
UI.MUTED = Color3.fromRGB(120, 98, 80)

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

-- The brown gradient card behind panels (results, while you were away, shop).
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

-- A chunky outlined button with dark text.
function UI.button(scope: Scope, props: { [any]: any })
	local base = {
		BackgroundColor3 = UI.CASH,
		AutoButtonColor = true,
		Font = UI.FONT,
		TextSize = 20,
		TextColor3 = UI.OUTLINE,
	}
	local children = props[Children]
	props[Children] = nil
	for key, value in props do
		base[key] = value
	end
	base[Children] = { UI.corner(scope, 10), UI.stroke(scope), children }
	return scope:New("TextButton")(base)
end

return UI
