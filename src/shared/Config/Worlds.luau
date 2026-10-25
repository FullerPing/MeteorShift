--!strict
-- The worlds (docs/design/world-2-nebula-rift.md): each is its own place in this universe, running the same scripts.
-- Shared.Worlds tells a server which world it is (by game.PlaceId) and whether a player may travel there.
-- PlaceId 0 = the place isn't created yet; World 1 also covers any place not listed (Studio copies, test places).
export type World = { Id: number, Name: string, PlaceId: number, Unlock: { Rebirths: number }?,
	Color: Color3 } -- Color: its card in the TELEPORT menu and its welcome banner

return {
	List = {
		{ Id = 1, Name = "Caldera Terraces", PlaceId = 113476105600560, Color = Color3.fromRGB(110, 210, 110) },
		{ Id = 2, Name = "Nebula Rift", PlaceId = 117824341220394, Unlock = { Rebirths = 25 }, Color = Color3.fromRGB(138, 92, 255) },
	} :: { World },
}
