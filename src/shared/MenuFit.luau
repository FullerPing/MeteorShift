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
MenuFit.ScaleUpRef = Vector2.new(1920, 1080) -- a screen bigger than this draws menus bigger, in proportion
MenuFit.MaxScale = 3

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

-- a menu of a natural size, centred under the top bar (its title ribbon pokes 16 px above it) and no bigger than
-- the screen, in virtual pixels
function MenuFit.centred(view: View, natural: Vector2): Rect
	local top = view.inset + 18
	local w = math.min(natural.X, math.max(0, view.viewport.X - 24))
	local h = math.min(natural.Y, math.max(0, view.viewport.Y - top - 12))
	return { x = (view.viewport.X - w) / 2, y = top + (view.viewport.Y - top - 12 - h) / 2, w = w, h = h }
end

return MenuFit
