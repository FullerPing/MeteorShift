--!strict
game:GetService("ReplicatedFirst"):RemoveDefaultLoadingScreen()

-- The view uses only built-in Instances: it can render before Shared arrives.
-- Edit-mode preview tools may evaluate this section and return buildView.
local function buildView(parent: Instance)
	local ink = Color3.fromRGB(14, 24, 52)
	local white = Color3.new(1, 1, 1)
	local gold = Color3.fromRGB(255, 240, 120)
	local function make(className: string, name: string, props: any, owner: Instance): any
		local item: any = Instance.new(className)
		item.Name = name
		for key, value in props do item[key] = value end
		item.Parent = owner
		return item
	end
	local function rounded(item: Instance, radius: number)
		make("UICorner", "Round", { CornerRadius = UDim.new(0, radius) }, item)
	end
	local function outline(item: Instance, thickness: number)
		return make("UIStroke", "Ink", { Color = ink, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, item)
	end
	local function gradient(item: Instance, top: Color3, bottom: Color3)
		(item :: GuiObject).BackgroundColor3 = Color3.new(1, 1, 1)
		return make("UIGradient", "Gradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, item)
	end
	local function frame(name: string, size: UDim2, position: UDim2, color: Color3, owner: Instance): Frame
		return make("Frame", name, { Size = size, Position = position, BackgroundColor3 = color, BorderSizePixel = 0 }, owner)
	end
	-- FredokaOne with a chunky ink outline (a UIStroke, much bolder than TextStroke), like the HUD
	local function label(name: string, text: string, size: UDim2, position: UDim2, owner: Instance): TextLabel
		local item = make("TextLabel", name, {
			Size = size, Position = position, Text = text, BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = white, TextStrokeTransparency = 1,
		}, owner)
		make("UIStroke", "TextInk", { Color = ink, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round }, item)
		return item
	end
	local function picture(name: string, owner: Instance): ImageLabel
		return make("ImageLabel", name, {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
			ScaleType = Enum.ScaleType.Fit,
		}, owner)
	end
	-- A full white screen (owner, 2026-10-20): the logo above the progress card, nothing else
	local root = make("CanvasGroup", "LoadingCanvas", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = white, BackgroundTransparency = 0, BorderSizePixel = 0, GroupTransparency = 0,
	}, parent)
	local logo = frame("Logo", UDim2.fromOffset(720, 452), UDim2.fromScale(.5, .38), white, root)
	logo.AnchorPoint = Vector2.new(.5, .5)
	logo.BackgroundTransparency = 1
	logo.ClipsDescendants = true
	-- the game's name in text, shown only until (or if never) the logo picture loads
	local logoText = label("Title", "METEOR MINING", UDim2.fromScale(1, .3), UDim2.fromScale(0, .3), logo)
	logoText.TextScaled = true
	logoText.TextColor3 = gold
	local ribbon = frame("Ribbon", UDim2.fromScale(.6, .14), UDim2.fromScale(.2, .62), Color3.fromRGB(30, 104, 232), logo)
	rounded(ribbon, 9)
	outline(ribbon, 3)
	gradient(ribbon, Color3.fromRGB(86, 186, 255), Color3.fromRGB(30, 104, 232))
	local subtitle = label("Subtitle", "SIMULATOR", UDim2.fromScale(.96, 1), UDim2.fromScale(.02, 0), ribbon)
	subtitle.TextScaled = true
	local wordmark = picture("Wordmark", logo)
	local logoShine = frame("Shine", UDim2.fromScale(.14, 1), UDim2.fromScale(-.2, 0), white, logo)
	logoShine.BackgroundTransparency = .65
	logoShine.Rotation = 18
	local shineGradient = gradient(logoShine, white, white)
	shineGradient.Rotation = 0
	shineGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, 0), NumberSequenceKeypoint.new(1, 1) })
	-- The progress card: a white body on a navy lip with an ink outline, like the game's menus
	local panel = frame("ProgressPanel", UDim2.fromOffset(720, 150), UDim2.fromScale(.5, .86), Color3.fromRGB(22, 58, 150), root)
	panel.AnchorPoint = Vector2.new(.5, .5)
	rounded(panel, 22)
	outline(panel, 4)
	local panelFace = frame("Face", UDim2.new(1, 0, 1, -8), UDim2.new(), white, panel)
	rounded(panelFace, 22)
	gradient(panelFace, white, Color3.fromRGB(214, 236, 255))
	local status = label("Status", "Waking up the crater...", UDim2.new(1, -120, 0, 32), UDim2.fromOffset(20, 10), panelFace)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextScaled = true
	make("UITextSizeConstraint", "TextLimit", { MaxTextSize = 26, MinTextSize = 12 }, status)
	local percent = label("Percent", "0%", UDim2.fromOffset(90, 34), UDim2.new(1, -108, 0, 9), panelFace)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.TextColor3 = gold
	percent.TextSize = 28
	local track = frame("Track", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 52), Color3.fromRGB(22, 50, 118), panelFace)
	rounded(track, 20)
	outline(track, 3)
	local trackShade = gradient(track, Color3.fromRGB(14, 32, 86), Color3.fromRGB(34, 70, 150))
	trackShade.Rotation = 90
	local fillClip = frame("FillClip", UDim2.fromScale(1, 1), UDim2.new(), white, track)
	fillClip.BackgroundTransparency = 1
	fillClip.ClipsDescendants = true
	rounded(fillClip, 20)
	local fill = frame("Fill", UDim2.fromScale(0, 1), UDim2.new(), Color3.fromRGB(50, 196, 30), fillClip)
	rounded(fill, 20)
	gradient(fill, Color3.fromRGB(178, 255, 74), Color3.fromRGB(50, 196, 30))
	local topShine = frame("TopShine", UDim2.new(1, -10, .36, 0), UDim2.fromOffset(5, 3), white, fill)
	rounded(topShine, 12)
	topShine.BackgroundTransparency = .55
	local gloss = frame("Gloss", UDim2.fromScale(1, 1), UDim2.new(), white, fill)
	rounded(gloss, 20)
	local glossGradient = gradient(gloss, white, white)
	glossGradient.Rotation = 25
	glossGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.2, 1),
		NumberSequenceKeypoint.new(.25, .75), NumberSequenceKeypoint.new(.35, .75),
		NumberSequenceKeypoint.new(.4, 1), NumberSequenceKeypoint.new(.55, 1),
		NumberSequenceKeypoint.new(.6, .75), NumberSequenceKeypoint.new(.7, .75),
		NumberSequenceKeypoint.new(.75, 1), NumberSequenceKeypoint.new(1, 1),
	})
	local pickaxe = picture("Pickaxe", track)
	pickaxe.Size = UDim2.fromOffset(52, 52)
	pickaxe.AnchorPoint = Vector2.new(.5, .5)
	pickaxe.ZIndex = 3
	local tipChip = frame("TipChip", UDim2.fromOffset(52, 28), UDim2.fromOffset(20, 104), gold, panelFace)
	rounded(tipChip, 9)
	outline(tipChip, 2.5)
	gradient(tipChip, gold, Color3.fromRGB(255, 178, 30))
	local tipTitle = label("TipTitle", "TIP", UDim2.fromScale(1, 1), UDim2.new(), tipChip)
	tipTitle.TextSize = 18
	tipTitle.TextColor3 = ink;
	(tipTitle:FindFirstChild("TextInk") :: UIStroke).Enabled = false
	local tip = label("Tip", "Mine the glowing rocks between meteors.", UDim2.new(1, -104, 0, 30), UDim2.fromOffset(82, 103), panelFace)
	tip.TextXAlignment = Enum.TextXAlignment.Left
	tip.TextTruncate = Enum.TextTruncate.AtEnd
	tip.TextColor3 = Color3.fromRGB(22, 50, 118);
	(tip:FindFirstChild("TextInk") :: UIStroke).Enabled = false
	tip.TextSize = 22
	local flash = frame("DismissFlash", UDim2.fromScale(1, 1), UDim2.new(), white, root)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 20
	-- Lower right, after SKIP_AFTER seconds: ends the screen early through the normal fade (see the runtime below)
	local SKIP_AFTER = 2
	local skip = make("TextButton", "Skip", {
		Size = UDim2.fromOffset(110, 42), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20),
		Text = "SKIP", Font = Enum.Font.FredokaOne, TextSize = 22, TextColor3 = ink, AutoButtonColor = true,
		BorderSizePixel = 0, Visible = false, ZIndex = 25,
	}, root)
	rounded(skip, 12)
	outline(skip, 3)
	gradient(skip, gold, Color3.fromRGB(255, 178, 30))
	local view: any = { Root = root, Panel = panel, Logo = logo, Status = status, Percent = percent, Tip = tip, Flash = flash, Skip = skip }
	-- buildView runs before the runtime section declares `config`, so keep our own copy here.
	local settings: any = nil
	function view:setAssets(config: any, icons: any)
		settings = config
		wordmark.Image = config.Wordmark or ""
		pickaxe.Image = icons.equipment or ""
	end
	local function loaded(image: ImageLabel): boolean
		-- Never hide the image itself: an invisible ImageLabel is not requested, so IsLoaded would stay false.
		return image.Image ~= "" and image.IsLoaded
	end
	function view:update(elapsed: number, progress: number, statusText: string, tipText: string, tipAlpha: number, reduced: boolean)
		local size = root.AbsoluteSize
		local compact = size.Y < 700 or size.X < 700
		-- the gui runs edge to edge, so phones keep the panel clear of the notch and rounded corners
		local panelWidth = math.min(720, size.X * (if compact then .8 else .84))
		local panelHeight = if compact then 130 else 150
		panel.Size = UDim2.fromOffset(panelWidth, panelHeight)
		panel.Position = UDim2.fromOffset(size.X * .5, math.min(size.Y * .86, size.Y - panelHeight * .5 - 14))
		-- the logo: as big as fits between the top and the progress card, centred in that space, with a gentle bob
		local aspect = (settings and settings.WordmarkAspect) or .627
		local room = panel.Position.Y.Offset - panelHeight * .5 - 48
		local logoWidth = math.max(0, math.min(size.X * (if compact then .86 else .56), room / aspect, 1100))
		logo.Size = UDim2.fromOffset(logoWidth, logoWidth * aspect)
		logo.Position = UDim2.new(.5, 0, 0, 24 + room * .5 + (if reduced then 0 else math.sin(elapsed * math.pi / 1.2) * 6))
		local hasWordmark = loaded(wordmark)
		logoText.Visible = not hasWordmark
		ribbon.Visible = not hasWordmark
		logoShine.Visible = not reduced and elapsed % 5 < 1
		logoShine.Position = UDim2.fromScale((elapsed % 5) * 1.4 - .2, 0)
		status.Text = statusText
		percent.Text = tostring(math.floor(progress * 100 + .00001)) .. "%"
		fill.Size = UDim2.fromScale(progress, 1)
		fill.Visible = progress > 0
		tip.Text = tipText
		tip.TextSize = if compact then 18 else 22
		tip.Position = UDim2.fromOffset(82, if compact then 89 else 103)
		tipChip.Position = UDim2.fromOffset(20, if compact then 90 else 104)
		track.Position = UDim2.fromOffset(20, if compact then 45 else 52)
		tip.TextTransparency = tipAlpha
		-- SKIP sits in the lower right corner; where the panel reaches that far (phones) it moves up above the panel
		local skipW, skipH, skipMargin = if compact then 92 else 110, if compact then 36 else 42, 20
		skip.Size = UDim2.fromOffset(skipW, skipH)
		skip.TextSize = if compact then 18 else 22
		local panelRight = size.X * .5 + panelWidth * .5
		local panelTop = panel.Position.Y.Offset - panelHeight * .5
		local overlaps = size.X - skipMargin - skipW < panelRight + 8
		skip.Position = UDim2.fromOffset(size.X - skipMargin, if overlaps then panelTop - 8 else size.Y - skipMargin)
		skip.Visible = elapsed >= SKIP_AFTER
		glossGradient.Offset = Vector2.new(if reduced then 0 else (elapsed % 2) - 1, 0)
		pickaxe.Position = UDim2.new(math.clamp(progress, .03, .97), 0, .5, 0)
		pickaxe.Rotation = if reduced then 0 else math.sin(elapsed * math.pi * 4) * 20
	end
	return view
