--!strict
-- The Rebirth menu's geometry, in the cartoon light look (MenuTheme). On a roomy window ("wide") it is the Gear Shop's
-- 760 x 501 frame (EquipmentShopLayout.view decides the draw scale): the reward and what resets / what you keep scroll
-- in the left column, the requirement, REBIRTH, the note, the gold keep-everything card and PERKS sit in a column on the
-- right. On a small screen (MenuFit) it is one column: the body scrolls and the requirement row, REBIRTH and the
-- keep-everything button are pinned under it, so the actions are always reachable.
-- Panel bounds are virtual screen pixels; every other rect is local to the panel.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	wide: boolean,
	padding: number,
	content: Rect, -- the scrolling body
	requirement: Rect,
	confirm: Rect, -- the main REBIRTH button
	footer: Rect, -- the note under it: what you still need, or what happens next
	keepCard: Rect, -- the gold card behind the keep-everything button (zero-sized on small screens)
	keep: Rect, -- the premium "rebirth, keep everything" button
	perks: Rect,
	wallet: Rect, -- the cash chip (zero-sized on small screens)
	compareH: number, -- the reward card at the top of the body
}

local RebirthLayout = {}

RebirthLayout.WIDE_W, RebirthLayout.WIDE_H = 760, 501 -- the Gear Shop's frame
RebirthLayout.RIBBON = 26 -- the title ribbon pokes this far above the body
RebirthLayout.LIP = 7 -- MenuTheme.LIP: the navy lip along the panel's bottom
RebirthLayout.COMPACT = Vector2.new(480, 560) -- the small-screen panel, before it is fitted to the screen

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function RebirthLayout.compute(viewport: Vector2, inset: number, wide: boolean?): Layout
	if wide then
		local W, H, R = RebirthLayout.WIDE_W, RebirthLayout.WIDE_H, RebirthLayout.RIBBON
		local h = H - R
		local pad, side = 22, 254
		local sideX = W - pad - side
		return {
			panel = rect((viewport.X - W) / 2, (viewport.Y - H) / 2 + R, W, h),
			wide = true,
			padding = pad,
			-- both columns end on PERKS's bottom edge; the side gaps run 8 / 4 (the note hugs its button) / 6 / 8
			content = rect(pad, 58, sideX - pad - 16, h - RebirthLayout.LIP - 58 - 12),
			requirement = rect(sideX, 58, side, 92),
			confirm = rect(sideX, 158, side, 64),
			footer = rect(sideX, 226, side, 40),
			keepCard = rect(sideX, 272, side, 128),
			keep = rect(sideX + 10, 344, side - 20, 48),
			perks = rect(sideX, 408, side, 48),
			wallet = rect(W - 62 - 150, 14, 150, 31), -- the same line and right edge (698) as the Gear Shop's and Pets' wallets
			compareH = 150,
		}
	end
	local top = math.max(0, inset) + 26 -- MenuTheme's ribbon pokes 24 px above the panel
	local w = math.min(RebirthLayout.COMPACT.X, math.max(0, viewport.X - 24))
	local h = math.min(RebirthLayout.COMPACT.Y, math.max(0, viewport.Y - top - 12))
	local pad = 14
	-- short screens (phones in landscape) use slimmer pinned controls so the body keeps a usable window
	local tight = h < 480
	local keepH, confirmH, footerH, reqH = 46, 56, 22, 40
	if tight then keepH, confirmH, footerH, reqH = 42, 48, 20, 38 end
	-- built up from the bottom edge
	local keepY = h - RebirthLayout.LIP - pad - keepH
	local confirmY = keepY - 8 - confirmH
	local footerY = confirmY - 4 - footerH
	local reqY = footerY - 6 - reqH
	local contentY = 56
	local perksW = 104
	return {
		panel = rect((viewport.X - w) / 2, top + (viewport.Y - top - 12 - h) / 2, w, h),
		wide = false,
		padding = pad,
		content = rect(pad, contentY, w - pad * 2, math.max(0, reqY - 8 - contentY)),
		requirement = rect(pad, reqY, w - pad * 2, reqH),
		-- PERKS shares REBIRTH's row: the header is the title ribbon's on a narrow phone
		confirm = rect(pad, confirmY, w - pad * 2 - 8 - perksW, confirmH),
		footer = rect(pad, footerY, w - pad * 2, footerH),
		keepCard = rect(pad, keepY, 0, 0),
		keep = rect(pad, keepY, w - pad * 2, keepH),
		perks = rect(w - pad - perksW, confirmY, perksW, confirmH),
		wallet = rect(0, 0, 0, 0),
		compareH = 118,
	}
end

return RebirthLayout
