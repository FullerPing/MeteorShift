--!strict
-- THE place to move, hide and add HUD things. Edit this file; nothing else needs to change.
-- With Rojo connected the edit reaches Studio instantly: press Play again to see it.
--
-- Everything is in screen pixels and is applied on top of the automatic layout
-- (Shared.HudLayout), so it follows every screen size, phone and desktop alike.
--
-- Element names you can use in Hidden and Nudge:
--   Level       the player level badge, top left
--   Wallet      cash and shards, bottom left
--   Foundry     the foundry icon and SELL button, bottom centre
--   Backpack    the backpack card, bottom right
--   Timer       the meteor clock, top centre
--   EventPanel  the "break the crust / strike the core" card
--   Toast       the notification line (Nudge only, so messages are never lost)
--   SHOP PETS INDEX REBIRTH STORE DAILY   the menu buttons (SHOP is labelled GEAR; DAILY is Daily Rewards)
--   Settings    the settings gear (touch screens)
--   FastWalk    the SPRINT button (the ORE button follows it)
--   Ore         the ORE button, on top of wherever FastWalk is
--   Offers      the 2x Ore, 2x Cash and Starter Pack buttons stacked above INDEX (they leave once bought)

local HudEdit = {}

-- Elements that should not be drawn at all. Example: { "Level", "INDEX" }
HudEdit.Hidden = {} :: { string }

-- Move or resize elements. x moves right, y moves down, scale multiplies the size
-- (0.8 = 20% smaller). Leave out whatever you do not change.
-- Example: { Wallet = { y = -20 }, Timer = { x = 40, scale = 0.9 } }
HudEdit.Nudge = {} :: { [string]: { x: number?, y: number?, scale: number? } }

-- Extra buttons and labels you add yourself. One table per element:
--   Id      unique name (required)
--   Kind    "button" (default) or "label"
--   Text    the words on it
--   Icon    a key from Config.HudIcons ("ore", "coin", "crystal", "meteor", ...), optional
--   Color   "blue" "deep" "green" "orange" "purple" "red" "gold" "white" "slate" "dark"
--   Anchor  where it sits: "TopLeft" "Top" "TopRight" "Left" "Center" "Right"
--           "BottomLeft" "Bottom" "BottomRight"
--   X, Y    pixels in from that anchor (negative X on a Right anchor moves it inwards)
--   Width, Height   size in pixels (default 120 x 54)
--   Open    what a click does, pick one: "Shop", "Rebirth", "Refinery", "FastWalk"
--   Click   or your own function: Click = function(player) ... end
-- Example:
--   { Id = "ShopShortcut", Text = "QUICK GEAR", Icon = "equipment", Color = "orange",
--     Anchor = "TopRight", X = -80, Y = 60, Width = 150, Height = 56, Open = "Shop" },
HudEdit.Custom = {} :: { { [string]: any } }

return HudEdit