end

-- Runtime: keep all waits out of the render path and under the same deadline.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local started = os.clock()
local alive, finishing, skipRequested = true, false, false
local maxShow, minShow, tipSeconds, assetTimeout = 20, 1.5, 3.5, 5
local player: Player? = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "CraterworksLoading"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- edge to edge: the default safe-area insets leave the notch side and rounded corners uncovered on phones
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local connections: { RBXScriptConnection } = {}
local threads: { thread } = {}
local view: any = nil
local progress: any = nil
local logic: any = nil
local config: any = nil
local display = 0
local tipIndex, tipSeed = 1, 73
local tips = { "Mine the glowing rocks between meteors." }
local nextTipAt, tipChangedAt = 4.5, -1
local readyFrame = false
local finishAt = 0
local warnedTimeout = false

local function cleanup()
	if not alive then return end
	alive = false
	for _, connection in connections do connection:Disconnect() end
	for _, thread in threads do
		if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then pcall(task.cancel, thread) end
	end
	if player then player:SetAttribute("LoadingDone", true) end
	gui:Destroy()
end
local function spawnOwned(callback: () -> ())
	local thread = coroutine.create(callback)
	table.insert(threads, thread)
	task.spawn(thread)
end
local function held(): boolean
	return ReplicatedFirst:GetAttribute("HoldLoading") == true
