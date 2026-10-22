--!strict
-- Where the HUD buttons, the MINE button and the panels go (spec §10). Pure math, no
-- Instances, so tests/HudLayout.spec.luau can check it for any screen size.
--
-- One place decides the geometry, so buttons cannot silently overlap each other, the
-- Roblox top bar, the thumbstick area or the jump button. Every controller asks for
-- its rect here instead of hard-coding a Y.
--
-- All rects are in SCREEN pixels, origin top-left of the full viewport (the strip under
-- the Roblox top bar starts at `inset`). GUIs with IgnoreGuiInset = true use them as is;
-- legacy GUIs that respect the inset can use HudLayout.toGui.
--
-- Desktop follows the reference; short touch screens use the clear centre strip,
-- and portrait cards stack above the thumbstick. Each rect has its own scale,
-- derived by the renderer from rect.w / baseWidth.

local Config = require(script.Parent.Config)

local Hud = Config.Hud
local BackpackPopupMinHeight, BackpackPopupGap = 72, 8
local BackpackPopupDailyHeight = 40 + 28 * 3 + 4 -- header and three ore rows: what Daily Rewards above Index must leave
local NavigationFaceSize, NavigationCaptionBottom = 80, 105
local PortraitWalletMax = 0.4 -- short portrait phones: the most the wallet beside the foundry button may scale
local PhoneClockLeft = 188 -- phones in landscape: Roblox's top-bar buttons end before this x
local PhoneClockScale = 0.45 -- phones in landscape: the clock in the top bar is at most this share of its base size
local PhoneObjectiveScale = 0.85 -- phones in landscape: the most the clock below the top bar scales to
local PhoneObjectiveDrop = 0.2 -- phones in landscape: how far the large clock sits from its top-bar spot (0) to below the bar (1)
local PhoneWalletScale = 0.5 -- phones in landscape: the wallet in the bottom-left corner

-- The personal navigation art has an 80 px face and a caption ending at y=105.
-- Keep the face's touch rect unchanged while reserving the caption below it.
local function navigationHeight(width: number, height: number): number
	return math.max(height, width * NavigationCaptionBottom / NavigationFaceSize)
end

export type Rect = { x: number, y: number, w: number, h: number }

export type Nudge = { x: number?, y: number?, scale: number? }
export type Edits = { Hidden: { string }?, Nudge: { [string]: Nudge }? }

