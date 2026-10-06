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
local NavigationFaceSize, NavigationCaptionBottom = 80, 105

-- The personal navigation art has an 80 px face and a caption ending at y=105.
-- Keep the face's touch rect unchanged while reserving the caption below it.
local function navigationHeight(width: number, height: number): number
	return math.max(height, width * NavigationCaptionBottom / NavigationFaceSize)
end

export type Rect = { x: number, y: number, w: number, h: number }

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
	jump: Rect?, -- Roblox's jump button (touch only)
	thumbstick: Rect?, -- Roblox's thumbstick area (touch only)
	topBar: Rect,
}

local HudLayout = {}

function HudLayout.scale(viewport: Vector2): number
	return math.clamp(
		math.min(viewport.X / Hud.ScaleRefWidth, viewport.Y / Hud.ScaleRefHeight),
		Hud.ScaleMin,
		Hud.ScaleMax
	)
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
	local referenceLandscape = false
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
		local navigationWidth = #Hud.ButtonOrder * (row.Width + row.Gap) + Hud.SettingsSize
		local left = if portrait then (width - navigationWidth) / 2 else 12
		for i, name in Hud.ButtonOrder do
			buttons[name] = { x = left + (i - 1) * (row.Width + row.Gap), y = topInset + row.Top, w = row.Width, h = row.Height }
		end
		settings = sized(left + #Hud.ButtonOrder * (row.Width + row.Gap), topInset + row.Top,
			Hud.SettingsSize, Hud.SettingsSize, 1)
		if touch then
			jump = HudLayout.jumpRect(viewport)
			thumbstick = { x = 0, y = height - Hud.Thumbstick.Height, w = Hud.Thumbstick.Width, h = Hud.Thumbstick.Height }
			if not portrait then
				-- The native small-phone joystick is a 74 px circle near the bottom
				-- left (29, height - 94 in the 844x390 emulator). Protect its travel
				-- area rather than reserving a 220 px square over the left navigation.
				-- Larger touch controls and cramped fallback keep the existing reserve.
				local small = math.min(width, height) <= Hud.Jump.SmallMaxSide
				local thumbWidth = if small then 160 else Hud.Thumbstick.Width
				local thumbHeight = if small then 156 else Hud.Thumbstick.Height
				local mineSize = if small then Hud.Mine.SmallSize else Hud.Mine.LargeSize
				local rightLimit = math.min(jump.x, jump.x + jump.w - mineSize) - 8
				local stripScale = (rightLimit - thumbWidth - 8 - 12)
					/ (cards.Resources.Width + cards.Production.Width + Hud.Backpack.Width)
				referenceLandscape = width >= 740 and height - thumbHeight - topInset >= 3 * navigationHeight
					and stripScale >= Hud.MinTouch / cards.Production.Height
				if referenceLandscape then
					thumbstick = { x = 0, y = height - thumbHeight, w = thumbWidth, h = thumbHeight }
				else
					-- Cramped landscape uses the horizontal row. Reduce only its top
					-- gap when the personal captions would enter the joystick reserve.
					local navTop = math.max(topInset, math.min(topInset + row.Top, thumbstick.y - navigationHeight))
					for _, button in buttons do button.y = navTop end
					if settings then settings.y = navTop end
				end
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
				local walletScale = (width - 24 - 6 - cards.Production.Width * productionScale) / cards.Resources.Width
				local minimumProductionScale = Hud.MinTouch / cards.Production.Height
				local minimumWalletScale = (width - 24 - 6 - cards.Production.Width * minimumProductionScale) / cards.Resources.Width
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
		elseif referenceLandscape then
			local reservedThumb = thumbstick :: Rect
			local reservedJump = jump :: Rect
			local navTop = math.min(topInset + row.Top, reservedThumb.y - 3 * navigationHeight)
			local navGap = math.max(0, math.min(row.Gap, (reservedThumb.y - navTop - 3 * navigationHeight) / 2))
			for i, name in { "SHOP", "INDEX", "REBIRTH" } do
				buttons[name] = { x = 12, y = navTop + (i - 1) * (navigationHeight + navGap), w = row.Width, h = row.Height }
			end
			settings = sized(width - 12 - Hud.SettingsSize, math.max(2, topInset - Hud.SettingsSize - 2),
				Hud.SettingsSize, Hud.SettingsSize, 1)
			buttons.STORE = { x = settings.x - row.Gap - row.Width, y = settings.y, w = row.Width, h = row.Height }
			local eventY = math.max(topInset + 6, settings.y + settings.h + 6, buttons.STORE.y + navigationHeight + 6)
			local eventScale = math.min(0.6,
				(reservedJump.y - Hud.Mine.Gap - Hud.Mine.MinSize - Hud.Mine.EventGap - eventY) / Hud.EventPanel.Height)
			eventPanel = sized(width - 12 - Hud.EventPanel.Width * eventScale, eventY,
				Hud.EventPanel.Width, Hud.EventPanel.Height, eventScale)
			local timerWidth = 2 * math.min(width / 2 - (12 + row.Width + 12), eventPanel.x - 12 - width / 2)
			timer = centred(math.max(topInset + 6, Hud.Timer.Top * scale), Hud.Timer.Width, Hud.Timer.Height,
				math.min(scale, timerWidth / Hud.Timer.Width))
			local reservedMine = mineForEvent() :: Rect
			local stripLeft = reservedThumb.x + reservedThumb.w + 8
			local stripRight = math.min(reservedJump.x, reservedMine.x) - 8
			local stripScale = math.min(Hud.TouchCardScale,
				(stripRight - stripLeft - 12) / (cards.Resources.Width + cards.Production.Width + Hud.Backpack.Width))
			local bottom = height - 6
			resources = sized(stripLeft, bottom - cards.Resources.Height * stripScale,
				cards.Resources.Width, cards.Resources.Height, stripScale)
			production = sized(resources.x + resources.w + 6, bottom - productionHeight * stripScale,
				cards.Production.Width, productionHeight, stripScale)
			backpack = sized(production.x + production.w + 6, bottom - Hud.Backpack.Height * stripScale,
				Hud.Backpack.Width, Hud.Backpack.Height, stripScale)
			tutorial = centred(math.min(resources.y, backpack.y, production.y) - 6 - training.Height * Hud.TouchCardScale,
				training.Width, training.Height, Hud.TouchCardScale)
		elseif compact then
			local eventScale = 0.7
			if jump then
				eventScale = math.min(eventScale,
					(jump.y - Hud.Mine.Gap - Hud.Mine.MinSize - Hud.Mine.EventGap - topInset - row.Top) / Hud.EventPanel.Height)
			end
			eventPanel = sized(width - 12 - Hud.EventPanel.Width * eventScale, topInset + row.Top,
				Hud.EventPanel.Width, Hud.EventPanel.Height, eventScale)
			local clockLeft = left + navigationWidth + 12
			local timerScale = math.min(scale, (eventPanel.x - 12 - clockLeft) / Hud.Timer.Width)
			timer = sized(clockLeft, topInset + row.Top, Hud.Timer.Width, Hud.Timer.Height, timerScale)
			production = centred(height - 6 - productionHeight * 0.6, cards.Production.Width, productionHeight, 0.6)
			local walletScale, backpackScale = 0.55, 0.65
			if expanded then
				if width < 740 then walletScale, backpackScale = 0.5, 0.55 end
				local reservedMine = mineForEvent()
				local rightLimit = if jump then math.min(jump.x - 8, if reservedMine then reservedMine.x - 8 else math.huge) else width - 12
				-- MINE can be wider than jump when the top inset is small. Fit the
				-- side cards to that tighter boundary while preserving a 44 px summary.
				local sideWidth = math.max(cards.Resources.Width * walletScale, Hud.Backpack.Width * backpackScale)
				local availableSideWidth = rightLimit - Hud.Thumbstick.Width - 8 - 6
					- cards.Production.Width * Hud.MinTouch / cards.Production.Height - 2
				local sideFit = math.min(1, availableSideWidth / sideWidth)
				walletScale *= sideFit
				backpackScale *= sideFit
				local productionScale = math.min(0.6,
					(rightLimit - Hud.Thumbstick.Width - 8 - 6 - math.max(cards.Resources.Width * walletScale, Hud.Backpack.Width * backpackScale))
						/ cards.Production.Width)
				production = sized(Hud.Thumbstick.Width + 8, height - 6 - productionHeight * productionScale,
					cards.Production.Width, productionHeight, productionScale)
				local sideY = math.max(production.y, eventPanel.y + eventPanel.h + 6)
				resources = sized(production.x + production.w + 6, sideY, cards.Resources.Width, cards.Resources.Height, walletScale)
				backpack = sized(resources.x, sideY + resources.h + 6, Hud.Backpack.Width, Hud.Backpack.Height, backpackScale)
			else
				production.x = math.max(production.x, Hud.Thumbstick.Width + 8)
				local rowWidth = cards.Resources.Width * walletScale + 6 + Hud.Backpack.Width * backpackScale
				local rowY = production.y - 6 - math.max(cards.Resources.Height * walletScale, Hud.Backpack.Height * backpackScale)
				resources = sized(math.max((width - rowWidth) / 2, Hud.Thumbstick.Width + 8), rowY,
					cards.Resources.Width, cards.Resources.Height, walletScale)
				backpack = sized(resources.x + resources.w + 6, rowY, Hud.Backpack.Width, Hud.Backpack.Height, backpackScale)
				tutorial = centred(rowY - 6 - training.Height * Hud.TouchCardScale, training.Width, training.Height, Hud.TouchCardScale)
			end
		else
			timer.y = topInset + row.Top
			resources = sized(12, topInset + row.Top + navigationHeight + 6, cards.Resources.Width, cards.Resources.Height, scale)
			eventPanel = sized(width - 12 - Hud.EventPanel.Width * scale, topInset + row.Top,
				Hud.EventPanel.Width, Hud.EventPanel.Height, scale)
			backpack = sized(width - 12 - Hud.Backpack.Width * scale, eventPanel.y + eventPanel.h + 6,
				Hud.Backpack.Width, Hud.Backpack.Height, scale)
		end
		mine = mineForEvent()
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
		local columnHeight = navigationHeight(Hud.Column.Width * buttonScale, Hud.Column.Height * buttonScale)
		local columnTop = math.min(Hud.Column.Top * scale,
			resources.y - #Hud.DesktopButtonOrder * columnHeight - (#Hud.DesktopButtonOrder - 1) * Hud.Column.Gap * buttonScale - 8)
		local buttonY = columnTop
		for _, name in Hud.DesktopButtonOrder do
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
		buttons.INDEX = sized(width - (Hud.EdgeMargin + Hud.Column.Width) * buttonScale,
			math.max(height * 0.48 - Hud.Column.Height * buttonScale / 2, eventPanel.y + eventPanel.h + 8),
			Hud.Column.Width, Hud.Column.Height, buttonScale)
		local index = buttons.INDEX
		local indexBottom = index.y + navigationHeight(index.w, index.h)
		if backpack.y - indexBottom - 2 * BackpackPopupGap < BackpackPopupMinHeight then
			-- Short desktop windows need the Index above the attached ore popup.
			-- Keep its full authored caption, then place the objective underneath.
			index.y = math.max(topInset + 6, settings.y + settings.h + 8)
			eventPanel.y = math.max(eventPanel.y, index.y + navigationHeight(index.w, index.h) + 8)
		end
	end
	-- Notifications use real pixels, independent of card scale. The reward line
	-- needs two rows; tight expanded screens temporarily reserve the event slot
	-- instead of shrinking the text into movement controls or the foundry.
	local notification = tightNotification or centred(timer.y + timer.h + (if desktop then 50 * scale else 0) + 8,
		math.min(400, width - 24), notificationHeight, 1)
	local eventVisible = not tightPortrait and not (activeNotification and touch and portrait and expanded == true)
	if referenceLandscape then
		if expanded then
			notification = { x = width - 12 - 190, y = eventPanel.y, w = 190, h = notificationHeight }
			eventVisible = not activeNotification
			if activeNotification and HudLayout.overlaps(timer, notification) then
				local timerWidth = math.min(timer.w, 2 * (notification.x - 12 - width / 2))
				timer = centred(timer.y, Hud.Timer.Width, Hud.Timer.Height, timerWidth / Hud.Timer.Width)
			end
		else
			notification = centred(tutorial.y, math.min(400, width - 24), notificationHeight, 1)
		end
	elseif portrait then
		if not tightPortrait then notification.y = if touch and expanded then eventPanel.y else tutorial.y end
	elseif touch and compact then
		if expanded then
			local y = buttons.SHOP.y + navigationHeight(buttons.SHOP.w, buttons.SHOP.h) + 2
			local pocketBottom = if thumbstick then thumbstick.y else height
			local pocketHeight = math.min(notificationHeight, pocketBottom - y - 2)
			local minimumHeight = if rewardNotificationActive then 48 else 24
			if pocketHeight < minimumHeight then
				notification = { x = width - 12 - 190, y = eventPanel.y, w = 190, h = notificationHeight }
				eventVisible = not activeNotification
			else
				notification = { x = 12, y = y, w = Hud.Thumbstick.Width - 12, h = pocketHeight }
			end
		else
			local x = Hud.Thumbstick.Width + 8
			notification = { x = x, y = tutorial.y, w = math.min(400, eventPanel.x - 6 - x), h = notificationHeight }
		end
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
		tutorialY = tutorial.y - topInset, mine = mine, jump = jump, thumbstick = thumbstick,
		topBar = { x = 0, y = 0, w = width, h = topInset },
	}
end

-- An ore list attached above the backpack HUD. These are screen pixels: the
-- renderer keeps text and rows readable instead of applying the HUD's scale.
-- Match the anchor's width and fit up to three rows beneath the header. High
-- anchors shrink the height so the list can scroll while retaining a full row.
function HudLayout.backpackPanel(layout: Layout, rowCount: number?): Rect
	local margin, gap = 12, BackpackPopupGap
	local visibleRows = math.clamp(math.floor(rowCount or 3), 1, 3)
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

return HudLayout