end
local function timeoutWarning()
	if not warnedTimeout then
		warnedTimeout = true
		warn("[LoadingScreen] Startup deadline reached; continuing to the game.")
	end
end
-- Independent of Shared, PlayerGui, require, PreloadAsync and RenderStepped.
spawnOwned(function()
	while alive do
		if not held() and os.clock() - started >= maxShow then
			if not finishing then timeoutWarning() end
			cleanup()
			return
		end
		task.wait(.05)
	end
end)

local ok, startupError = pcall(function()
	view = buildView(gui)
	local function attach()
		player = player or Players.LocalPlayer
		local playerGui = if player then player:FindFirstChildOfClass("PlayerGui") else nil
		if playerGui and gui.Parent ~= playerGui then gui.Parent = playerGui end
	end
	attach()
	local function update(dt: number)
		attach()
		local elapsed = os.clock() - started
		local reduced = player ~= nil and player:GetAttribute("ReduceEffects") == true
		if finishing then
			local age = elapsed - finishAt
			view.Flash.BackgroundTransparency = if reduced then 1 else math.clamp(age / .15, 0, 1)
			view.Root.GroupTransparency = math.clamp((age - (if reduced then 0 else .15)) / .5, 0, 1)
			if view.Root.GroupTransparency >= 1 then cleanup() end
			return
		end
		if progress then
			if game:IsLoaded() then progress:setStage("engine", 1) end
			if player and player:GetAttribute("HudReady") == true then
				progress:setStage("state", 1)
				-- The next render frame confirms the HUD had a chance to draw.
				if readyFrame then progress:setStage("hud", 1) end
				readyFrame = true
			end
		end
		local total = if progress then progress:total() else math.min(.12, elapsed * .024)
		local target = math.max(display, total)
		display = if logic then logic.ease(display, target, dt) else display + (target - display) * (1 - math.exp(-dt * 6))
		if elapsed >= nextTipAt and logic then
			tipIndex, tipSeed = logic.nextTip(#tips, tipIndex, tipSeed)
			tipChangedAt = elapsed
			nextTipAt = elapsed + tipSeconds
		end
		local tipAlpha = if reduced then 0 else math.max(math.clamp((elapsed - nextTipAt + .25) / .25, 0, 1), math.clamp(1 - (elapsed - tipChangedAt) / .25, 0, 1))
		local status = if logic then logic.status(display * 100, if config then config.StatusThresholds else nil) else "Waking up the crater..."
		view:update(elapsed, display, status, tips[tipIndex] or tips[1], tipAlpha, reduced)
		-- Reserve the fade inside MaxShow rather than adding it after the deadline.
		local shouldFinish = if logic then logic.shouldFinish(elapsed, total, minShow, math.max(0, maxShow - .65)) else elapsed >= maxShow - .65
		if not held() and (skipRequested or shouldFinish) then
			finishing, finishAt = true, elapsed
			if skipRequested then
				-- the player chose to leave early: nothing to warn about
			elseif total < 1 then timeoutWarning() else
				view:update(elapsed, 1, "Ready!", tips[tipIndex] or tips[1], 0, reduced)
			end
		end
	end
	table.insert(connections, view.Skip.Activated:Connect(function()
		skipRequested = true
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local success, err = pcall(update, dt)
		if not success then
			cleanup()
			warn("[LoadingScreen] " .. tostring(err))
		end
	end))
	update(0)
	spawnOwned(function()
		local function findChild(owner: Instance, name: string): Instance?
			while alive do
				local child = owner:FindFirstChild(name)
				if child then return child end
				task.wait(.05)
			end
			return nil
		end
		local shared = findChild(ReplicatedStorage, "Shared")
		if not shared then return end
		local progressModule = findChild(shared, "LoadingProgress")
		local configModule = findChild(shared, "Config")
		if not progressModule or not configModule then return end
		local loadingModule = findChild(configModule, "Loading")
		local iconsModule = findChild(configModule, "HudIcons")
		if not loadingModule or not iconsModule then return end
		local success = pcall(function()
			logic = require(progressModule :: ModuleScript)
			config = require(loadingModule :: ModuleScript)
			local icons = require(iconsModule :: ModuleScript)
			if not alive then return end
			maxShow = math.clamp(config.MaxShow, .65, 45)
			minShow = math.clamp(config.MinShow, 0, maxShow)
			tipSeconds = math.max(.5, config.TipSeconds)
			assetTimeout = math.clamp(config.AssetTimeout or 12, 0, 12)
			tips = if #config.Tips > 0 then config.Tips else tips
			progress = logic.new(config.Weights)
			view:setAssets(config, icons)
			local list: { any } = {}
			local seen: { [string]: boolean } = {}
			local function addId(id: any)
				if type(id) == "string" and string.match(id, "^rbxassetid://%d+$") and not seen[id] then
					seen[id] = true
					table.insert(list, id)
				end
			end
			-- The world (its own stage, alongside the assets): the character, the streamed map around it, the game's
			-- client code started, then the downloads that map queued drained, so the screen opens on a drawn world
			-- instead of one still popping in. WorldTimeout caps it; MaxShow caps everything.
			spawnOwned(function()
				local deadline = os.clock() + (config.WorldTimeout or 20)
				local function step(fraction: number) if alive then progress:setStage("world", fraction) end end
				local me = Players.LocalPlayer
				local root: BasePart? = nil
				while alive and os.clock() < deadline do
					local character = me and me.Character
					root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
					if root then break end
					task.wait(.1)
				end
				step(.25)
				-- the map streams in around the character: wait until the parts near it stop arriving
				-- (RequestStreamAroundAsync is server-only, so the client watches the count instead)
				if root then
					local last, still = -1, 0
					while alive and os.clock() < deadline and still < 3 do
						local count = #workspace:GetPartBoundsInRadius(root.Position, 160)
						still = if count == last then still + 1 else 0
						last = count
						task.wait(.3)
					end
				end
				step(.5)
				while alive and os.clock() < deadline and me and me:GetAttribute("ClientStarted") ~= true do task.wait(.1) end
				step(.75)
				-- three quiet checks in a row: the queue can dip to empty between two waves of requests
				local quiet, peak = 0, 1
				while alive and os.clock() < deadline and quiet < 3 do
					local queued = ContentProvider.RequestQueueSize
					peak = math.max(peak, queued)
					quiet = if queued <= 2 then quiet + 1 else 0
					step(.75 + .25 * (1 - queued / peak))
					task.wait(.2)
				end
				step(1)
			end)
			-- What the screen waits for (up to AssetTimeout), requested in small parallel batches, not one by one: the
			-- logo, the HUD icons, then the meshes and sounds the menus and effects use (pets, art), so the menus open
			-- drawn instead of popping in. (The map is the world stage's job: with streaming most of it isn't here yet.)
			addId(config.Wordmark)
			for _, id in config.Preload do addId(id) end
			for _, id in icons do addId(id) end
			local instances = 0
			for _, container in { ReplicatedStorage:FindFirstChild("PetModels"), ReplicatedStorage:FindFirstChild("MeshArt"),
				game:GetService("SoundService") } do
				if container then
					for _, child in container:GetDescendants() do
						if instances >= (config.PreloadLimit or 1500) then break end
						if child:IsA("MeshPart") or child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance")
							or child:IsA("Sound") or child:IsA("SpecialMesh") then
							table.insert(list, child)
							instances += 1
						end
					end
				end
			end
			local assetStarted, done = os.clock(), 0
			local BATCH = 32
			local batches = math.max(1, math.ceil(#list / BATCH))
			for first = 1, #list, BATCH do
				spawnOwned(function()
					local batch = table.move(list, first, math.min(first + BATCH - 1, #list), 1, {})
					pcall(function() ContentProvider:PreloadAsync(batch) end)
					done += 1
					if alive then progress:setStage("assets", done / batches) end
				end)
			end
			if #list == 0 then progress:setStage("assets", 1) end
			while alive and done < batches and #list > 0 and os.clock() - assetStarted < assetTimeout do task.wait(.05) end
			if alive then progress:setStage("assets", 1) end
		end)
		-- Missing/broken config: the white screen and the text title stay until the deadline.
		if not success then config = nil end
	end)
end)
if not ok then
	cleanup()
	warn("[LoadingScreen] " .. tostring(startupError))
end
