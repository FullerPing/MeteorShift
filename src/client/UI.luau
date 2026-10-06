--!strict
-- Shared simulator look: glossy cartoon HUD cards (Client.Cartoon), chunky
-- outlined text and colour-coded navigation tiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Sfx = require(script.Parent.Sfx)
local Cartoon = require(script.Parent.Cartoon)

local Children = Fusion.Children

export type Scope = Fusion.Scope<typeof(Fusion)>

local UI = {}

UI.FONT = Enum.Font.FredokaOne
UI.BODY_FONT = Enum.Font.GothamMedium
UI.WHITE = Color3.fromRGB(255, 255, 255)
UI.SUBTEXT = Color3.fromRGB(211, 228, 240)
UI.ORANGE = Color3.fromRGB(255, 174, 52)
UI.SHARD = Color3.fromRGB(66, 190, 255)
UI.RED = Color3.fromRGB(235, 70, 70)
UI.GREEN = Color3.fromRGB(105, 240, 103)
UI.CASH = Color3.fromRGB(255, 207, 55)
UI.BAR = Color3.fromRGB(232, 171, 89)
UI.OUTLINE = Color3.fromRGB(12, 18, 25)
UI.PANEL = Color3.fromRGB(43, 44, 49)
-- Gradient colors multiply the frame color; keep the top bright enough to read.
UI.PANEL_TOP = Color3.fromRGB(255, 255, 255)
UI.PANEL_BOTTOM = Color3.fromRGB(209, 209, 209)
UI.PANEL_DARK = Color3.fromRGB(29, 30, 35)
UI.CARD = Color3.fromRGB(67, 69, 77)
UI.DISABLED = Color3.fromRGB(73, 83, 94)
UI.MUTED = UI.DISABLED

-- HUD surfaces stay blue independently of the menus' charcoal palette.
UI.HUD_SURFACE = Color3.fromRGB(37, 208, 255)
UI.HUD_BORDER = UI.OUTLINE
UI.HUD_MUTED = UI.SUBTEXT
UI.HUD_GOLD = Color3.fromRGB(255, 219, 100)
UI.HUD_MINT = Color3.fromRGB(139, 240, 195)

local STUD_TEXTURE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(128, 128)

-- One tiled image per surface. Texture children stay below sibling labels/icons,
-- never receive input and retain the parent's fill color and disabled state.
local function studTexture(scope: Scope, transparency: number, radius: number)
	return scope:New("ImageLabel")({
		Name = "StudTexture", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = STUD_TEXTURE, ImageColor3 = UI.WHITE, ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Tile, TileSize = STUD_TILE_SIZE,
		ZIndex = 0, Active = false, Selectable = false,
		[Children] = { UI.corner(scope, radius) },
	})
end

-- Glossy cartoon card (Client.Cartoon): saturated gradient, thick ink outline,
-- a darker lip, gloss stripes and a faint stud texture. The parent must keep a
-- transparent background; content at ZIndex 1+ draws above the surface.
function UI.hudFill(_scope: Scope, kind: string?, options: Cartoon.SurfaceOptions?)
	local merged: Cartoon.SurfaceOptions = { studs = 0.88, studSize = 36 }
	if options then for key, value in options :: any do (merged :: any)[key] = value end end
	return { Cartoon.surface(kind or "blue", merged) }
end

function UI.hudText(scope: Scope, props: { [any]: any })
	local merged: { [any]: any } = { Font = UI.FONT, TextStrokeTransparency = 0 }
	for key, value in props do merged[key] = value end
	return UI.label(scope, merged)
end

function UI.hudIcon(scope: Scope, name: string, props: { [any]: any }?)
	local merged: { [any]: any } = {
		Name = name .. "Icon", BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = HudIcons[name], ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(32, 32),
	}
	if props then for key, value in props do merged[key] = value end end
	return scope:New("ImageLabel")(merged)
end

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

