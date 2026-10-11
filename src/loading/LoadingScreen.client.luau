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
	local function label(name: string, text: string, size: UDim2, position: UDim2, owner: Instance): TextLabel
		return make("TextLabel", name, {
			Size = size, Position = position, Text = text, BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = white,
			TextStrokeColor3 = ink, TextStrokeTransparency = 0,
		}, owner)
	end
	local function picture(name: string, owner: Instance): ImageLabel
		return make("ImageLabel", name, {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "",
			ScaleType = Enum.ScaleType.Fit,
		}, owner)
	end
	local root = make("CanvasGroup", "LoadingCanvas", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 0,
	}, parent)
	-- The sky gradient lives on its own frame: a UIGradient on the CanvasGroup would tint every child.
	local sky = frame("Sky", UDim2.fromScale(1, 1), UDim2.new(), white, root)
	gradient(sky, Color3.fromRGB(62, 155, 255), Color3.fromRGB(191, 235, 255))
	local fallback = frame("FallbackIsland", UDim2.fromScale(1, 1), UDim2.new(), white, root)
	fallback.BackgroundTransparency = 1
	local sea = frame("Lagoon", UDim2.fromScale(1, .43), UDim2.fromScale(0, .57), Color3.fromRGB(39, 196, 211), fallback)
	gradient(sea, Color3.fromRGB(69, 220, 230), Color3.fromRGB(44, 128, 208))
	local island = frame("Isle", UDim2.fromScale(.84, .24), UDim2.fromScale(.08, .48), Color3.fromRGB(88, 197, 96), fallback)
	rounded(island, 200)
	outline(island, 4)
	local wall = frame("Rampart", UDim2.fromScale(.7, .1), UDim2.fromScale(.15, .55), Color3.fromRGB(255, 236, 184), fallback)
	rounded(wall, 70)
	outline(wall, 4)
	local crater = frame("Crater", UDim2.fromScale(.24, .1), UDim2.fromScale(.26, .57), Color3.fromRGB(34, 53, 79), fallback)
	rounded(crater, 100)
	outline(crater, 4)
	local backdrop = picture("Backdrop", root)
	backdrop.ScaleType = Enum.ScaleType.Crop
	local clouds = {}
	for i = 1, 3 do
		local cloud = frame("Cloud" .. i, UDim2.fromOffset(210, 72), UDim2.new(), white, root)
		rounded(cloud, 80)
		gradient(cloud, white, Color3.fromRGB(238, 236, 252))
		local puff = frame("Puff", UDim2.fromScale(.58, 1), UDim2.fromScale(.2, -.3), white, cloud)
		rounded(puff, 90)
		local sprite = picture("Sprite", cloud)
		sprite.Size = UDim2.fromScale(1.2, 1.5)
		sprite.Position = UDim2.fromScale(-.1, -.45)
		table.insert(clouds, { body = cloud, puff = puff, sprite = sprite })
	end
	local trail = frame("Trail", UDim2.fromOffset(180, 22), UDim2.new(), Color3.fromRGB(255, 178, 30), root)
	-- Rotation pivots on the centre, so the position is worked out per frame to keep the head on the meteor.
	trail.AnchorPoint = Vector2.new(.5, .5)
	rounded(trail, 40)
	local trailGradient = gradient(trail, gold, Color3.fromRGB(255, 128, 26))
	trailGradient.Rotation = 0
	trailGradient.Transparency = NumberSequence.new(1, .05)
	local trailSprite = picture("Sprite", trail)
	local meteor = frame("Meteor", UDim2.fromOffset(86, 86), UDim2.new(), Color3.fromRGB(184, 118, 84), root)
	meteor.AnchorPoint = Vector2.new(.5, .5)
	rounded(meteor, 32)
	outline(meteor, 4)
	local core = frame("Core", UDim2.fromScale(.45, .45), UDim2.fromScale(.275, .275), Color3.fromRGB(255, 150, 60), meteor)
	rounded(core, 20)
	local meteorSprite = picture("Sprite", meteor)
	local ring = frame("Impact", UDim2.new(), UDim2.new(), white, root)
	ring.AnchorPoint = Vector2.new(.5, .5)
	ring.BackgroundTransparency = 1
	rounded(ring, 1000)
	local ringStroke = outline(ring, 6)
	ringStroke.Color = gold
	local chips = {}
	for i = 1, 6 do
		local chip = frame("Chip" .. i, UDim2.fromOffset(9 + i, 9 + i), UDim2.new(), Color3.fromRGB(255, 178, 30), root)
		rounded(chip, 3)
		outline(chip, 2)
		table.insert(chips, chip)
	end
	local logo = frame("Logo", UDim2.fromOffset(720, 190), UDim2.fromScale(.5, .24), white, root)
	logo.AnchorPoint = Vector2.new(.5, .5)
	logo.BackgroundTransparency = 1
	local logoText = label("Title", "CRATERWORKS", UDim2.fromScale(1, .65), UDim2.new(), logo)
	logoText.TextScaled = true
	logoText.TextColor3 = gold
	local ribbon = frame("Ribbon", UDim2.fromScale(.65, .27), UDim2.fromScale(.175, .66), Color3.fromRGB(30, 104, 232), logo)
	rounded(ribbon, 9)
	outline(ribbon, 3)
	gradient(ribbon, Color3.fromRGB(86, 186, 255), Color3.fromRGB(30, 104, 232))
	local subtitle = label("Subtitle", "METEOR MINING", UDim2.fromScale(.96, 1), UDim2.fromScale(.02, 0), ribbon)
	subtitle.TextScaled = true
	local wordmark = picture("Wordmark", logo)
	local logoShine = frame("Shine", UDim2.fromScale(.14, 1), UDim2.fromScale(-.2, 0), white, logo)
	logoShine.BackgroundTransparency = .65
	logoShine.Rotation = 18
	local shineGradient = gradient(logoShine, white, white)
	shineGradient.Rotation = 0
	shineGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, 0), NumberSequenceKeypoint.new(1, 1) })
	logo.ClipsDescendants = true
	local panel = frame("ProgressPanel", UDim2.fromOffset(720, 150), UDim2.fromScale(.5, .86), Color3.fromRGB(12, 40, 112), root)
	panel.AnchorPoint = Vector2.new(.5, .5)
	rounded(panel, 16)
	outline(panel, 3)
	local panelFace = frame("Face", UDim2.new(1, 0, 1, -7), UDim2.new(), Color3.fromRGB(22, 72, 190), panel)
	rounded(panelFace, 16)
	gradient(panelFace, Color3.fromRGB(56, 138, 240), Color3.fromRGB(22, 72, 190))
	local status = label("Status", "Waking up the crater...", UDim2.new(1, -110, 0, 32), UDim2.fromOffset(18, 10), panelFace)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextScaled = true
	make("UITextSizeConstraint", "TextLimit", { MaxTextSize = 24, MinTextSize = 12 }, status)
	local percent = label("Percent", "0%", UDim2.fromOffset(70, 32), UDim2.new(1, -86, 0, 10), panelFace)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.TextColor3 = gold
	local track = frame("Track", UDim2.new(1, -36, 0, 34), UDim2.fromOffset(18, 52), Color3.fromRGB(22, 72, 190), panelFace)
	rounded(track, 20)
	outline(track, 3)
	local fillClip = frame("FillClip", UDim2.fromScale(1, 1), UDim2.new(), white, track)
	fillClip.BackgroundTransparency = 1
	fillClip.ClipsDescendants = true
	rounded(fillClip, 20)
	local fill = frame("Fill", UDim2.fromScale(0, 1), UDim2.new(), Color3.fromRGB(50, 196, 30), fillClip)
	rounded(fill, 20)
	gradient(fill, Color3.fromRGB(178, 255, 74), Color3.fromRGB(50, 196, 30))
	local topShine = frame("TopShine", UDim2.new(1, -6, .4, 0), UDim2.fromOffset(3, 3), white, fill)
	rounded(topShine, 12)
	topShine.BackgroundTransparency = .7
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
	pickaxe.Size = UDim2.fromOffset(38, 38)
	pickaxe.AnchorPoint = Vector2.new(.5, .5)
	local pickFallback = label("PickaxeFallback", "⛏", UDim2.fromOffset(38, 38), UDim2.new(), track)
	pickFallback.AnchorPoint = Vector2.new(.5, .5)
	pickFallback.TextSize = 32
	local tipChip = frame("TipChip", UDim2.fromOffset(48, 28), UDim2.fromOffset(18, 104), gold, panelFace)
	rounded(tipChip, 8)
	outline(tipChip, 2)
	gradient(tipChip, gold, Color3.fromRGB(255, 178, 30))
	local tipTitle = label("TipTitle", "TIP", UDim2.fromScale(1, 1), UDim2.new(), tipChip)
	tipTitle.TextSize = 18
	tipTitle.TextColor3 = ink
	tipTitle.TextStrokeTransparency = 1
	local tip = label("Tip", "Mine the glowing rocks between meteors.", UDim2.new(1, -100, 0, 30), UDim2.fromOffset(78, 103), panelFace)
	tip.TextXAlignment = Enum.TextXAlignment.Left
	tip.TextTruncate = Enum.TextTruncate.AtEnd
	tip.TextSize = 22
	local flash = frame("DismissFlash", UDim2.fromScale(1, 1), UDim2.new(), white, root)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 20
	-- Lower right, after SKIP_AFTER seconds: ends the screen early through the normal fade (see the runtime below)
	local SKIP_AFTER = 4
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
		backdrop.Image = config.Background or ""
		wordmark.Image = config.Wordmark or ""
		trailSprite.Image = config.Trail or ""
		meteorSprite.Image = icons.meteor or ""
		pickaxe.Image = icons.equipment or ""
		for _, cloud in clouds do cloud.sprite.Image = config.Cloud or "" end
	end
	local function loaded(image: ImageLabel): boolean
		-- Never hide the image itself: an invisible ImageLabel is not requested, so IsLoaded would stay false.
		-- An unloaded ImageLabel draws nothing, so the fallback shows until this returns true.
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
		local logoWidth = math.min(1100, size.X - 24, math.max(360, size.X * (if compact then .7 else .38)))
		local impactAge = elapsed % 4.1 - 2.2
		local shake = if not reduced and impactAge >= 0 and impactAge < .25 then math.sin(impactAge * 100) * 6 * (1 - impactAge / .25) else 0
		logo.Size = UDim2.fromOffset(logoWidth, logoWidth * .27)
		local wide = (settings and settings.LogoWide) or Vector2.new(.5, .24)
		local logoY = math.max(logoWidth * .135 + 40, size.Y * (if compact then .2 else wide.Y))
		logo.Position = UDim2.new(if compact then .5 else wide.X, shake, 0, logoY + (if reduced then 0 else math.sin(elapsed * math.pi / 1.2) * 6))
		status.Text = statusText
		percent.Text = tostring(math.floor(progress * 100 + .00001)) .. "%"
		fill.Size = UDim2.fromScale(progress, 1)
		fill.Visible = progress > 0
		tip.Text = tipText
		tip.TextSize = if compact then 18 else 22
		tip.Position = UDim2.fromOffset(78, if compact then 89 else 103)
		tipChip.Position = UDim2.fromOffset(18, if compact then 90 else 104)
		track.Position = UDim2.fromOffset(18, if compact then 45 else 52)
		tip.TextTransparency = tipAlpha
		tip.TextStrokeTransparency = tipAlpha
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
		pickFallback.Position = pickaxe.Position
		pickFallback.Rotation = pickaxe.Rotation
		pickFallback.Visible = not loaded(pickaxe)
		fallback.Visible = not loaded(backdrop)
		-- A background with the logo painted in (LogoBaked) replaces the live logo and the drifting clouds, which would cover it.
		local baked = settings ~= nil and settings.LogoBaked == true and loaded(backdrop)
		logo.Visible = not baked
		local hasWordmark = loaded(wordmark)
		logoText.Visible = not hasWordmark
		ribbon.Visible = not hasWordmark
		logoShine.Visible = not reduced and elapsed % 5 < 1
		logoShine.Position = UDim2.fromScale((elapsed % 5) * 1.4 - .2, 0)
		for i, cloud in clouds do
			cloud.body.Visible = not reduced and not baked
			cloud.body.Position = UDim2.fromScale(((i * .3 + elapsed / (60 + i * 10)) % 1.35) - .2, .08 + (i - 1) * .075)
			local hasSprite = loaded(cloud.sprite)
			cloud.body.BackgroundTransparency = if hasSprite then 1 else 0
			cloud.puff.Visible = not hasSprite
		end
		-- Crop uses the authored crater's image coordinates, including on portrait phones.
		local imageSize = (settings and settings.BackgroundSize) or Vector2.new(2048, 1152)
		local crater = (settings and settings.Crater) or Vector2.new(.38, .62)
		local cropScale = math.max(size.X / imageSize.X, size.Y / imageSize.Y)
		local impactX = if backdrop.Visible then size.X * .5 + (imageSize.X * crater.X - imageSize.X / 2) * cropScale else size.X * .38
		local impactY = if backdrop.Visible then size.Y * .5 + (imageSize.Y * crater.Y - imageSize.Y / 2) * cropScale else size.Y * .62
		-- A painted sky has no crater: the meteor is bigger and crosses the whole screen, tail included, instead of landing.
		local fly = baked
		local meteorSize = if fly then math.clamp(size.X * .11, 80, 220) else math.clamp(size.X * .055, 42, 100)
		local hasTrail = loaded(trailSprite)
		-- The sprite (1191x357) is a fireball on the right with its tail to the left; its head sits about 85% along.
		local trailW = if hasTrail then meteorSize * (if fly then 6 else 4.2) else 180
		local startX, startY, endX, endY = size.X * .9, -size.Y * .1, impactX, impactY
		if fly then
			startX, startY = size.X + meteorSize, -meteorSize
			local baseX, baseY = -meteorSize, size.Y + meteorSize
			local length = math.sqrt((baseX - startX) ^ 2 + (baseY - startY) ^ 2)
			-- run on until the tail has left the screen too
			local extra = trailW + meteorSize
			endX = baseX + (baseX - startX) / length * extra
			endY = baseY + (baseY - startY) / length * extra
		end
		local flight = if fly then math.clamp((elapsed % 4.1) / 2.8, 0, 1) else math.clamp((elapsed % 4.1) / 2.2, 0, 1) ^ 2
		if reduced then flight = if fly then .5 else 1 end
		local meteorX = startX + (endX - startX) * flight
		local meteorY = startY + (endY - startY) * flight
		meteor.Size = UDim2.fromOffset(meteorSize, meteorSize)
		meteor.Position = UDim2.fromOffset(meteorX, meteorY)
		local hasMeteor = loaded(meteorSprite)
		meteor.BackgroundTransparency = if hasMeteor then 1 else 0
		meteor.Ink.Enabled = not hasMeteor
		core.Visible = not hasMeteor
		local heading = math.atan2(endY - startY, endX - startX)
		-- The meteor icon's flame trails to its upper left, so it flies toward 45 degrees; turn it to match the trail.
		meteor.Rotation = math.deg(heading) - 45
		trail.Size = UDim2.fromOffset(trailW, if hasTrail then trailW * 357 / 1191 else 22)
		local back = if hasTrail then .35 * trailW else trailW * .5
		trail.Position = UDim2.fromOffset(meteorX - math.cos(heading) * back, meteorY - math.sin(heading) * back)
		trail.Rotation = math.deg(heading)
		trail.Visible = not reduced and flight < 1
		trail.BackgroundTransparency = if hasTrail then 1 else flight * .5
		local impact = math.clamp(impactAge / .5, 0, 1)
		ring.Visible = not reduced and not fly and impactAge >= 0 and impactAge < .5
		ring.Position = UDim2.fromOffset(impactX, impactY)
		ring.Size = UDim2.fromOffset(size.X * .22 * impact, size.X * .22 * impact)
		ringStroke.Transparency = impact
		for i, chip in chips do
			chip.Visible = not reduced and not fly and impactAge >= 0 and impactAge < .5
			chip.Position = UDim2.fromOffset(impactX + (i - 3.5) * 30 * impact, impactY - math.sin(impact * math.pi) * (60 + i * 8))
			chip.Rotation = i * 45 + impact * 180
			chip.BackgroundTransparency = impact
			chip.Ink.Transparency = impact
		end
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
local maxShow, minShow, tipSeconds, assetTimeout = 25, 2.5, 4.5, 12
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
			maxShow = math.clamp(config.MaxShow, .65, 25)
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
			for _, id in { config.Background, config.Wordmark, config.Cloud, config.Trail } do addId(id) end
			for _, id in config.Preload do addId(id) end
			for _, id in icons do addId(id) end
			local meshCount = 0
			for _, name in { "PetModels", "MeshArt" } do
				local container = ReplicatedStorage:FindFirstChild(name)
				if container then
					for _, child in container:GetDescendants() do
						if child:IsA("MeshPart") and meshCount < 300 then
							table.insert(list, child)
							meshCount += 1
						end
					end
				end
			end
			local assetStarted, completed = os.clock(), false
			local preloadThread: thread? = nil
			spawnOwned(function()
				local processed = 0
				for _, asset in list do
					if not alive then return end
					-- Count completed input items (callbacks can fire multiple times per mesh).
					pcall(function() ContentProvider:PreloadAsync({ asset }) end)
					processed += 1
					if alive then progress:setStage("assets", processed / math.max(1, #list)) end
				end
				completed = true
				if alive then progress:setStage("assets", 1) end
			end)
			preloadThread = threads[#threads]
			while alive and not completed and os.clock() - assetStarted < assetTimeout do task.wait(.05) end
			if alive and not completed then
				if preloadThread and coroutine.status(preloadThread) ~= "dead" then pcall(task.cancel, preloadThread) end
				progress:setStage("assets", 1)
			end
		end)
		-- Missing/broken config simply uses the already-visible fallback until the deadline.
		if not success then config = nil end
	end)
end)
if not ok then
	cleanup()
	warn("[LoadingScreen] " .. tostring(startupError))
end
