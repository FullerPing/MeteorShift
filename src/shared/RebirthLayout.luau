--!strict
-- Panel bounds are screen pixels; everything else is panel-local.
-- The body (reward, what you keep, what resets, progress) scrolls; the rebirth button, its note and the
-- premium "keep everything" button stay pinned below it so they are always reachable.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	padding: number,
	contentY: number,
	contentH: number,
	confirmY: number, -- the main REBIRTH button
	confirmH: number,
	footerY: number, -- the line under it: what you still need, or what happens next
	footerH: number,
	dividerY: number, -- the PREMIUM divider (dividerH is 0 on short screens, which hide it)
	dividerH: number,
	keepY: number, -- the premium "rebirth, keep everything" button, last and lighter than the main action
	keepH: number,
}

local RebirthLayout = {}

function RebirthLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local panelWidth = math.min(440, availableWidth)
	local panelHeight = math.min(640, availableHeight)
	-- short screens (phones in landscape) drop the divider and tighten the controls so the body keeps a usable window
	local tight = panelHeight < 480
	local padding, gap = if tight then 12 else 16, 8
	local confirmH, footerH, dividerH, keepH = 50, 34, 18, 44
	if tight then confirmH, footerH, dividerH, keepH = 40, 22, 0, 36 end

	-- built up from the bottom edge
	local keepY = panelHeight - padding - keepH
	local dividerY = keepY - gap - dividerH
	local footerY = dividerY - 4 - footerH
	local confirmY = footerY - 4 - confirmH
	local contentY = if tight then 64 else 68

	return {
		panel = {
			x = (viewport.X - panelWidth) / 2,
			y = topInset + 12 + (availableHeight - panelHeight) / 2,
			w = panelWidth,
			h = panelHeight,
		},
		padding = padding,
		contentY = contentY,
		contentH = math.max(0, confirmY - 10 - contentY),
		confirmY = confirmY, confirmH = confirmH,
		footerY = footerY, footerH = footerH,
		dividerY = dividerY, dividerH = dividerH,
		keepY = keepY, keepH = keepH,
	}
end

return RebirthLayout
