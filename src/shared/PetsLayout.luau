--!strict
-- The Pets menu's geometry and list logic, pure so tests/PetsLayout.spec.luau can check them.
-- Panel bounds are screen pixels; everything else is local to the panel.
local Config = require(script.Parent.Config.Pets)
local Pets = require(script.Parent.Pets)
local EquipmentShopLayout = require(script.Parent.EquipmentShopLayout)

export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	narrow: boolean,
	compact: boolean, -- phones in landscape: slim header and tabs, the footer line sits under the wallet
	padding: number,
	gap: number,
	headerH: number,
	tabsY: number,
	tabsH: number,
	contentY: number,
	contentH: number,
	footerY: number,
	footerH: number,
	-- PETS and INDEX tabs: a card grid beside (or above) the detail panel
	summaryH: number, -- the equipped line and bonus banner (PETS) or the discovery bar (INDEX) above the grid and detail
	list: Rect,
	detail: Rect, -- the detail column: its banner pokes 6 px above it on the wide layout
	action: Rect, -- the equip / put away button, under the detail
	more: Rect, -- "More slots: ..." under the grid (zero-sized where there is no room)
	cellW: number,
	cellH: number,
	columns: number,
	wide: boolean, -- the cartoon light mockup's frame, the same size as the Gear Shop's
}

local PetsLayout = {}

-- The wide layout: the owner's mockup on the Gear Shop's frame (EquipmentShopLayout.view decides when there is room), the
-- body 760 x 475 with the ribbon poking above it. Everything is local to the body.
local function wideLayout(viewport: Vector2): Layout
	local W, H, R = EquipmentShopLayout.WIDE_W, EquipmentShopLayout.WIDE_H, EquipmentShopLayout.RIBBON
	return {
		panel = { x = (viewport.X - W) / 2, y = (viewport.Y - H) / 2 + R, w = W, h = H - R },
		-- 6 px higher than the first pass, with the Gear Shop (EquipmentShopLayout); the hint is as tall as the action
		-- button beside it so both columns end on one line
		narrow = false, compact = false, padding = 22, gap = 8, headerH = 46, tabsY = 55, tabsH = 42,
		contentY = 107, contentH = 307, footerY = 414, footerH = 42, summaryH = 82,
		list = { x = 22, y = 197, w = 440, h = 190 },
		detail = { x = 493, y = 107, w = 245, h = 296 },
		action = { x = 493, y = 414, w = 245, h = 42 },
		more = { x = 22, y = 390, w = 440, h = 20 },
		cellW = 136, cellH = 168, columns = 3, wide = true,
	}
end

function PetsLayout.compute(viewport: Vector2, inset: number, wide: boolean?): Layout
	if wide then return wideLayout(viewport) end
	local topInset = math.max(0, inset)
	local availableW = math.max(0, viewport.X - 24)
	local availableH = math.max(0, viewport.Y - topInset - 24)
	local w = math.min(860, availableW)
	local narrow = w < 640
	-- phones in landscape: the panel runs from just under the top bar (its title ribbon pokes 16 px above it) to
	-- the bottom, with a slimmer header and tabs, and the footer line moves up beside the title
	local compact = not narrow and availableH < 400
	local panelTop = if compact then topInset + 18 else nil
	if panelTop then availableH = math.max(0, viewport.Y - panelTop - 12) end
	local h = math.min(620, availableH)
	local padding, gap = 12, 8
	local headerH = if compact then 44 else 54
	local tabsY, tabsH = headerH + 6, 40
	local contentY = tabsY + tabsH + gap
	local footerH = if compact then 0 else 40
	local footerY = h - padding - footerH
	local contentH = math.max(0, footerY - (if compact then 0 else gap) - contentY)
	local innerW = math.max(0, w - padding * 2)
	-- roomy cards on a desktop panel, snug ones where space is tight
	local snug = narrow or compact
	local cellW, cellH = if snug then 104 else 150, if snug then 124 else 172
	-- one slim row on narrow and short screens, two rows (label over banner) otherwise
	local summaryH = if snug then 40 else 66
	local bodyY, bodyH = contentY + summaryH + gap, math.max(0, contentH - summaryH - gap)
	local list: Rect, detail: Rect
	local actionH = 44
	if narrow then
		local listH = math.floor(bodyH * 0.46)
		list = { x = padding, y = bodyY, w = innerW, h = listH }
		detail = { x = padding, y = bodyY + listH + gap, w = innerW, h = math.max(0, bodyH - listH - gap * 2 - actionH) }
	else
		local listW = math.floor((innerW - gap) * 0.55)
		list = { x = padding, y = bodyY, w = listW, h = bodyH }
		detail = { x = padding + listW + gap, y = bodyY, w = innerW - listW - gap, h = math.max(0, bodyH - gap - actionH) }
	end
	local action = { x = detail.x, y = detail.y + detail.h + gap, w = detail.w, h = actionH }
	local columns = math.max(1, math.floor((list.w - 16 + gap) / (cellW + gap)))
	return {
		panel = { x = (viewport.X - w) / 2, y = panelTop or topInset + 12 + (availableH - h) / 2, w = w, h = h },
		narrow = narrow, compact = compact, padding = padding, gap = gap, headerH = headerH, tabsY = tabsY, tabsH = tabsH,
		contentY = contentY, contentH = contentH, footerY = footerY, footerH = footerH, summaryH = summaryH,
		list = list, detail = detail, action = action, more = { x = 0, y = 0, w = 0, h = 0 }, cellW = cellW, cellH = cellH, columns = columns, wide = false,
	}
