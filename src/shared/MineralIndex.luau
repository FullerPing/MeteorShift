--!strict
-- Mineral index rules (spec §8.2): what a meteor hit drops, page completion and the
-- page rewards. Config.Index holds the pages; a player's index is the profile's
-- `index` table, mineral id -> how many they have found.
--
--   roll           each validated crust or core hit rolls every mineral of the meteor's
--                  page on its own, rarest first, and drops at most one: the first that
--                  hits. Off rich nodes the rich-only mineral is skipped. The odds are
--                  fixed and nothing purchasable reaches this function (spec §8.1, §9.4);
--                  since a rarer mineral that hits first takes the drop, a common one
--                  lands a hair under its published odds
--   pageComplete   every mineral of the page found at least once (found counts them)
--   cashBonus      the bar sale multiplier: 1 plus the CashBonus of each completed page,
--                  additive across pages
--   titles         the titles of the completed pages in page order; the last is the best
--   oddsText       the published odds on each card ("1 in 600, rich nodes only")
--   pickRichNodes  which of a meteor's crust nodes are rich
--
-- Pure functions only (callers pass the rng and the index), so the rules are covered
-- by tests/MineralIndex.spec.

local Index = require(script.Parent.Config.Index)
local Format = require(script.Parent.Format)

type Mineral = Index.Mineral
type Page = Index.Page

export type PlayerIndex = { [string]: number } -- mineral id -> count found

local Pages = Index.Pages
local PageOrder = Index.PageOrder

local MineralIndex = {}

-- Each page's minerals sorted rarest first, the order roll draws them in
local rarestFirst: { [string]: { Mineral } } = {}
for pageId, page in Pages do
	local sorted = table.clone(page.Minerals)
	table.sort(sorted, function(a, b)
		return a.Odds < b.Odds
	end)
	rarestFirst[pageId] = sorted
end

-- The mineral one hit on this page's meteor drops, or nil. `rng` returns a uniform
-- number in [0, 1) and is called once per mineral rolled.
function MineralIndex.roll(pageId: string, isRichNode: boolean, rng: () -> number): string?
	local minerals = rarestFirst[pageId]
	if not minerals then
		return nil
	end
	for _, mineral in minerals do
		if (isRichNode or not mineral.RichOnly) and rng() < mineral.Odds then
			return mineral.Id
		end
	end
	return nil
end

-- How many of the page's minerals the player has found.
function MineralIndex.found(index: PlayerIndex, pageId: string): number
	local page = Pages[pageId]
	if not page then
		return 0
	end
	local found = 0
	for _, mineral in page.Minerals do
		if (index[mineral.Id] or 0) > 0 then
			found += 1
		end
	end
	return found
end

function MineralIndex.pageComplete(index: PlayerIndex, pageId: string): boolean
	local page = Pages[pageId]
	return page ~= nil and MineralIndex.found(index, pageId) == #page.Minerals
end

-- Multiplier on bar sales from completed pages (1 with none).
function MineralIndex.cashBonus(index: PlayerIndex): number
	local bonus = 1
	for _, pageId in PageOrder do
		if MineralIndex.pageComplete(index, pageId) then
			bonus += Pages[pageId].CashBonus
		end
	end
	return bonus
end

-- Titles earned, lowest page first; the last one is the player's best.
function MineralIndex.titles(index: PlayerIndex): { string }
	local titles = {}
	for _, pageId in PageOrder do
		if MineralIndex.pageComplete(index, pageId) then
			table.insert(titles, Pages[pageId].Title)
		end
	end
	return titles
end

-- A mineral and the page it is on, by id.
function MineralIndex.find(mineralId: string): (Mineral?, Page?)
	for _, page in Pages do
		for _, mineral in page.Minerals do
			if mineral.Id == mineralId then
				return mineral, page
			end
		end
	end
	return nil, nil
end

-- "1 in 600", plus ", rich nodes only" for a rich-only mineral.
function MineralIndex.oddsText(mineral: { Odds: number, RichOnly: boolean }): string
	local text = "1 in " .. Format.number(math.floor(1 / mineral.Odds + 0.5))
	return if mineral.RichOnly then text .. ", rich nodes only" else text
end

-- Picks RichNodesPerMeteor distinct crust nodes out of `nodeCount` (all of them when
-- there are fewer), as a set of node numbers 1..nodeCount. `rng` is uniform in [0, 1).
function MineralIndex.pickRichNodes(nodeCount: number, rng: () -> number): { [number]: boolean }
	local nodes = {}
	for i = 1, nodeCount do
		nodes[i] = i
	end
	-- Partial Fisher-Yates: the first `count` slots end up a uniform random pick
	local rich = {}
	for i = 1, math.min(Index.RichNodesPerMeteor, nodeCount) do
		local j = math.min(i + math.floor(rng() * (nodeCount - i + 1)), nodeCount)
		nodes[i], nodes[j] = nodes[j], nodes[i]
		rich[nodes[i]] = true
	end
	return rich
end

return MineralIndex
