--!strict
-- Which world a server is (Config.Worlds) and who may travel to each. Pure: callers pass game.PlaceId, whether this
-- is Studio and workspace's DevWorld attribute (a Studio-only override, so one place file can test either world).
local Config = require(script.Parent.Config.Worlds)

local Worlds = {}

function Worlds.find(id: any): Config.World?
	for _, world in Config.List do
		if world.Id == id then return world end
	end
	return nil
end

function Worlds.current(placeId: number, studio: boolean, override: any): Config.World
	local forced = if studio then Worlds.find(override) else nil
	if forced then return forced end
	for _, world in Config.List do
		if world.PlaceId ~= 0 and world.PlaceId == placeId then return world end
	end
	return Config.List[1]
end

function Worlds.isOpen(world: Config.World, rebirths: number): boolean
	return world.Unlock == nil or rebirths >= world.Unlock.Rebirths
end

return Worlds