end

local rarityIndex: { [string]: number } = {}
for index, id in Config.RarityOrder do rarityIndex[id] = index end
local function rarityOf(id: string): number
	local def = Pets.def(id)
	return if def then rarityIndex[def.Rarity] else 0
end
local catalogIndex: { [string]: number } = {}
for index, pet in Config.List do catalogIndex[pet.Id] = index end

-- The PETS tab: what you own, the ones out first, then rarest and highest level first.
function PetsLayout.ownedOrder(saved: Pets.Saved?): { string }
	local ids: { string } = {}
	if not saved then return ids end
	for id in saved.owned do
		if catalogIndex[id] then table.insert(ids, id) end
	end
	local out: { [string]: boolean } = {}
	for _, id in saved.equipped do out[id] = true end
	table.sort(ids, function(a, b)
		if (out[a] == true) ~= (out[b] == true) then return out[a] == true end
		local ra, rb = rarityOf(a), rarityOf(b)
		if ra ~= rb then return ra > rb end
		local la, lb = saved.owned[a].level, saved.owned[b].level
		if la ~= lb then return la > lb end
		return catalogIndex[a] < catalogIndex[b]
	end)
	return ids
end

-- The INDEX tab: every pet in the catalogue, by rarity then catalogue order.
function PetsLayout.indexOrder(): { string }
	local ids: { string } = {}
	for _, pet in Config.List do table.insert(ids, pet.Id) end
	table.sort(ids, function(a, b)
		local ra, rb = rarityOf(a), rarityOf(b)
		if ra ~= rb then return ra < rb end
		return catalogIndex[a] < catalogIndex[b]
	end)
	return ids
end

function PetsLayout.discovered(saved: Pets.Saved?): number
	local count = 0
	if not saved then return 0 end
	for _, pet in Config.List do
		if saved.owned[pet.Id] then count += 1 end
	end
	return count
end

-- "+7.5%" without trailing zeros
function PetsLayout.percent(value: number): string
	return string.format("+%g%%", math.floor(value * 10000 + 0.5) / 100)
end

export type PerkRow = { role: string, name: string, now: string, max: string, text: string }

-- A pet's perks as the menu shows them: the value now, the value at max level and the plain-English line.
function PetsLayout.perkRows(def: Config.Pet, level: number): { PerkRow }
	local rows: { PerkRow } = {}
	local atMax = Pets.perksOf(def, Config.MaxLevel)
	for index, perk in Pets.perksOf(def, level) do
		local role = Config.Roles[perk.role]
		table.insert(rows, {
			role = perk.role, name = role.Name, now = PetsLayout.percent(perk.value), max = PetsLayout.percent(atMax[index].value),
			text = string.format(role.Text, string.format("%g%%", math.floor(perk.value * 10000 + 0.5) / 100)),
		})
	end
	return rows
end

-- The eggs that can drop a pet (empty for pass pets)
function PetsLayout.eggsFor(def: Config.Pet): { Config.Egg }
	local eggs: { Config.Egg } = {}
	if def.Pass then return eggs end
	for _, egg in Config.Eggs do
		if (egg.Odds[def.Rarity] or 0) > 0 then table.insert(eggs, egg) end
	end
	return eggs
end

return PetsLayout
