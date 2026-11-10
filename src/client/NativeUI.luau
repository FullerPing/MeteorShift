--!strict
-- Studio-authored ScreenGui prefabs; controllers bind their named controls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local MenuFit = require(ReplicatedStorage.Shared.MenuFit)
local HudEditConfig = require(ReplicatedStorage.Shared.Config.HudEdit)
local Sfx = require(script.Parent.Sfx)
local MenuSkin = require(script.Parent.MenuSkin)
local MenuFlags = require(script.Parent.MenuFlags)
local NativeUI = {}
NativeUI.FONT = Enum.Font.FredokaOne
NativeUI.WHITE = Color3.new(1, 1, 1)
NativeUI.OUTLINE = Color3.fromRGB(12, 18, 25)
NativeUI.PANEL = Color3.fromRGB(43, 44, 49)
NativeUI.CARD = Color3.fromRGB(67, 69, 77)
NativeUI.MUTED = Color3.fromRGB(211, 228, 240)
NativeUI.CYAN = Color3.fromRGB(66, 190, 255)
NativeUI.ORANGE = Color3.fromRGB(255, 174, 52)
NativeUI.GREEN = Color3.fromRGB(105, 240, 103)
NativeUI.RED = Color3.fromRGB(235, 70, 70)
NativeUI.BODY_FONT = Enum.Font.GothamMedium
NativeUI.SUBTEXT, NativeUI.HUD_MUTED = NativeUI.MUTED, NativeUI.MUTED
NativeUI.SHARD = NativeUI.CYAN
NativeUI.HUD_GOLD = Color3.fromRGB(255, 219, 100)
NativeUI.HUD_MINT = Color3.fromRGB(139, 240, 195)

-- These authoring helpers run only when building the editable prefabs in Studio.
function NativeUI.create(class: string, props: { [string]: any }, parent: Instance?): any
	local object: any = Instance.new(class)
	for key, value in props do object[key] = value end
	object.Parent = parent
	return object
end
function NativeUI.surface(parent: GuiObject, radius: number?, alpha: number?)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, parent)
	NativeUI.create("UIStroke", { Color = NativeUI.OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	NativeUI.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }, parent)
	local texture = NativeUI.create("ImageLabel", {
		Name = "StudTexture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = "rbxassetid://6927295847", ImageTransparency = alpha or .72,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		Active = false, Selectable = false, ZIndex = 0,
	}, parent)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, texture)
end
function NativeUI.text(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, body: boolean?): TextLabel
	return NativeUI.create("TextLabel", {
		Name = name, Text = text, Position = position, Size = size, BackgroundTransparency = 1,
		Font = if body then Enum.Font.GothamMedium else NativeUI.FONT, TextSize = if body then 13 else 20,
		TextColor3 = NativeUI.WHITE, TextStrokeColor3 = NativeUI.OUTLINE, TextStrokeTransparency = if body then 1 else 0,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, parent)
end
function NativeUI.button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, color: Color3?): TextButton
	local button = NativeUI.create("TextButton", {
		Name = name, Text = text, Position = position, Size = size, BorderSizePixel = 0,
		BackgroundColor3 = color or NativeUI.CYAN, Font = NativeUI.FONT, TextSize = 17,
		TextColor3 = NativeUI.WHITE, TextStrokeColor3 = NativeUI.OUTLINE, TextStrokeTransparency = 0, ZIndex = 4,
	}, parent)
	NativeUI.surface(button)
	return button
