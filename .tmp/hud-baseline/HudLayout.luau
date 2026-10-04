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
-- Two arrangements, chosen by `touch` (TouchEnabled and not KeyboardEnabled):
--   mouse: a left navigation column, centre clock and equipment, right status cards;
--   touch: a row along the top right, so the right edge below it is free for the MINE
--          button, which sits above Roblox's jump button.

local Config = require(script.Parent.Config)

local Hud = Config.Hud

export type Rect = { x: number, y: number, w: number, h: number }

export type Layout = {
	viewport: Vector2,
	touch: boolean,
	inset: number,
	scale: number, -- the HUD card scale
	-- HUD buttons by name (Hud.ButtonOrder), drawn at `buttonBase` * `buttonScale`
	buttons: { [string]: Rect },
	buttonBase: Vector2, -- unscaled size to give the button with a UIScale of buttonScale
	buttonScale: number,
	buttonTextSize: number?, -- fixed text size for the touch row (nil: keep each button's own)
	timer: Rect,
	leftCards: { [string]: Rect }, -- Resources, Equipment, Production
	leftScale: number, -- the scale to draw the left cards at
	eventPanel: Rect,
	tutorial: Rect,
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

function HudLayout.compute(viewport: Vector2, touch: boolean, inset: number?, expanded: boolean?): Layout
	local topInset = inset or Hud.TopBarInset
	local width, height = viewport.X, viewport.Y
	local scale = HudLayout.scale(viewport)
	local cards = Hud.LeftCards
	local buttons: { [string]: Rect } = {}
	local buttonBase = Vector2.new(Hud.Column.Width, Hud.Column.Height)
	local buttonScale = math.max(scale, Hud.MinTouch / Hud.Column.Height)
	local timer: Rect = {
		x = (width - Hud.Timer.Width * scale) / 2,
		y = math.max(topInset + 6, Hud.Timer.Top * scale),
		w = Hud.Timer.Width * scale,
		h = Hud.Timer.Height * scale,
	}
	local resources: Rect = {
		x = cards.X * scale,
		y = math.max(topInset + 6, cards.Resources.Top * scale),
		w = cards.Resources.Width * scale,
		h = cards.Resources.Height * scale,
	}
	local equipment: Rect = {
		x = (width - cards.Equipment.Width * scale) / 2,
		y = height - (cards.Equipment.Bottom + cards.Equipment.Height) * scale,
		w = cards.Equipment.Width * scale,
		h = cards.Equipment.Height * scale,
	}
	local productionHeight = if expanded then cards.Production.ExpandedHeight else cards.Production.Height
	local production: Rect = {
		x = width - (cards.Production.Right + cards.Production.Width) * scale,
		y = height - (cards.Production.Bottom + productionHeight) * scale,
		w = cards.Production.Width * scale,
		h = productionHeight * scale,
	}
	local eventPanel: Rect = {
		x = width - Hud.EdgeMargin * scale - Hud.EventPanel.Width * scale,
		y = math.max(topInset + 6, Hud.EventPanel.Top * scale),
		w = Hud.EventPanel.Width * scale,
		h = Hud.EventPanel.Height * scale,
	}
	local training = Hud.Training
	local tutorial: Rect = {
		x = width - (training.Right + training.Width) * scale,
		y = if expanded then production.y - (training.Gap + training.Height) * scale
			else height - (training.Bottom + training.Height) * scale,
		w = training.Width * scale,
		h = training.Height * scale,
	}
	local mine: Rect? = nil
	local jump: Rect? = nil
	local thumbstick: Rect? = nil
	if touch then
		local row = Hud.TouchRow
		buttonBase = Vector2.new(row.Width, row.Height)
		buttonScale = 1
		local left = width - row.Right - (#Hud.ButtonOrder * row.Width + (#Hud.ButtonOrder - 1) * row.Gap)
		for i, name in Hud.ButtonOrder do
			buttons[name] = { x = left + (i - 1) * (row.Width + row.Gap), y = topInset + row.Top, w = row.Width, h = row.Height }
		end
		timer.y = topInset + row.Top
		resources.x = 12
		resources.y = topInset + row.Top
		eventPanel.x = width - 12 - eventPanel.w
		eventPanel.y = topInset + row.Top + row.Height + Hud.EventPanel.Gap
		production.x = if expanded then (width - production.w) / 2 else 12
		if not expanded then
			local productionScale = math.min(scale, (timer.x - 20) / cards.Production.Width)
			production.w = cards.Production.Width * productionScale
			production.h = productionHeight * productionScale
		end
		production.y = if expanded then timer.y + timer.h + 8 else resources.y + resources.h + 6
		local trainingScale = math.max(scale, Hud.TouchCardScale)
		tutorial.w, tutorial.h = training.Width * trainingScale, training.Height * trainingScale
		tutorial.x = (width - tutorial.w) / 2
		tutorial.y = timer.y + timer.h + 8
		jump = HudLayout.jumpRect(viewport)
		thumbstick = { x = 0, y = height - Hud.Thumbstick.Height, w = Hud.Thumbstick.Width, h = Hud.Thumbstick.Height }
		local size = if math.min(width, height) <= Hud.Jump.SmallMaxSide then Hud.Mine.SmallSize else Hud.Mine.LargeSize
		local room = jump.y - Hud.Mine.Gap - (eventPanel.y + eventPanel.h + Hud.Mine.EventGap)
		size = math.clamp(math.floor(room), Hud.Mine.MinSize, size)
		mine = { x = jump.x + jump.w - size, y = jump.y - Hud.Mine.Gap - size, w = size, h = size }
	else
		for i, name in Hud.ButtonOrder do
			buttons[name] = {
				x = Hud.Column.Left * scale,
				y = Hud.Column.Top * scale + (i - 1) * (Hud.Column.Height + Hud.Column.Gap) * buttonScale,
				w = Hud.Column.Width * buttonScale,
				h = Hud.Column.Height * buttonScale,
			}
		end
	end
	return {
		viewport = viewport, touch = touch, inset = topInset, scale = scale,
		buttons = buttons, buttonBase = buttonBase, buttonScale = buttonScale,
		buttonTextSize = nil, timer = timer,
		leftCards = { Resources = resources, Equipment = equipment, Production = production },
		leftScale = scale, eventPanel = eventPanel, tutorial = tutorial,
		tutorialY = tutorial.y - topInset, mine = mine, jump = jump, thumbstick = thumbstick,
		topBar = { x = 0, y = 0, w = width, h = topInset },
	}
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
