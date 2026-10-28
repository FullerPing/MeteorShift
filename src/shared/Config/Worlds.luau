--!strict
-- The worlds (docs/design/world-2-nebula-rift.md): each is its own place in this universe, running the same scripts.
-- Shared.Worlds tells a server which world it is (by game.PlaceId) and whether a player may travel there.
-- PlaceIds: the live game's place first, then the "Testing MeteorMine" game's; a server is this world if its place is
-- either one, and it travels to the place in the same slot (live to live, testing to testing). 0 = not created yet.
-- World 1 also covers any place not listed (Studio copies).
export type World = { Id: number, Name: string, PlaceIds: { number }, Unlock: { Rebirths: number }?,
	Color: Color3 } -- Color: its card in the TELEPORT menu and its welcome banner

return {
	List = {
		{ Id = 1, Name = "Caldera Terraces", PlaceIds = { 113476105600560, 71172107370266 }, Color = Color3.fromRGB(110, 210, 110) },
		{ Id = 2, Name = "Nebula Rift", PlaceIds = { 117824341220394, 80747941311181 }, Unlock = { Rebirths = 25 }, Color = Color3.fromRGB(138, 92, 255) },
	} :: { World },
}
