--!strict
-- The worlds (docs/design/world-2-nebula-rift.md): each is its own place in this universe, running the same scripts.
-- Shared.Worlds tells a server which world it is (by game.PlaceId) and whether a player may travel there.
-- PlaceId 0 = the place isn't created yet; World 1 also covers any place not listed (Studio copies, test places).
export type World = { Id: number, Name: string, PlaceId: number, Unlock: { Rebirths: number }? }

return {
	List = {
		{ Id = 1, Name = "Caldera Terraces", PlaceId = 0 },
		{ Id = 2, Name = "Nebula Rift", PlaceId = 0, Unlock = { Rebirths = 25 } },
	} :: { World },
}
