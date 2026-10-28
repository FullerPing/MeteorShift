--!strict
-- How big menus are drawn. Above 1080p a menu is laid out for a 1080p screen and drawn larger. Below a minimum screen size a menu is laid out for a larger "virtual" screen and drawn
-- smaller (a UIScale of `scale` on its panel), so a phone shows the whole menu a small desktop window shows instead
-- of a cramped slice of it. Rects from the menu layouts (Shared.*Layout) are in the virtual screen's pixels.
export type View = { viewport: Vector2, inset: number, scale: number }
export type Rect = { x: number, y: number, w: number, h: number }

local MenuFit = {}

MenuFit.LandscapeMin = Vector2.new(860, 460) -- a landscape screen smaller than this draws menus smaller
MenuFit.PortraitMinWidth = 420 -- a portrait screen narrower than this does
MenuFit.MinScale = 0.7 -- never smaller, so text stays readable
-- Text drawn smaller than this many on-screen pixels turns to mush (FredokaOne under ~13 px), so a menu drawn smaller
-- keeps its text at least this big, or at its authored size when that is smaller still (MenuFit.drawnTextSize)
MenuFit.MinTextPx = 14
MenuFit.ScaleUpRef = Vector2.new(1920, 1080) -- a screen bigger than this draws menus bigger, in proportion
MenuFit.MaxScale = 3
MenuFit.RibbonRoom = 28 -- between the top bar and a centred panel: the title ribbon pokes 24 px above it
MenuFit.FootRoom = 15 -- under a centred panel: its 7 px lip and a margin

function MenuFit.view(viewport: Vector2, inset: number): View
	local scale = if viewport.Y > viewport.X then viewport.X / MenuFit.PortraitMinWidth
		else math.min(viewport.X / MenuFit.LandscapeMin.X, viewport.Y / MenuFit.LandscapeMin.Y)
	scale = math.clamp(scale, MenuFit.MinScale, 1)
	-- big screens (1440p, 4K) lay the menu out as on a 1080p screen and draw it larger
	local up = math.min(viewport.X / MenuFit.ScaleUpRef.X, viewport.Y / MenuFit.ScaleUpRef.Y)
	scale = math.max(scale, math.min(up, MenuFit.MaxScale))
	return { viewport = viewport / scale, inset = inset / scale, scale = scale }
end

-- where a virtual rect's centre is on the real screen (panels are placed by their centre, AnchorPoint 0.5)
function MenuFit.centre(view: View, rect: Rect): Vector2
	return Vector2.new((rect.x + rect.w / 2) * view.scale, (rect.y + rect.h / 2) * view.scale)
end

-- a menu of a natural size, centred under the top bar and no bigger than the screen, in virtual pixels. Room is kept for
-- the cartoon title ribbon (24 px above the panel, MenuFit.RibbonRoom with a gap) and the lip under it (MenuFit.FootRoom)
function MenuFit.centred(view: View, natural: Vector2): Rect
	local top = view.inset + MenuFit.RibbonRoom
	local w = math.min(natural.X, math.max(0, view.viewport.X - 24))
	local h = math.min(natural.Y, math.max(0, view.viewport.Y - top - MenuFit.FootRoom))
	return { x = (view.viewport.X - w) / 2, y = top + (view.viewport.Y - top - MenuFit.FootRoom - h) / 2, w = w, h = h }
end

-- a menu drawn whole, the way its mockup draws it: centred like MenuFit.centred, and where the screen has no room for its
-- natural size it is drawn smaller still (the returned view's scale) instead of cut short. For small fixed dialogs.
function MenuFit.whole(view: View, natural: Vector2): (View, Rect)
	local roomW = math.max(1, view.viewport.X - 24)
	local roomH = math.max(1, view.viewport.Y - view.inset - MenuFit.RibbonRoom - MenuFit.FootRoom)
	local shrink = math.min(1, roomW / natural.X, roomH / natural.Y)
	local whole = { viewport = view.viewport / shrink, inset = view.inset / shrink, scale = view.scale * shrink }
	return whole, MenuFit.centred(whole, natural)
end

-- A UITextSizeConstraint caps text in on-screen pixels, after the UIScales above it, so a cap authored for a menu drawn
-- at 1080p would freeze its text while the menu grows on a bigger screen. These are the limits to set for an authored
-- (baseMin, baseMax) under a drawn `scale`: the max follows the scale; the min grows with it but never shrinks below what
-- was authored (small screens keep their legibility floor) and never passes the max. Roblox allows 1 to 100.
function MenuFit.textLimits(baseMin: number, baseMax: number, scale: number): (number, number)
	local max = MenuFit.drawnTextSize(baseMax, scale)
	local min = math.clamp(math.floor(baseMin * math.max(scale, 1) + 0.5), 1, max)
	return min, max
end

-- The on-screen size of text authored at `size` under a drawn `scale`: it follows the scale, but a menu drawn smaller
-- never takes it below MenuFit.MinTextPx (or below its own size, when that is smaller). Roblox allows 1 to 100.
function MenuFit.drawnTextSize(size: number, scale: number): number
	return math.clamp(math.floor(math.max(size * scale, math.min(size, MenuFit.MinTextPx)) + 0.5), 1, 100)
end

return MenuFit
