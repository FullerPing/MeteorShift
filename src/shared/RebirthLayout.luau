--!strict
-- Panel bounds are screen pixels; body and footer positions are panel-local.
-- Only the body scrolls, preserving fixed-size confirmation and close controls.
export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	contentY: number,
	contentH: number,
	canvasH: number,
	confirmY: number,
	footerY: number,
}

local RebirthLayout = {}

function RebirthLayout.compute(viewport: Vector2, inset: number): Layout
	local topInset = math.max(0, inset)
	local availableWidth = math.max(0, viewport.X - 24)
	local availableHeight = math.max(0, viewport.Y - topInset - 24)
	local panelWidth = math.min(400, availableWidth)
	local panelHeight = math.min(400, availableHeight)

	return {
		panel = {
			x = (viewport.X - panelWidth) / 2,
			y = topInset + 12 + (availableHeight - panelHeight) / 2,
			w = panelWidth,
			h = panelHeight,
		},
		contentY = 64,
		contentH = math.max(0, panelHeight - 64 - 104),
		canvasH = 226,
		confirmY = panelHeight - 92,
		footerY = panelHeight - 38,
	}
end

return RebirthLayout