export type Layout = {
	viewport: Vector2,
	touch: boolean,
	inset: number,
	scale: number, -- the HUD card scale
	compact: boolean,
	portrait: boolean,
	-- HUD buttons by name (Hud.ButtonOrder), drawn at `buttonBase` * `buttonScale`
	buttons: { [string]: Rect },
	buttonBase: Vector2, -- unscaled size to give the button with a UIScale of buttonScale
	buttonScale: number,
	buttonTextSize: number?, -- fixed text size for the touch row (nil: keep each button's own)
	timer: Rect,
	timerVisible: boolean, -- a notice can replace the clock on the smallest portrait
	leftCards: { [string]: Rect }, -- Resources, Equipment, Production
	resourcesVisible: boolean,
	leftScale: number, -- the scale to draw the left cards at
	eventPanel: Rect,
	tutorial: Rect,
	tutorialVisible: boolean, -- expanded touch details replace training temporarily
	backpack: Rect,
	backpackVisible: boolean,
	settings: Rect?,
	notification: Rect,
	notificationCompact: boolean,
	eventVisible: boolean, -- a brief notification may reserve the objective slot on tight screens
	tutorialY: number, -- inset-relative y retained for callers using toGui
	mine: Rect?, -- touch only
	fastWalk: Rect?, -- where SPRINT goes: phones in landscape (ORE sits above it) and desktop (beside the backpack); nil lets the button place itself
	ore: Rect?, -- desktop: where ORE goes, a tile in the left column under STORE; nil puts it above SPRINT
	levelAbove: boolean?, -- phones in landscape: the level medal sits above the wallet instead of on its corner
	objective: Rect?, -- phones in landscape: the clock's larger slot below the top bar (countdown, cooldown and objective)
	offers: { Rect }, -- touch and portrait: free cells in line with the menu buttons for the Offers buttons, best first
	jump: Rect?, -- Roblox's jump button (touch only)
	thumbstick: Rect?, -- Roblox's thumbstick area (touch only)
	topBar: Rect,
	-- set by applyEdits from Config.HudEdit: hidden element names and per-element nudges
	hidden: { [string]: boolean }?,
	nudge: { [string]: Nudge }?,
}

local HudLayout = {}

function HudLayout.scale(viewport: Vector2): number
	local base = math.clamp(
		math.min(viewport.X / Hud.ScaleRefWidth, viewport.Y / Hud.ScaleRefHeight),
		Hud.ScaleMin,
		Hud.ScaleMax
	)
	-- past 1080p the HUD grows with the screen, so a 1440p or 4K screen sees it the size a 1080p one does
	local up = math.min(viewport.X / Hud.ScaleUpRef.X, viewport.Y / Hud.ScaleUpRef.Y)
	return math.max(base, math.min(up, Hud.ScaleUpMax))
end

-- Two rects overlap when they share area (touching edges do not count)
function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function HudLayout.inside(inner: Rect, outer: Rect): boolean
	return inner.x >= outer.x
		and inner.y >= outer.y
		and inner.x + inner.w <= outer.x + outer.w
		and inner.y + inner.h <= outer.y + outer.h
end

-- The HUD gui starts under the top bar
function HudLayout.toGui(rect: Rect, inset: number): Rect
	return { x = rect.x, y = rect.y - inset, w = rect.w, h = rect.h }
end

-- Roblox's jump button for a viewport, as TouchGui places it
function HudLayout.jumpRect(viewport: Vector2): Rect
	local spec = if math.min(viewport.X, viewport.Y) <= Hud.Jump.SmallMaxSide then Hud.Jump.Small else Hud.Jump.Large
	return { x = viewport.X - spec.Right, y = viewport.Y - spec.Bottom, w = spec.Size, h = spec.Size }
end

function HudLayout.compute(
	viewport: Vector2, touch: boolean, inset: number?, expanded: boolean?,
	notificationActive: boolean?, rewardNotificationActive: boolean?
): Layout
	local topInset = inset or Hud.TopBarInset
	local activeNotification = notificationActive == true or rewardNotificationActive == true
	local notificationHeight = if rewardNotificationActive then 64 else 48
	local width, height = viewport.X, viewport.Y
	local scale = HudLayout.scale(viewport)
	local portrait = width < height
	local desktop = not touch and not portrait
	local cards = if desktop then Hud.Desktop.LeftCards else Hud.LeftCards
	local timerSpec = if desktop then Hud.Desktop.Timer else Hud.Timer
	local backpackSpec = if desktop then Hud.Desktop.Backpack else Hud.Backpack
	local statusScale = if desktop then math.min(scale,
		(width - (cards.X + backpackSpec.Right) * scale - 12)
			/ (cards.Resources.Width + cards.Production.Width + backpackSpec.Width)) else scale
	local compact = portrait or height < 600
	local buttons: { [string]: Rect } = {}
	local buttonBase = Vector2.new(Hud.Column.Width, Hud.Column.Height)
	local buttonScale = math.max(scale, Hud.MinTouch / Hud.Column.Height)
	local productionHeight = if expanded then cards.Production.ExpandedHeight else cards.Production.Height
	local training = Hud.Training
	local function sized(x: number, y: number, w: number, h: number, s: number): Rect
		return { x = x, y = y, w = w * s, h = h * s }
	end
	local function centred(y: number, w: number, h: number, s: number): Rect
		return sized((width - w * s) / 2, y, w, h, s)
	end
	local timer = centred(if desktop then timerSpec.Top * scale else math.max(topInset + 6, timerSpec.Top * scale),
		timerSpec.Width, timerSpec.Height, scale)
	local resources = sized(cards.X * scale, height - cards.Resources.Bottom * scale - cards.Resources.Height * statusScale,
		cards.Resources.Width, cards.Resources.Height, statusScale)
	local backpack = sized(width - backpackSpec.Right * scale - backpackSpec.Width * statusScale,
		height - backpackSpec.Bottom * scale - backpackSpec.Height * statusScale,
		backpackSpec.Width, backpackSpec.Height, statusScale)
	local production = centred(height - cards.Production.Bottom * scale - productionHeight * statusScale,
		cards.Production.Width, productionHeight, statusScale)
	local eventPanel = sized(width - (Hud.EdgeMargin + Hud.EventPanel.Width) * scale,
		math.max(topInset + 6, Hud.EventPanel.Top * scale), Hud.EventPanel.Width, Hud.EventPanel.Height, scale)
	local tutorial = centred(production.y - (training.Gap + training.Height) * scale, training.Width, training.Height, scale)
	local settings: Rect? = sized(cards.X * scale, topInset + 6, Hud.SettingsSize, Hud.SettingsSize, 1)
	local mine: Rect? = nil
	local jump: Rect? = nil
	local thumbstick: Rect? = nil
	local shortPortrait = false
	local tightPortrait = false
	local phoneLandscape = false
	local fastWalk: Rect? = nil
	local ore: Rect? = nil
	local objective: Rect? = nil
	local timerVisible, resourcesVisible, backpackVisible = true, true, true
	local tightNotification: Rect? = nil
	local function mineForEvent(): Rect?
		if not jump then return nil end
		local size = if math.min(width, height) <= Hud.Jump.SmallMaxSide then Hud.Mine.SmallSize else Hud.Mine.LargeSize
		local room = jump.y - Hud.Mine.Gap - (eventPanel.y + eventPanel.h + Hud.Mine.EventGap)
		size = math.clamp(math.floor(room), Hud.Mine.MinSize, size)
		if thumbstick and jump.y - Hud.Mine.Gap > thumbstick.y then
			local rightRoom = jump.x + jump.w - (thumbstick.x + thumbstick.w) - 8
			size = math.min(size, math.max(Hud.Mine.MinSize, rightRoom))
		end
		return { x = jump.x + jump.w - size, y = jump.y - Hud.Mine.Gap - size, w = size, h = size }
	end
	if touch or portrait then
		local row = Hud.TouchRow
		local navigationHeight = navigationHeight(row.Width, row.Height)
		buttonScale = row.Height / Hud.Column.Height
		-- Daily Rewards and Codes join the row when they fit, with the gaps closed up to 2 px on a narrow phone; a screen
		-- without room for one keeps the Settings rows (and, for Daily, the join popup) as its way in
		local order = table.clone(Hud.ButtonOrder)
		-- (Codes only in portrait: a landscape row that long would push the gear into the clock)
		for _, extra in if portrait then { "DAILY", "CODES" } else { "DAILY" } do
			if width - 24 - (#order + 1) * (row.Width + 2) - Hud.SettingsSize < 0 then break end
			table.insert(order, extra)
		end
		local rowGap = math.clamp((width - 24 - Hud.SettingsSize) / #order - row.Width, 2, row.Gap)
		local navigationWidth = #order * (row.Width + rowGap) + Hud.SettingsSize
		local left = if portrait then (width - navigationWidth) / 2 else 12
		for i, name in order do
			buttons[name] = { x = left + (i - 1) * (row.Width + rowGap), y = topInset + row.Top, w = row.Width, h = row.Height }
		end
		settings = sized(left + #order * (row.Width + rowGap), topInset + row.Top,
			Hud.SettingsSize, Hud.SettingsSize, 1)
		if touch then
			jump = HudLayout.jumpRect(viewport)
			thumbstick = { x = 0, y = height - Hud.Thumbstick.Height, w = Hud.Thumbstick.Width, h = Hud.Thumbstick.Height }
			if not portrait then
				-- The native small-phone joystick is a 74 px circle near the bottom
				-- left (29, height - 94 in the 844x390 emulator). Protect its travel
				-- area rather than reserving a 220 px square over the left navigation.
				local small = math.min(width, height) <= Hud.Jump.SmallMaxSide
				thumbstick = { x = 0, y = height - (if small then 156 else Hud.Thumbstick.Height),
					w = if small then 160 else Hud.Thumbstick.Width, h = if small then 156 else Hud.Thumbstick.Height }
			end
		end
		if portrait then
			local timerScale = math.min(scale, (width - 24) / Hud.Timer.Width)
			local navigationGap = 6
			if touch and expanded and thumbstick then
				-- Even a notched 487 px phone retains a 48 px notice and two 44 px
				-- foundry controls after the authored caption, with a 2 px separator.
				navigationGap = math.min(navigationGap, math.max(0,
					thumbstick.y - 2 - (topInset + row.Top + navigationHeight) - 48 - 2 - 2 * Hud.MinTouch))
			end
			timer = centred(topInset + row.Top + navigationHeight + navigationGap, Hud.Timer.Width, Hud.Timer.Height, timerScale)
			eventPanel = centred(timer.y + timer.h + 6, Hud.EventPanel.Width, Hud.EventPanel.Height, 0.6)
			tutorial = centred(eventPanel.y + eventPanel.h + 6, training.Width, training.Height, 0.75)
			local limit = if thumbstick then thumbstick.y else height
			local stackedSummaryBottom = tutorial.y + tutorial.h + 6 + cards.Resources.Height * 0.6 + 6 + Hud.MinTouch
			local stackedDetailsBottom = eventPanel.y + eventPanel.h + 6 + cards.Resources.Height * 0.6 + 6
				+ cards.Production.ExpandedHeight * Hud.MinTouch / cards.Production.Height
			shortPortrait = touch and math.max(stackedSummaryBottom, stackedDetailsBottom) > limit - 6
			if shortPortrait then
				-- On short portrait phones, use the width alongside the objective and
				-- foundry rather than shrinking a vertical stack below usable targets.
				eventPanel = sized(12, timer.y + timer.h + 6, Hud.EventPanel.Width, Hud.EventPanel.Height, 0.55)
				local backpackScale = math.min(0.65, (width - 24 - eventPanel.w - 6) / Hud.Backpack.Width)
				backpack = sized(eventPanel.x + eventPanel.w + 6, eventPanel.y,
					Hud.Backpack.Width, Hud.Backpack.Height, backpackScale)
				tutorial = centred(eventPanel.y + eventPanel.h + 6, training.Width, training.Height, 0.75)
				local detailsY = eventPanel.y + eventPanel.h + 6
				local productionScale = math.min(0.6, (limit - 2 - detailsY) / cards.Production.ExpandedHeight,
					(width - 24 - 6 - 90) / cards.Production.Width)
				local rowY = if expanded then detailsY else tutorial.y + tutorial.h + 6
				-- the wallet takes the rest of the row, but no taller than the stack has room for
				local walletScale = math.min(PortraitWalletMax, (width - 24 - 6 - cards.Production.Width * productionScale) / cards.Resources.Width)
				local minimumProductionScale = Hud.MinTouch / cards.Production.Height
				local minimumWalletScale = math.min(PortraitWalletMax, (width - 24 - 6 - cards.Production.Width * minimumProductionScale) / cards.Resources.Width)
				if productionScale < minimumProductionScale
					and detailsY + 2 * Hud.MinTouch <= limit - 2
					and tutorial.y + tutorial.h + 6 + math.max(Hud.MinTouch, cards.Resources.Height * minimumWalletScale) <= limit - 2 then
					-- A medium phone still fits its guide, summary and close control.
					-- Let expanded details scroll rather than hiding those useful cards.
					productionScale = minimumProductionScale
					walletScale = minimumWalletScale
				end
				if productionScale < minimumProductionScale then
					-- The smallest portrait cannot hold the full objective/training stack.
					-- Preserve navigation and the foundry target, then use only card slots
					-- that fit above movement. Expanded details scroll within the remaining
					-- height; their scale and the fixed summary never shrink below 44 px.
					tightPortrait = true
					productionScale = minimumProductionScale
					local top = timer.y
					local bottom = limit - 2
					local sideWidth = (width - 30) / 2
					resources = sized(12, timer.y + timer.h + 6,
						cards.Resources.Width, cards.Resources.Height, sideWidth / cards.Resources.Width)
					backpack = sized(resources.x + resources.w + 6, resources.y,
						Hud.Backpack.Width, Hud.Backpack.Height, sideWidth / Hud.Backpack.Width)
						if expanded then
							resourcesVisible, backpackVisible = false, false
							timer = centred(top, Hud.Timer.Width, Hud.Timer.Height, math.min(0.4, timerScale))
							timerVisible = not activeNotification and bottom - top - timer.h - 6 >= 2 * Hud.MinTouch
							local headerHeight = if activeNotification then 48 elseif timerVisible then timer.h else 0
							if activeNotification then tightNotification = sized(12, top, width - 24, 48, 1) end
							local headerGap = if activeNotification then 2 else 6
							production = centred(top + headerHeight + headerGap, cards.Production.Width, productionHeight, productionScale)
						production.h = math.min(production.h, bottom - production.y)
					else
						local summaryHeight = cards.Production.Height * productionScale
						if activeNotification then
							timerVisible = false
							tightNotification = sized(12, top, width - 24, notificationHeight, 1)
							top += notificationHeight + 6
						elseif top + timer.h + 6 + resources.h + 6 + summaryHeight <= bottom then
							top += timer.h + 6
						else
							timerVisible = false
						end
						-- Leave a header and ore row above the backpack anchor. When the
						-- viewport cannot hold that anchor, keep the wallet and hide the
						-- backpack rather than breaking its attached popup.
							local backpackTop = topInset + row.Top + navigationHeight + BackpackPopupGap
							+ BackpackPopupMinHeight + BackpackPopupGap
						local anchoredTop = math.max(top, backpackTop)
						if anchoredTop + resources.h + 6 + summaryHeight <= bottom then
							top = anchoredTop
						else
							backpackVisible = false
						end
						resources.y, backpack.y = top, math.max(top, backpackTop)
						if top + resources.h + 6 + summaryHeight <= bottom then
							top += resources.h + 6
						else
							resourcesVisible, backpackVisible = false, false
						end
						production = centred(top, cards.Production.Width, productionHeight, productionScale)
					end
				elseif expanded then
					production = sized(12, rowY, cards.Production.Width, productionHeight, productionScale)
					production.h = math.min(production.h, limit - 2 - production.y)
					resources = sized(production.x + production.w + 6, rowY,
						cards.Resources.Width, cards.Resources.Height, walletScale)
					if activeNotification then
						backpack = sized(resources.x, resources.y + resources.h + 6,
							Hud.Backpack.Width, Hud.Backpack.Height, resources.w / Hud.Backpack.Width)
					end
				else
					resources = sized(12, rowY, cards.Resources.Width, cards.Resources.Height, walletScale)
					production = sized(resources.x + resources.w + 6, rowY,
						cards.Production.Width, productionHeight, productionScale)
				end
			else
				local rowY = if expanded and touch then eventPanel.y + eventPanel.h + 6 else tutorial.y + tutorial.h + 6
				local walletScale, backpackScale = 0.6, 0.7
				local rowWidth = cards.Resources.Width * walletScale + 6 + Hud.Backpack.Width * backpackScale
				resources = sized((width - rowWidth) / 2, rowY, cards.Resources.Width, cards.Resources.Height, walletScale)
				backpack = sized(resources.x + resources.w + 6, rowY, Hud.Backpack.Width, Hud.Backpack.Height, backpackScale)
				local productionY = rowY + math.max(resources.h, backpack.h) + 6
				local productionScale = math.min(if expanded then 0.75 else 0.8, (width - 24) / cards.Production.Width,
					(limit - 6 - productionY) / productionHeight)
				production = centred(productionY, cards.Production.Width, productionHeight, productionScale)
			end
		elseif compact then
			-- Phones in landscape (the owner's 10 October layout): Gear, Index and Rebirth across the top left with
			-- Pets and Store down the left edge, settings in the top bar's right corner, the clock centred in the top
			-- bar, ORE and SPRINT stacked on the right above MINE and jump, the wallet (with the level above it) in
			-- the bottom-left corner over the joystick area (it takes no touches, so the stick still works through
			-- it), the foundry centred at the bottom with training above it, and the backpack bottom right, beside
			-- the jump button.
			phoneLandscape = true
			local reservedThumb = thumbstick :: Rect
			local reservedJump = jump :: Rect
			local lTop = math.max(topInset, math.min(topInset + row.Top, reservedThumb.y - 3 * navigationHeight - 4))
			local navGap = math.max(0, math.min(2, (reservedThumb.y - lTop - 3 * navigationHeight) / 2))
			local rowRight
			local rowBottom: number? = nil -- set when the five buttons run in one row across the top
			if lTop + 3 * navigationHeight + 2 * navGap <= reservedThumb.y then
				for i, name in { "SHOP", "INDEX", "REBIRTH" } do
					buttons[name] = { x = 12 + (i - 1) * (row.Width + row.Gap), y = lTop, w = row.Width, h = row.Height }
				end
				buttons.PETS = { x = 12, y = lTop + navigationHeight + navGap, w = row.Width, h = row.Height }
				-- Daily Rewards sits beside Pets, under Index, and Codes beside Store
				buttons.DAILY = { x = 12 + (row.Width + row.Gap), y = lTop + navigationHeight + navGap, w = row.Width, h = row.Height }
				buttons.CODES = { x = 12 + (row.Width + row.Gap), y = lTop + 2 * (navigationHeight + navGap), w = row.Width, h = row.Height }
				buttons.STORE = { x = 12, y = lTop + 2 * (navigationHeight + navGap), w = row.Width, h = row.Height }
				-- (the Offers fill the two free cells under Rebirth, see HudLayout.offerSlots)
				rowRight = 12 + 3 * (row.Width + row.Gap) - row.Gap
			elseif math.max(topInset, math.min(topInset + row.Top, reservedThumb.y - 2 * navigationHeight - 2)) + 2 * navigationHeight + 2 <= reservedThumb.y then
				-- smaller phones: too short for the column above the joystick, so two lines instead: Gear, Index and
				-- Rebirth, then Pets, Store and Daily under them
				local top = math.max(topInset, math.min(topInset + row.Top, reservedThumb.y - 2 * navigationHeight - 2))
				for i, name in { "SHOP", "INDEX", "REBIRTH", "PETS", "STORE", "DAILY" } do
					local column, line = (i - 1) % 3, (i - 1) // 3
					buttons[name] = { x = 12 + column * (row.Width + row.Gap), y = top + line * (navigationHeight + 2), w = row.Width, h = row.Height }
				end
				rowRight = 12 + 3 * (row.Width + row.Gap) - row.Gap
			else
				-- too short even for two lines above the joystick: all six across the top instead (Codes waits for Settings)
				local navTop = math.max(topInset, math.min(topInset + row.Top, reservedThumb.y - navigationHeight))
				for i, name in { "SHOP", "INDEX", "REBIRTH", "PETS", "STORE", "DAILY" } do
					buttons[name] = { x = 12 + (i - 1) * (row.Width + row.Gap), y = navTop, w = row.Width, h = row.Height }
				end
				rowRight = 12 + 6 * (row.Width + row.Gap) - row.Gap
				rowBottom = navTop + navigationHeight
			end
			settings = sized(width - 12 - Hud.SettingsSize, math.max(2, topInset - Hud.SettingsSize - 2),
				Hud.SettingsSize, Hud.SettingsSize, 1)
			local settingsRect = settings :: Rect
			-- the clock: centred in the top bar, clear of Roblox's buttons on the left, the menu row and the gear
			local leftLimit = math.max(PhoneClockLeft, rowRight + 8)
			local half = math.min(width / 2 - leftLimit, settingsRect.x - 8 - width / 2)
			local timerScale = math.min(scale, PhoneClockScale, 2 * half / Hud.Timer.Width)
			timer = centred(math.max(4, topInset - Hud.Timer.Height * timerScale + 6), Hud.Timer.Width, Hud.Timer.Height, timerScale)
			-- the objective card only shows when the clock is hidden; keep its slot under the clock
			eventPanel = centred(timer.y + timer.h + 6, Hud.EventPanel.Width, Hud.EventPanel.Height, 0.5)
			-- SPRINT with ORE above it, right-aligned with jump, below the gear; MINE fills the gap down to jump
			local side = Hud.SideButtons
			local columnTop = math.max(topInset + 6, settingsRect.y + settingsRect.h + 6)
			local right = reservedJump.x + reservedJump.w
			local sprint = { x = right - side.Size, y = columnTop + side.Size + side.Gap, w = side.Size, h = side.Size }
			local mineSize = math.clamp(math.floor(reservedJump.y - Hud.Mine.Gap - (sprint.y + sprint.h + Hud.Mine.EventGap)),
				Hud.Mine.MinSize, if math.min(width, height) <= Hud.Jump.SmallMaxSide then Hud.Mine.SmallSize else Hud.Mine.LargeSize)
			mine = { x = right - mineSize, y = reservedJump.y - Hud.Mine.Gap - mineSize, w = mineSize, h = mineSize }
			if sprint.y + sprint.h > (mine :: Rect).y then
				-- no room above MINE: the pair moves in beside it
				sprint.x = (mine :: Rect).x - 8 - side.Size
			end
			fastWalk = sprint
			-- the bottom: wallet in the corner, foundry in the middle, backpack beside the jump button
			local bottom = height - 6
			resources = sized(12, bottom - cards.Resources.Height * PhoneWalletScale, cards.Resources.Width, cards.Resources.Height, PhoneWalletScale)
			local productionScale = if expanded then math.min(0.6, (bottom - (timer.y + timer.h + 6)) / productionHeight) else 0.6
			production = centred(bottom - productionHeight * productionScale, cards.Production.Width, productionHeight, productionScale)
			local backpackScale = math.min(0.65, (reservedJump.x - 8 - (production.x + production.w + 8)) / Hud.Backpack.Width)
			backpack = sized(reservedJump.x - 8 - Hud.Backpack.Width * backpackScale, bottom - Hud.Backpack.Height * backpackScale,
				Hud.Backpack.Width, Hud.Backpack.Height, backpackScale)
			tutorial = centred(production.y - 6 - training.Height * Hud.TouchCardScale, training.Width, training.Height, Hud.TouchCardScale)
			-- the clock (and the objective it turns into while a meteor is down) comes out of the top bar, larger,
			-- between the menu row and the ORE column and above training (the open foundry keeps it in the bar)
			if not expanded then
				local objectiveRight = math.min(sprint.x, right - side.Size) - 12
				local function fit(left: number, top: number): number
					return math.min(PhoneObjectiveScale, 2 * math.min(width / 2 - left, objectiveRight - width / 2) / Hud.Timer.Width,
						(tutorial.y - 4 - top) / Hud.Timer.Height)
				end
				-- beside the menu row, or under it when the row runs all the way across (short phones)
				local objectiveTop = topInset + 4
				local objectiveScale = fit(rowRight + 12, objectiveTop)
				local underRow = false
				if objectiveScale <= timerScale and rowBottom then
					objectiveTop = rowBottom + 4
					objectiveScale = fit(12, objectiveTop)
					underRow = true
				end
				if objectiveScale > timerScale then
					-- the owner's placement: a fifth of the way down from the clock's spot in the top bar, so it rides
					-- high and may brush Roblox's chat button (under a full-width menu row it stays put)
					if not underRow then objectiveTop = timer.y + PhoneObjectiveDrop * (objectiveTop - timer.y) end
					objective = centred(objectiveTop, Hud.Timer.Width, Hud.Timer.Height, objectiveScale)
				end
			end
		else
			timer.y = topInset + row.Top
			resources = sized(12, topInset + row.Top + navigationHeight + 6, cards.Resources.Width, cards.Resources.Height, scale)
			eventPanel = sized(width - 12 - Hud.EventPanel.Width * scale, topInset + row.Top,
				Hud.EventPanel.Width, Hud.EventPanel.Height, scale)
			backpack = sized(width - 12 - Hud.Backpack.Width * scale, eventPanel.y + eventPanel.h + 6,
				Hud.Backpack.Width, Hud.Backpack.Height, scale)
		end
		if not phoneLandscape then mine = mineForEvent() end
	else
		-- Roblox's menu button ends two pixels above the bottom of its top row.
		-- Match that edge rather than centring in the entire inset strip.
		settings = sized(width - Hud.EdgeMargin * scale - Hud.SettingsSize,
			math.max(2, topInset - Hud.SettingsSize - 2), Hud.SettingsSize, Hud.SettingsSize, 1)
		if HudLayout.overlaps(timer, eventPanel) then eventPanel.y = timer.y + timer.h + 8 end
		if expanded then
			-- The framed plot tag sits ten units under the clock and is forty high.
			-- Keep the guide and expanded foundry below that shared header.
			local headerBottom = timer.y + timer.h + 50 * scale
			local available = height - cards.Production.Bottom * scale - headerBottom - 8
				- (training.Height + training.Gap) * scale
			local productionScale = math.min(statusScale, available / productionHeight)
			production = centred(height - cards.Production.Bottom * scale - productionHeight * productionScale,
				cards.Production.Width, productionHeight, productionScale)
			tutorial = centred(production.y - (training.Height + training.Gap) * scale, training.Width, training.Height, scale)
		end
		buttonScale *= Hud.Desktop.ButtonScale
		-- Short windows shrink the tiles so the whole column still fits between the top bar and the wallet
		local niceScale = buttonScale
		local function fitted(count: number): number
			local fit = (resources.y - 8 - (topInset + 6)) / (count * Hud.Column.Height * NavigationCaptionBottom / NavigationFaceSize)
			return math.max(Hud.MinTouch / Hud.Column.Height, math.min(niceScale, fit))
		end
		-- The right-hand stack: Daily Rewards above Index, Codes under it, below the gear and leaving the ore popup
		-- above the backpack three rows. Whatever does not fit ends the left column instead (Codes first). The
		-- objective card is not counted: with the clock shown (always, on desktop) the clock carries the objective
		-- and the card is never drawn.
		local stackFloor = math.max(topInset + 6, if settings then settings.y + settings.h + 8 else 0)
		local function stackIndexY(candidate: number, daily: boolean, codes: boolean): number?
			local face = navigationHeight(Hud.Column.Width * candidate, Hud.Column.Height * candidate)
			local lowest = stackFloor + (if daily then face + 2 else 0)
			local highest = backpack.y - 2 * BackpackPopupGap - BackpackPopupDailyHeight - face - (if codes then face + 2 else 0)
			if lowest > highest then return nil end
			return math.clamp(height * 0.48 - Hud.Column.Height * candidate / 2, lowest, highest)
		end
		local order = table.clone(Hud.DesktopButtonOrder)
		local stackDaily, stackCodes = true, true
		if not stackIndexY(fitted(#order), true, true) then stackCodes = false end
		if not stackCodes and not stackIndexY(fitted(#order), true, false) then stackDaily = false end
		if not stackDaily then table.insert(order, "DAILY") end
		if not stackCodes then table.insert(order, "CODES") end
		-- ORE is a tile in the column, straight under STORE (taken back out of `buttons` below), when the column still
		-- fits at the smallest tile size; a window too short for it leaves ORE to sit above SPRINT
		local roomy = (resources.y - 8 - (topInset + 6)) / ((#order + 1) * Hud.Column.Height * NavigationCaptionBottom / NavigationFaceSize)
		if roomy >= Hud.MinTouch / Hud.Column.Height then
			table.insert(order, (table.find(order, "STORE") or #order) + 1, "ORE")
		end
		buttonScale = fitted(#order)
		local columnHeight = navigationHeight(Hud.Column.Width * buttonScale, Hud.Column.Height * buttonScale)
		local columnTop = math.min(Hud.Column.Top * scale,
			resources.y - #order * columnHeight - (#order - 1) * Hud.Column.Gap * buttonScale - 8)
		local buttonY = columnTop
		for _, name in order do
			buttons[name] = {
				x = Hud.Column.Left * scale,
				y = buttonY,
				w = Hud.Column.Width * buttonScale,
				h = Hud.Column.Height * buttonScale,
			}
			-- Reuse the exact prior edge: separately multiplied fractional offsets
			-- can round a touching pair into an apparent sub-pixel overlap.
			buttonY = buttons[name].y + columnHeight + Hud.Column.Gap * buttonScale
		end
		ore, buttons.ORE = buttons.ORE, nil
		local indexTop = if stackDaily then stackIndexY(buttonScale, stackDaily, stackCodes) else nil
		-- the right stack mirrors the left column's margin (Column.Left × scale), not a margin shrunk with the tiles
		buttons.INDEX = sized(width - Hud.Column.Left * scale - Hud.Column.Width * buttonScale,
			indexTop or math.max(height * 0.48 - Hud.Column.Height * buttonScale / 2, eventPanel.y + eventPanel.h + 8),
			Hud.Column.Width, Hud.Column.Height, buttonScale)
		local index = buttons.INDEX
		local indexHeight = navigationHeight(index.w, index.h)
		if stackDaily then
			buttons.DAILY = { x = index.x, y = index.y - indexHeight - 2, w = index.w, h = index.h }
			if stackCodes then buttons.CODES = { x = index.x, y = index.y + indexHeight + 2, w = index.w, h = index.h } end
			-- the objective card is only a fallback for a hidden clock and is never drawn here; should it ever be, it
			-- sits beside the stack instead of behind it
			eventPanel.x = math.min(eventPanel.x, index.x - eventPanel.w - 8)
		elseif backpack.y - (index.y + indexHeight) - 2 * BackpackPopupGap < BackpackPopupMinHeight then
			-- Short desktop windows need the Index above the attached ore popup.
			-- Keep its full authored caption, then place the objective underneath.
			index.y = math.max(topInset + 6, settings.y + settings.h + 8)
			eventPanel.y = math.max(eventPanel.y, index.y + indexHeight + 8)
		end
		-- SPRINT runs in line with the backpack, on its left, leaving the right edge to the menu stack. A window so
		-- narrow that it would reach the foundry leaves it to place itself above the backpack instead.
		local side = Hud.SideButtons
		local sprintSpot = { x = backpack.x - 8 - side.Size, y = backpack.y + (backpack.h - side.Size) / 2, w = side.Size, h = side.Size }
		if not HudLayout.overlaps(sprintSpot, production) and not HudLayout.overlaps(sprintSpot, tutorial) then
			fastWalk = sprintSpot
		end
	end
	local offers = if touch or portrait then HudLayout.offerSlots(buttons, width, height, {
		settings, if timerVisible then timer else nil, objective, eventPanel, mine, jump, fastWalk, ore, production, tutorial,
		-- the thumbstick's reserve reaches well above the stick itself: a cell may graze its top edge
		if thumbstick then { x = thumbstick.x, y = thumbstick.y + 4, w = thumbstick.w, h = thumbstick.h - 4 } else nil,
		if backpackVisible then backpack else nil, if resourcesVisible then resources else nil,
		if fastWalk and not ore then { x = fastWalk.x, y = fastWalk.y - Hud.SideButtons.Size - Hud.SideButtons.Gap,
			w = fastWalk.w, h = Hud.SideButtons.Size } else nil, -- ORE above SPRINT
	}) else {}
	-- Notifications use real pixels, independent of card scale. The reward line
	-- needs two rows; tight expanded screens temporarily reserve the event slot
	-- instead of shrinking the text into movement controls or the foundry.
	local notification = tightNotification or centred(timer.y + timer.h + (if desktop then 50 * scale else 0) + 8,
		math.min(400, width - 24), notificationHeight, 1)
	local eventVisible = not tightPortrait and not (activeNotification and touch and portrait and expanded == true)
	if phoneLandscape then
		-- a notice takes the training card's place, or sits under the clock while the foundry is open; it stays
		-- between the left menu column and the ORE / SPRINT / MINE column
		local obstacles: { Rect } = { resources, backpack, thumbstick :: Rect, jump :: Rect, mine :: Rect }
		if fastWalk then
			table.insert(obstacles, fastWalk)
			table.insert(obstacles, { x = fastWalk.x, y = fastWalk.y - Hud.SideButtons.Size - Hud.SideButtons.Gap,
				w = fastWalk.w, h = Hud.SideButtons.Size }) -- ORE
		end
		for _, button in buttons do
			table.insert(obstacles, { x = button.x, y = button.y, w = button.w, h = navigationHeight(button.w, button.h) })
		end
		for _, offer in offers do table.insert(obstacles, offer) end
		-- the widest centred banner at y that stays clear of everything on either side of it
		local function place(y: number): Rect
			local left, right = 12, width - 12
			for _, o in obstacles do
				if o.y < y + notificationHeight + 2 and y - 2 < o.y + o.h then
					if o.x + o.w / 2 < width / 2 then left = math.max(left, o.x + o.w + 8) else right = math.min(right, o.x - 8) end
				end
			end
			local w = math.min(400, 2 * math.min(width / 2 - left, right - width / 2))
			return { x = (width - w) / 2, y = y, w = w, h = notificationHeight }
		end
		notification = place(if expanded then eventPanel.y else tutorial.y)
		if notification.w < 190 then
			-- the menu row reaches the clock on narrow phones: drop below its captions instead
			local below = 0
			for _, button in buttons do below = math.max(below, button.y + navigationHeight(button.w, button.h) + 4) end
			notification = place(below)
		end
		if expanded then
			eventVisible = false -- the open foundry reaches up to the clock
			if activeNotification and production.y < notification.y + notification.h + 6 then
				-- the open foundry scrolls under the notice rather than sliding beneath it
				local productionBottom = production.y + production.h
				production.y = notification.y + notification.h + 6
				production.h = productionBottom - production.y
			end
		end
	elseif portrait then
		if not tightPortrait then notification.y = if touch and expanded then eventPanel.y else tutorial.y end
	elseif notification.y < eventPanel.y + eventPanel.h and eventPanel.y < notification.y + notification.h then
		-- Preserve a centred banner while shortening it before the right objective.
		notification.w = math.min(notification.w, 2 * (eventPanel.x - 8 - width / 2))
		notification.x = (width - notification.w) / 2
	end
	local tutorialVisible = not tightPortrait and not (touch and expanded == true)
		and not (activeNotification and HudLayout.overlaps(notification, tutorial))
	return {
		viewport = viewport, touch = touch, inset = topInset, scale = scale, compact = compact, portrait = portrait,
		buttons = buttons, buttonBase = buttonBase, buttonScale = buttonScale,
		buttonTextSize = if touch or portrait then Hud.TouchRow.TextSize else nil, timer = timer, timerVisible = timerVisible,
		leftCards = { Resources = resources, Equipment = buttons.SHOP, Production = production },
		resourcesVisible = resourcesVisible,
		leftScale = scale, eventPanel = eventPanel, tutorial = tutorial,
		tutorialVisible = tutorialVisible, backpack = backpack, backpackVisible = backpackVisible, settings = settings,
		notification = notification, notificationCompact = notification.h < 40, eventVisible = eventVisible,
		tutorialY = tutorial.y - topInset, mine = mine, jump = jump, thumbstick = thumbstick, fastWalk = fastWalk, ore = ore,
		levelAbove = phoneLandscape, objective = objective, offers = offers,
		topBar = { x = 0, y = 0, w = width, h = topInset },
	}
end

-- Touch and portrait: up to Hud.OfferSlots cells for the Offers buttons (2x Ore, 2x Cash, Starter Pack), in line
-- with the menu buttons. The menu buttons sit on a grid; the empty cells inside it come first (row by row) and,
-- when they all take an offer, are all the slots (the rest wait until one is bought). Otherwise a column to the right of it, then the rows under it (portrait phones: under the clock, beside the event card),
-- where the slots stay one block of touching cells. A cell that leaves the screen or touches any of `blockers`
-- (nil entries are skipped) is passed over.
function HudLayout.offerSlots(buttons: { [string]: Rect }, width: number, height: number, blockers: { Rect? }): { Rect }
	local row = Hud.TouchRow
	local xs, ys = {}, {}
	local function add(list: { number }, value: number)
		for _, v in list do
			if math.abs(v - value) < 0.5 then return end
		end
		table.insert(list, value)
	end
	for _, button in buttons do
		add(xs, button.x)
		add(ys, button.y)
	end
	if #xs == 0 then return {} end
	table.sort(xs)
	table.sort(ys)
	local stepX = if #xs > 1 then xs[2] - xs[1] else row.Width + row.Gap
	local stepY = if #ys > 1 then ys[2] - ys[1] else navigationHeight(row.Width, row.Height) + row.Gap
	local cells: { Rect } = {}
	local function cell(x: number, y: number): Rect
		return { x = x, y = y, w = row.Width, h = row.Height }
	end
	for _, y in ys do
		for _, x in xs do
			local taken = false
			for _, button in buttons do
				if math.abs(button.x - x) < 0.5 and math.abs(button.y - y) < 0.5 then taken = true break end
			end
			if not taken then table.insert(cells, cell(x, y)) end
		end
	end
	local holes = #cells
	for _, y in ys do table.insert(cells, cell(xs[#xs] + stepX, y)) end
	for line = 1, math.ceil(height / stepY) do
		for _, x in xs do table.insert(cells, cell(x, ys[#ys] + line * stepY)) end
	end
	local slots: { Rect } = {}
	local below: { Rect } = {} -- the slots taken under the grid, which must stay one block
	local function touching(a: Rect, b: Rect): boolean
		local dx, dy = math.abs(a.x - b.x), math.abs(a.y - b.y)
		return (dy < 0.5 and math.abs(dx - stepX) < 0.5) or (dx < 0.5 and math.abs(dy - stepY) < 0.5)
	end
	for i, candidate in cells do
		-- once the offers have filled the grid's gaps it is a clean rectangle: stop rather than grow a ragged edge
		if #slots >= Hud.OfferSlots or (i > holes and #slots > 0 and #slots == holes) then break end
		local under = candidate.y > ys[#ys] + 0.5
		local clear = candidate.x >= 0 and candidate.y >= 0 and candidate.x + candidate.w <= width - 6
			and candidate.y + navigationHeight(candidate.w, candidate.h) <= height
		for _, button in buttons do
			if clear and HudLayout.overlaps(candidate, button) then clear = false end
		end
		for j = 1, 16 do
			local blocker = blockers[j]
			if clear and blocker and HudLayout.overlaps(candidate, blocker) then clear = false end
		end
		if clear and under and #below > 0 then
			clear = false
			for _, other in below do
				if touching(candidate, other) then clear = true break end
			end
		end
		if clear then
			table.insert(slots, candidate)
			if under then table.insert(below, candidate) end
		end
	end
	return slots
end

-- An ore list attached above the backpack HUD. These are screen pixels: the
-- renderer keeps text and rows readable instead of applying the HUD's scale.
-- Match the anchor's width and fit up to six rows (ore, then carried bars) beneath
-- the header. High anchors shrink the height and the rows shrink to fit.
function HudLayout.backpackPanel(layout: Layout, rowCount: number?): Rect
	local margin, gap = 12, BackpackPopupGap
	local visibleRows = math.clamp(math.floor(rowCount or 3), 1, 6)
	local maxHeight, minHeight = 40 + 28 * visibleRows + 4, BackpackPopupMinHeight
	local viewport, anchor = layout.viewport, layout.backpack
	local safeWidth = math.max(1, viewport.X - 2 * margin)
	local right = math.clamp(anchor.x + anchor.w, margin + 1, math.max(margin + 1, viewport.X - margin))
	local width = math.min(anchor.w, safeWidth, right - margin)
	local x = right - width
	local top = layout.inset + margin
	local function clearNavigation(rect: Rect, caption: boolean?)
		-- Touch and portrait use one navigation row. Desktop only reserves
		-- buttons that share the popup's horizontal span (usually INDEX).
		if layout.touch or layout.portrait or (x < rect.x + rect.w and rect.x < x + width) then
			top = math.max(top, rect.y + (if caption then navigationHeight(rect.w, rect.h) else rect.h) + gap)
		end
	end
	for _, button in layout.buttons do clearNavigation(button, true) end
	if layout.settings then clearNavigation(layout.settings) end
	if not layout.touch and not layout.portrait and layout.eventVisible then
		clearNavigation(layout.eventPanel)
	end
	local screenBottom = viewport.Y - margin
	local bottom = math.min(anchor.y - gap, screenBottom)
	local availableAbove = bottom - top
	if availableAbove >= minHeight then
		local height = math.min(maxHeight, availableAbove)
		return { x = x, y = bottom - height, w = width, h = height }
	end
	-- A moved or unusually high anchor can leave no usable room above. Keep
	-- the panel visible below navigation with a header and row where possible.
	local height = math.min(minHeight, math.max(1, screenBottom - top))
	return { x = x, y = top, w = width, h = height }
end

-- The standalone level badge (mouse layouts): top-left under the Roblox top
-- bar, shrunk to stay clear of the clock. nil when it cannot fit beside the
-- navigation, so the wallet card shows the level instead.
function HudLayout.level(layout: Layout): Rect?
	if layout.touch or layout.portrait then return nil end
	local spec = Hud.Level
	local x = Hud.Desktop.LeftCards.X * layout.scale
	local s = math.min(layout.scale, (layout.timer.x - 8 - x) / spec.Width)
	if spec.Height * s < spec.MinHeight then return nil end
	local rect = { x = x, y = layout.inset + spec.Top * layout.scale, w = spec.Width * s, h = spec.Height * s }
	local blockers = { layout.timer, layout.eventPanel, layout.leftCards.Resources, layout.backpack, layout.notification }
	if layout.settings then table.insert(blockers, layout.settings) end
	for _, button in layout.buttons do
		table.insert(blockers, { x = button.x, y = button.y, w = button.w, h = navigationHeight(button.w, button.h) })
	end
	for _, other in blockers do
		if HudLayout.overlaps(rect, other) then return nil end
	end
	return rect
end

-- A centred panel (shop, index, rebirth, store) of `baseWidth` x `baseHeight` unscaled
-- units. It is scaled down to fit the height under the top bar and to stay
-- SideMargin from each side; `width` is the unscaled width to give the Frame (so that
-- width * scale fits), `rect` where it ends up on screen. The frame is centred in the
-- space below the top bar (Position y offset = inset / 2 on an IgnoreGuiInset gui).
function HudLayout.panel(
	viewport: Vector2,
	baseWidth: number,
	baseHeight: number,
	inset: number?
): { scale: number, width: number, rect: Rect }
	local topInset = inset or Hud.TopBarInset
	local margin = Hud.Panel.Margin
	local scale = math.min(1, math.max(Hud.Panel.MinScale, (viewport.Y - topInset - 2 * margin) / baseHeight))
	local width = math.min(baseWidth, (viewport.X - 2 * Hud.Panel.SideMargin) / scale)
	local w, h = width * scale, baseHeight * scale
	return {
		scale = scale,
		width = width,
		rect = {
			x = (viewport.X - w) / 2,
			y = viewport.Y / 2 + topInset / 2 - h / 2,
			w = w,
			h = h,
		},
	}
end

-- A close button drawn at least Hud.MinTouch px on screen inside a panel scaled by
-- `panelScale`: the unscaled size to give it
function HudLayout.closeSize(baseSize: number, panelScale: number): number
	return math.max(baseSize, Hud.MinTouch / panelScale)
end

-- Config.HudEdit on top of the automatic layout: moves, resizes and hides the named elements. Pure, so the specs can
-- check it. Elements are named as in Config/HudEdit.luau; names it does not know are ignored.
local OFFSCREEN = -4000

local function nudged(rect: Rect, nudge: Nudge?): Rect
	if not nudge then return rect end
	local s = nudge.scale or 1
	return { x = rect.x + (nudge.x or 0), y = rect.y + (nudge.y or 0), w = rect.w * s, h = rect.h * s }
end

-- Where `rect` ends up for `name`, for callers that place an element themselves (the level badge).
function HudLayout.nudged(layout: Layout, name: string, rect: Rect): Rect
	return nudged(rect, if layout.nudge then layout.nudge[name] else nil)
end

function HudLayout.isHidden(layout: Layout, name: string): boolean
	return layout.hidden ~= nil and layout.hidden[name] == true
end

function HudLayout.applyEdits(layout: Layout, edits: Edits): Layout
	local hidden: { [string]: boolean } = {}
	for _, name in edits.Hidden or {} do hidden[name] = true end
	local nudge: { [string]: Nudge } = edits.Nudge or {}
	local result: any = table.clone(layout)
	result.hidden, result.nudge = hidden, nudge
	local function move(rect: Rect, name: string): Rect
		if hidden[name] then return { x = OFFSCREEN, y = OFFSCREEN, w = rect.w, h = rect.h } end
		return nudged(rect, nudge[name])
	end
	local cards = table.clone(layout.leftCards)
	cards.Resources = nudged(cards.Resources, nudge.Wallet)
	cards.Production = nudged(cards.Production, nudge.Foundry)
	result.leftCards = cards
	result.resourcesVisible = layout.resourcesVisible and not hidden.Wallet
	result.backpack = nudged(layout.backpack, nudge.Backpack)
	result.backpackVisible = layout.backpackVisible and not hidden.Backpack
	result.timer = nudged(layout.timer, nudge.Timer)
	result.timerVisible = layout.timerVisible and not hidden.Timer
	result.eventPanel = nudged(layout.eventPanel, nudge.EventPanel)
	result.eventVisible = layout.eventVisible and not hidden.EventPanel
	result.notification = nudged(layout.notification, nudge.Toast)
	local buttons = table.clone(layout.buttons)
	for name, rect in buttons do buttons[name] = move(rect, name) end
	result.buttons = buttons
	if layout.settings then result.settings = move(layout.settings, "Settings") end
	return result :: Layout
end

return HudLayout