-- Text gets the chunky cartoon outline: a rounded UIStroke replaces the thin
-- engine text stroke whenever the stroke is a static value.
function UI.label(scope: Scope, props: { [any]: any })
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		Font = UI.FONT,
		TextColor3 = UI.WHITE,
		TextStrokeColor3 = UI.OUTLINE,
		TextStrokeTransparency = 0,
		TextScaled = false,
	}
	for key, value in props do
		if key ~= Children then base[key] = value end
	end
	local outline: Instance? = nil
	local strokeTransparency = base.TextStrokeTransparency
	if typeof(strokeTransparency) == "number" and strokeTransparency < 1 then
		local size = if typeof(base.TextSize) == "number" then base.TextSize else 22
		local color = if typeof(base.TextStrokeColor3) == "Color3" then base.TextStrokeColor3 else Cartoon.INK
		if color == UI.OUTLINE then color = Cartoon.INK end
		outline = Cartoon.textStroke(if base.TextScaled == true then 2.5 else Cartoon.strokeFor(size), color)
		base.TextStrokeTransparency = 1
	end
	base[Children] = { props[Children], outline }
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

-- Keep decorations at ZIndex0 so ordinary sibling text and controls draw above
-- the backing, including when their panel uses a higher ZIndex.
function UI.panelFill(scope: Scope)
	return {
		UI.corner(scope, 6),
		scope:New("UIStroke")({ Color = UI.HUD_BORDER, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		scope:New("Frame")({
			Name = "MenuStudBacking", Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UI.PANEL, BorderSizePixel = 0,
			ZIndex = 0, Active = false, Selectable = false, ClipsDescendants = true,
			[Children] = { UI.corner(scope, 6), studTexture(scope, 0.75, 6) },
		}),
	}
end

-- A passive accent strip; both color and height may be static or Fusion states.
-- Add beside the existing title/close controls, after UI.panelFill(scope).
function UI.menuHeader(scope: Scope, color: Fusion.UsedAs<Color3>, height: Fusion.UsedAs<number>)
	return scope:New("Frame")({
		Name = "MenuHeader", Position = UDim2.fromScale(0, 0),
		Size = scope:Computed(function(use) return UDim2.new(1, 0, 0, use(height)) end),
		BackgroundColor3 = color, BorderSizePixel = 0,
		ZIndex = 0, Active = false, Selectable = false, ClipsDescendants = true,
		[Children] = {
			UI.corner(scope, 6),
			studTexture(scope, 0.65, 6),
			scope:New("Frame")({
				Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = UI.OUTLINE, BorderSizePixel = 0,
				ZIndex = 0, Active = false, Selectable = false,
			}),
		},
	})
end

-- Simple inset cards with modest corners and a solid black outline.
function UI.cardFill(scope: Scope)
	return {
		UI.corner(scope, 4),
		scope:New("UIStroke")({
			Color = UI.HUD_BORDER,
			Thickness = 3,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(UI.WHITE, Color3.fromRGB(235, 235, 235)),
		}),
		studTexture(scope, 0.75, 4),
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
			Color = UI.HUD_BORDER,
			Transparency = 0.55,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		artwork,
		extraChildren,
	}
	return scope:New("Frame")(base)
end

-- A simple outlined action button. Native shading follows reactive fill colors.
function UI.button(scope: Scope, props: { [any]: any })
	local base = {
		BackgroundColor3 = UI.CASH,
		AutoButtonColor = true,
		Font = UI.FONT,
		TextSize = 20,
		TextColor3 = UI.WHITE,
		TextStrokeColor3 = UI.OUTLINE,
		TextStrokeTransparency = 0,
		BorderSizePixel = 0,
	}
	local children = props[Children]
	for key, value in props do
		if key ~= Children then
			base[key] = value
		end
	end
	base[Children] = {
		UI.corner(scope, 4),
		scope:New("UIStroke")({ Color = UI.OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(UI.WHITE, Color3.fromRGB(235, 235, 235)),
		}),
		studTexture(scope, 0.75, 4),
		children,
	}
	local button = scope:New("TextButton")(base)
	table.insert(scope, button.Activated:Connect(function()
		Sfx.play("Click")
	end))
	return button
end


-- The HUD layout for the current screen (Shared.HudLayout): a Computed that follows the
-- camera viewport and touch capability (spec §10). Every controller
-- that places a HUD button or sizes a panel reads it, so the geometry lives in one place.
function UI.hud(scope: Scope): Fusion.Computed<HudLayout.Layout>
	local player = game:GetService("Players").LocalPlayer
	local expanded = scope:Value(player:GetAttribute("FoundryExpanded") == true)
	table.insert(scope, player:GetAttributeChangedSignal("FoundryExpanded"):Connect(function()
		expanded:set(player:GetAttribute("FoundryExpanded") == true)
	end))
	local notification = scope:Value(player:GetAttribute("HudNotificationActive") == true)
	table.insert(scope, player:GetAttributeChangedSignal("HudNotificationActive"):Connect(function()
		notification:set(player:GetAttribute("HudNotificationActive") == true)
	end))
	local rewardNotification = scope:Value(player:GetAttribute("HudRewardNotificationActive") == true)
	table.insert(scope, player:GetAttributeChangedSignal("HudRewardNotificationActive"):Connect(function()
		rewardNotification:set(player:GetAttribute("HudRewardNotificationActive") == true)
	end))
	local viewport = scope:Value(Vector2.new(1280, 720))
	local function isTouch(): boolean
		-- Phones in Studio and hybrid devices can report a keyboard as well.
		-- Keep their touch controls and native movement UI clear in either case.
		return UserInputService.TouchEnabled
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
		return HudLayout.compute(use(viewport), use(touch), use(inset), use(expanded), use(notification), use(rewardNotification))
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
	local iconNames = { SHOP = "equipment", INDEX = "index", REBIRTH = "rebirth", STORE = "premium" }
	local tileColors = { SHOP = UI.ORANGE, INDEX = UI.SHARD, REBIRTH = UI.GREEN, STORE = UI.CASH }
	local tileColor = tileColors[name] or UI.CARD
	local hover = scope:Value(false)
	merged.Text = ""
	merged.BorderSizePixel = 0
	local accent = props.BackgroundColor3 or UI.HUD_BORDER
	local highlighted = scope:Computed(function(use)
		local color = use(accent)
		return name ~= "STORE" and color.G > color.R and color.G > color.B
	end)
	merged.BackgroundColor3 = scope:Computed(function(use)
		return if use(hover) then tileColor:Lerp(UI.WHITE, 0.12) else tileColor
	end)
	merged.BackgroundTransparency = 0
	merged.AutoButtonColor = false
	merged[ Fusion.OnEvent("MouseEnter") ] = function() hover:set(true) end
	merged[ Fusion.OnEvent("MouseLeave") ] = function() hover:set(false) end
	merged[ Fusion.OnEvent("SelectionGained") ] = function() hover:set(true) end
	merged[ Fusion.OnEvent("SelectionLost") ] = function() hover:set(false) end
	merged[Children] = {
		UI.corner(scope, 16),
		scope:New("UIStroke")({
			Color = UI.OUTLINE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = scope:Computed(function(use) return 2 / use(hud).buttonScale end),
		}),
		scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(UI.WHITE, UI.PANEL_BOTTOM) }),
		studTexture(scope, 0.75, 16),
		scope:New("UIScale")({
			Scale = scope:Computed(function(use)
				return use(hud).buttonScale
			end),
		}),
		props[Children],
		UI.hudIcon(scope, iconNames[name], {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.74, 0.74),
			ImageColor3 = UI.WHITE,
		}),
		UI.hudText(scope, {
			Name = "Caption", Position = UDim2.fromScale(0, 0.70), Size = UDim2.fromScale(1, 0.30),
			Text = if name == "SHOP" then "GEAR" else name, Font = UI.FONT,
			TextSize = scope:Computed(function(use) return use(hud).buttonTextSize or math.max(18, 11 / use(hud).buttonScale) end),
			TextColor3 = UI.WHITE, TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0,
		}),
		scope:New("Frame")({
			Name = "ReadyBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(9, 9), BackgroundColor3 = accent, BorderSizePixel = 0,
			Visible = highlighted, [Children] = { UI.corner(scope, 9) },
		}),
		UI.hudText(scope, {
			Name = "Tooltip", Position = if name == "INDEX" then UDim2.new(0, -110, 0.5, -16) else UDim2.new(1, 8, 0.5, -16), Size = UDim2.fromOffset(102, 32),
			Text = if name == "SHOP" then "GEAR" else name, TextSize = 14, BackgroundTransparency = 0,
			BackgroundColor3 = UI.HUD_SURFACE, Visible = scope:Computed(function(use) return use(hover) and not use(hud).touch end), ZIndex = 2,
			[Children] = { UI.corner(scope, 6) },
		}),
	}
	local button = scope:New("TextButton")(merged)
	table.insert(scope, button.Activated:Connect(function() Sfx.play("Click") end))
	return button
end

return UI
