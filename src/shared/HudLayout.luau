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
-- the HUD gui (IgnoreGuiInset = false) subtracts `inset` from y (see HudLayout.toGui).
--
-- Two arrangements, chosen by `touch` (TouchEnabled and not KeyboardEnabled):
--   mouse: a column of buttons down the right side, under the event card;
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
	eventPanel: Rect,
	tutorialY: number, -- gui y (below the top bar) of the tutorial card when it sits at the right
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

function HudLayout.compute(viewport: Vector2, touch: boolean, inset: number?): Layout
	local topInset = inset or Hud.TopBarInset
	local width, height = viewport.X, viewport.Y
	local scale = HudLayout.scale(viewport)
	local order = Hud.ButtonOrder
	local count = #order

	local buttons: { [string]: Rect } = {}
	local buttonBase: Vector2
	local buttonScale: number
	local buttonTextSize: number? = nil
	local eventTop: number
	local tutorialY: number

	if touch then
		local row = Hud.TouchRow
		buttonBase = Vector2.new(row.Width, row.Height)
		buttonScale = 1
		buttonTextSize = row.TextSize
		local left = width - row.Right - (count * row.Width + (count - 1) * row.Gap)
		local top = topInset + row.Top
		for i, name in order do
			buttons[name] = { x = left + (i - 1) * (row.Width + row.Gap), y = top, w = row.Width, h = row.Height }
		end
		eventTop = top + row.Height + Hud.EventPanel.Gap
		-- The card has the row's place to itself: centred under the clock
		tutorialY = 138 * scale
	else
		local column = Hud.Column
		buttonBase = Vector2.new(column.Width, column.Height)
		buttonScale = math.max(scale, Hud.MinTouch / column.Height)
		local w, h, gap = column.Width * buttonScale, column.Height * buttonScale, column.Gap * buttonScale
		local top = topInset + column.Top * scale
		for i, name in order do
			buttons[name] = { x = width - Hud.EdgeMargin - w, y = top + (i - 1) * (h + gap), w = w, h = h }
		end
		eventTop = topInset + Hud.EventPanel.Top * scale
		-- Compact windows put the card where the buttons under SHOP would be
		tutorialY = buttons[order[2]].y - topInset
	end

	local panel = Hud.EventPanel
	local eventPanel: Rect = {
		x = width - Hud.EdgeMargin - panel.Width * scale,
		y = eventTop,
		w = panel.Width * scale,
		h = panel.Height * scale,
	}
	local timer: Rect = {
		x = width / 2 - Hud.Timer.Width * scale / 2,
		y = topInset + Hud.Timer.Top,
		w = Hud.Timer.Width * scale,
		h = Hud.Timer.Height * scale,
	}

	local mine: Rect? = nil
	local jump: Rect? = nil
	local thumbstick: Rect? = nil
	if touch then
		local jumpRect = HudLayout.jumpRect(viewport)
		jump = jumpRect
		thumbstick = {
			x = 0,
			y = height - Hud.Thumbstick.Height,
			w = Hud.Thumbstick.Width,
			h = Hud.Thumbstick.Height,
		}
		local size = if math.min(width, height) <= Hud.Jump.SmallMaxSide then Hud.Mine.SmallSize else Hud.Mine.LargeSize
		mine = {
			x = jumpRect.x + jumpRect.w - size, -- right edges aligned
			y = jumpRect.y - Hud.Mine.Gap - size,
			w = size,
			h = size,
		}
	end

	return {
		viewport = viewport,
		touch = touch,
		inset = topInset,
		scale = scale,
		buttons = buttons,
		buttonBase = buttonBase,
		buttonScale = buttonScale,
		buttonTextSize = buttonTextSize,
		timer = timer,
		eventPanel = eventPanel,
		tutorialY = tutorialY,
		mine = mine,
		jump = jump,
		thumbstick = thumbstick,
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