end
function NativeUI.menu(name: string, title: string, color: Color3, width: number, height: number): ScreenGui
	local gui = NativeUI.create("ScreenGui", {
		Name = name, Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	gui:SetAttribute("NativePrefab", true)
	NativeUI.create("TextButton", { Name = "Dimmer", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = NativeUI.OUTLINE,
		BackgroundTransparency = .35, BorderSizePixel = 0, AutoButtonColor = false, Modal = true, Selectable = false }, gui)
	local panel = NativeUI.create("Frame", { Name = "Panel", Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = NativeUI.PANEL,
		BorderSizePixel = 0, Active = true, ZIndex = 2 }, gui)
	NativeUI.surface(panel, 4, .8)
	local header = NativeUI.create("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }, panel)
	NativeUI.surface(header, 4, .58)
	NativeUI.text(panel, "Title", title, UDim2.fromOffset(14, 4), UDim2.new(1, -80, 0, 44)).TextSize = 28
	NativeUI.button(panel, "Close", "X", UDim2.new(1, -48, 0, 4), UDim2.fromOffset(44, 44), NativeUI.RED)
	return gui
end
-- `prepare` runs before the shared cartoon skin, so a controller can mark the
-- subtrees it styles itself (attribute CartoonCustom = true).
function NativeUI.get(name: string, prepare: ((ScreenGui) -> ())?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- StarterGui is copied in when the character first spawns, which a slow device can take well past 15 s (live errors,
	-- 2026-10-24: Rebirth and Store were dead for that session), so keep waiting; warn once if it is really missing
	local gui = playerGui:FindFirstChild(name)
	local waited = os.clock()
	local warned = false
	while not gui do
		playerGui.ChildAdded:Wait()
		gui = playerGui:FindFirstChild(name)
		if not gui and not warned and os.clock() - waited > 60 then
			warned = true
			warn("Missing StarterGui prefab: " .. name .. ". Run tools/build-native-ui.luau in Edit mode.")
		end
	end
	assert(gui:IsA("ScreenGui"), name .. " in PlayerGui is not a ScreenGui")
	if prepare then prepare(gui :: ScreenGui) end
	MenuSkin.apply(gui :: ScreenGui)
	local function wire(node: Instance)
		if node:IsA("GuiButton") then
			-- gamepad selection must never land on the full-screen backdrop (A there would close the menu)
			if node.Name == "Dimmer" then node.Selectable = false end
			node.Activated:Connect(function() if node.Active then Sfx.play("Click") end end)
			NativeUI.pressable(node)
		end
	end
	for _, node in gui:GetDescendants() do wire(node) end
	-- rows cloned from Templates later get the click and the press too
	gui.DescendantAdded:Connect(function(node)
		local templates = gui:FindFirstChild("Templates")
		if not (templates and node:IsDescendantOf(templates)) then wire(node) end
	end)
	NativeUI.animateOpen(gui :: ScreenGui)
	return gui :: ScreenGui
end

-- Motion (off with Reduce Effects). Only positions move: a UIScale or size tween would re-pin every label's text size
-- each frame (FixedTextSize) and make the text step.
local PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- a short slide that settles with a slight overshoot, so a menu lands instead of stopping dead
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_FROM = 36 -- px below its place a menu starts its slide
local function calm(): boolean return Players.LocalPlayer:GetAttribute("ReduceEffects") == true end

-- A chunky button (MenuTheme.button: a Face over a navy lip) lifts a pixel under the pointer and sinks into its lip while
-- held, so every press is felt. Buttons that can't be pressed (Active false) stay still.
function NativeUI.pressable(button: GuiButton)
	local face = button:FindFirstChild("Face")
	if not face or not face:IsA("GuiObject") or button:GetAttribute("Pressable") then return end
	button:SetAttribute("Pressable", true)
	local rest = face.Position
	local hovered, held = false, false
	local function go()
		local dy = if not button.Active then 0 elseif held then 3 elseif hovered then -1 else 0
		local target = rest + UDim2.fromOffset(0, dy)
		if calm() then face.Position = target else TweenService:Create(face, PRESS, { Position = target }):Play() end
	end
	button.MouseEnter:Connect(function() hovered = true; go() end)
	button.MouseLeave:Connect(function() hovered, held = false, false; go() end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then held = true; go() end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then held = false; go() end
	end)
	button:GetPropertyChangedSignal("Active"):Connect(go)
end

-- When a menu shows (its ScreenGui enabled with the Panel visible, either way round), the Panel slides up into place and
-- the Dimmer fades in instead of both snapping on. Closing stays instant, so a close never feels slow.
local slides: { [GuiObject]: Tween } = setmetatable({}, { __mode = "k" }) :: any
local slideTargets: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
function NativeUI.animateOpen(gui: ScreenGui)
	local panel = gui:FindFirstChild("Panel") or gui:FindFirstChild("SettingsPanel")
	if not panel or not panel:IsA("GuiObject") then return end
	local dimmer = gui:FindFirstChild("Dimmer") or gui:FindFirstChild("SettingsBackdrop")
	local shownBefore = gui.Enabled and panel.Visible
	local function changed()
		local shownNow = gui.Enabled and panel.Visible
		if shownNow == shownBefore then return end
		shownBefore = shownNow
		if not shownNow or calm() then return end
		-- read the place after this frame's layout: the controller may position the panel right after showing it
		task.defer(function()
			if not (gui.Enabled and panel.Visible) then return end
			-- reopened mid-slide: aim for the place the last slide was heading to, not where it had got to
			local running = slides[panel]
			local target = if running and running.PlaybackState == Enum.PlaybackState.Playing then slideTargets[panel] or panel.Position else panel.Position
			if running then running:Cancel() end
			slideTargets[panel] = target
			panel.Position = target + UDim2.fromOffset(0, SLIDE_FROM)
			local tween = TweenService:Create(panel, SLIDE, { Position = target })
			slides[panel] = tween
			tween:Play()
			if dimmer and dimmer:IsA("GuiObject") then
				local alpha = dimmer:GetAttribute("RestTransparency")
				if type(alpha) ~= "number" then alpha = dimmer.BackgroundTransparency; dimmer:SetAttribute("RestTransparency", alpha) end
				dimmer.BackgroundTransparency = 1
				TweenService:Create(dimmer, FADE, { BackgroundTransparency = alpha }):Play()
			end
		end)
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(changed)
	panel:GetPropertyChangedSignal("Visible"):Connect(changed)
end
-- A menu authored in StarterGui is used as is; a place that has none yet gets one built from its NativeMenus module.
function NativeUI.getOrBuild(name: string, build: () -> ScreenGui, prepare: ((ScreenGui) -> ())?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if not playerGui:FindFirstChild(name) then build().Parent = playerGui end
	return NativeUI.get(name, prepare)
end
-- Like getOrBuild, but a copy saved in the place (StarterGui) or built earlier whose MenuLayout attribute is not
-- `layout` is thrown away first, so a redesigned builder wins over an old export.
function NativeUI.getFresh(name: string, build: () -> ScreenGui, layout: number, prepare: ((ScreenGui) -> ())?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local saved = playerGui:FindFirstChild(name)
	if not saved and StarterGui:FindFirstChild(name) then saved = playerGui:WaitForChild(name, 15) end
	if saved and saved:GetAttribute("MenuLayout") ~= layout then saved:Destroy() end
	return NativeUI.getOrBuild(name, build, prepare)
end
function NativeUI.enable(button: GuiButton, enabled: boolean, color: Color3)
	button.Active, button.Selectable, button.AutoButtonColor = enabled, enabled, enabled
	button.BackgroundColor3 = if enabled then color else Color3.fromRGB(29, 30, 35)
	if button:IsA("TextButton") then
		button.TextColor3 = if enabled then NativeUI.WHITE else NativeUI.MUTED
		button.TextStrokeTransparency = if enabled then 0 else 1
	end
end
function NativeUI.hudLayout(): HudLayout.Layout
	local p = Players.LocalPlayer
	-- Studio QA: a PreviewViewport attribute (Vector2) lays the menus out for that screen as a touch device
	local preview = p:GetAttribute("PreviewViewport")
	local viewport = if typeof(preview) == "Vector2" then preview
		elseif workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720)
	-- with Config.HudEdit applied, so the menu buttons follow the same moves and hides as the HUD cards
	return HudLayout.applyEdits(HudLayout.compute(viewport,
		UserInputService.TouchEnabled or typeof(preview) == "Vector2", GuiService:GetGuiInset().Y, p:GetAttribute("FoundryExpanded") == true,
		p:GetAttribute("HudNotificationActive") == true, p:GetAttribute("HudRewardNotificationActive") == true), HudEditConfig)
end
function NativeUI.onLayoutChanged(callback: (HudLayout.Layout) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local cameraConnection: RBXScriptConnection? = nil
	local function update() callback(NativeUI.hudLayout()) end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		cameraConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) else nil
		update()
	end
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(connections, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update))
	table.insert(connections, GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update))
	for _, name in { "FoundryExpanded", "HudNotificationActive", "HudRewardNotificationActive", "PreviewViewport" } do
		table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(update))
	end
	bindCamera()
	return function()
		if cameraConnection then cameraConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end
end
-- Menus on small screens: lay out for `view.viewport` / `view.inset` (Shared.MenuFit), then place the panel with
-- `place`, which centres it where that virtual rect lands and draws it at `view.scale`.
function NativeUI.menuView(hud: HudLayout.Layout): MenuFit.View
	return MenuFit.view(hud.viewport, hud.inset)
end
function NativeUI.place(panel: GuiObject, rect: MenuFit.Rect, view: MenuFit.View)
	local centre = MenuFit.centre(view, rect)
	local slide = slides[panel]
	if slide then slide:Cancel(); slides[panel] = nil end -- a resize mid-slide lands on the new place
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromOffset(centre.X, centre.Y)
	panel.Size = UDim2.fromOffset(rect.w, rect.h)
	local scale = panel:FindFirstChild("MenuFit") :: UIScale?
	if not scale then
		local made = Instance.new("UIScale")
		made.Name, made.Parent = "MenuFit", panel
		scale = made
	end
	(scale :: UIScale).Scale = view.scale
end
-- A fixed-size menu, centred under the top bar and drawn smaller where the screen is
function NativeUI.fitCentred(panel: GuiObject, natural: Vector2)
	-- the fit decides the size now; an authored size constraint would fight the draw scale
	for _, child in panel:GetChildren() do
		if child:IsA("UISizeConstraint") then child:Destroy() end
	end
	NativeUI.onLayoutChanged(function(hud)
		local view = NativeUI.menuView(hud)
		NativeUI.place(panel, MenuFit.centred(view, natural), view)
	end)
end
-- A fixed-design menu drawn whole (MenuFit.whole): smaller still where the screen has no room for it
function NativeUI.fitWhole(panel: GuiObject, natural: Vector2)
	for _, child in panel:GetChildren() do
		if child:IsA("UISizeConstraint") then child:Destroy() end
	end
	NativeUI.onLayoutChanged(function(hud)
		local view, rect = MenuFit.whole(NativeUI.menuView(hud), natural)
		NativeUI.place(panel, rect, view)
	end)
end
function NativeUI.bindOpen(gui: ScreenGui, attribute: string, close: () -> ())
	local p = Players.LocalPlayer
	local function update() gui.Enabled = p:GetAttribute(attribute) == true end
	p:GetAttributeChangedSignal(attribute):Connect(update)
	local dimmer = gui:WaitForChild("Dimmer") :: GuiButton
	local closeButton = gui:WaitForChild("Panel"):WaitForChild("Close") :: GuiButton
	dimmer.Activated:Connect(close)
	closeButton.Activated:Connect(close)
	UserInputService.InputBegan:Connect(function(input)
		if not gui.Enabled or UserInputService:GetFocusedTextBox() then return end -- Escape while typing only leaves the box
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	update()
end
-- Gamepad: when a menu opens, select its Close button (the shown one in the topmost ScreenGui) so the pad drives the
-- menu, not a covered HUD tile; when the last menu closes, drop the selection.
local function shown(object: Instance): boolean
	local node: Instance? = object
	while node and not node:IsA("ScreenGui") do
		if node:IsA("GuiObject") and not node.Visible then return false end
		node = node.Parent
	end
	return node ~= nil and (node :: ScreenGui).Enabled
end
function NativeUI.watchGamepadFocus(flags: { string })
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function refocus()
		task.defer(function()
			local selected = GuiService.SelectedObject
			if not MenuFlags.anyOpen(flags) then
				if selected then GuiService.SelectedObject = nil end
				return
			end
			if not string.find(UserInputService:GetLastInputType().Name, "Gamepad") then return end
			if selected and shown(selected) and selected.Interactable then return end
			local best: GuiObject? = nil
			local order = -math.huge
			for _, gui in playerGui:GetChildren() do
				if gui:IsA("ScreenGui") and gui.Enabled and gui.DisplayOrder > order then
					for _, close in gui:GetDescendants() do
						if close.Name == "Close" and close:IsA("GuiButton") and shown(close) then
							best, order = close, gui.DisplayOrder
							break
						end
					end
				end
			end
			GuiService.SelectedObject = best
		end)
	end
	MenuFlags.onChanged(flags, refocus)
end
return NativeUI
