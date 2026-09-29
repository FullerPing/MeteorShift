--!strict
-- Mineral index (spec §8.2): a collection book with one page per meteor type. Every
-- validated crust or core hit on a meteor rolls that page's minerals at fixed,
-- published odds that nothing purchasable changes (spec §8.1, §9.4: 2x Ore doubles
-- ore, never these odds). Only players whose own pickaxe meets the meteor's
-- RequiredTier roll, and debris never drops minerals. The rarest mineral of each page
-- is RichOnly: it drops only from the few "rich" crust nodes of each meteor, which
-- sparkle in RichColor. Shared.MineralIndex holds the rules.
--
-- Completing a page pays a permanent bonus on bar sales (CashBonus, additive across
-- pages) and a title. The spec's third reward, a décor piece, is left out: there is
-- no décor system yet.

local Index = {}

export type Mineral = {
	Id: string, -- key of the profile's index (mineral id -> count found), unique across pages
	Name: string,
	Odds: number, -- chance per validated crust or core hit
	RichOnly: boolean, -- drops only from rich crust nodes
	Color: Color3,
}

export type Page = {
	Id: string, -- the meteor type it belongs to (Config.Meteor.Types)
	Name: string,
	Minerals: { Mineral }, -- most common first
	CashBonus: number, -- added to the bar sale multiplier once the page is complete
	Title: string,
}

Index.RichNodesPerMeteor = 3 -- crust nodes per meteor that can drop the RichOnly minerals
Index.RichColor = Color3.fromRGB(255, 221, 110) -- the sparkle and ore tint that marks a rich node

Index.PageOrder = { "Iron", "Ice", "Crystal" } -- lowest meteor first; the last completed page gives the best title

Index.Pages = {
	Iron = {
		Id = "Iron",
		Name = "Iron",
		CashBonus = 0.02,
		Title = "Iron Prospector",
		Minerals = {
			{ Id = "magnetite", Name = "Magnetite", Odds = 1 / 25, RichOnly = false, Color = Color3.fromRGB(150, 156, 176) },
			{ Id = "hematiteRose", Name = "Hematite Rose", Odds = 1 / 120, RichOnly = false, Color = Color3.fromRGB(214, 84, 76) },
			{ Id = "meteoricNickel", Name = "Meteoric Nickel", Odds = 1 / 600, RichOnly = false, Color = Color3.fromRGB(214, 218, 196) },
			{ Id = "starfallIron", Name = "Starfall Iron", Odds = 1 / 2500, RichOnly = true, Color = Color3.fromRGB(255, 160, 64) },
		},
	} :: Page,
	Ice = {
		Id = "Ice",
		Name = "Ice",
		CashBonus = 0.02,
		Title = "Frost Walker",
		Minerals = {
			{ Id = "rimePearl", Name = "Rime Pearl", Odds = 1 / 25, RichOnly = false, Color = Color3.fromRGB(226, 240, 250) },
			{ Id = "frostOpal", Name = "Frost Opal", Odds = 1 / 120, RichOnly = false, Color = Color3.fromRGB(140, 232, 226) },
			{ Id = "glacialSapphire", Name = "Glacial Sapphire", Odds = 1 / 600, RichOnly = false, Color = Color3.fromRGB(72, 136, 240) },
			{ Id = "heartOfWinter", Name = "Heart of Winter", Odds = 1 / 2500, RichOnly = true, Color = Color3.fromRGB(150, 246, 255) },
		},
	} :: Page,
	Crystal = {
		Id = "Crystal",
		Name = "Crystal",
		CashBonus = 0.02,
		Title = "Crystal Seer",
		Minerals = {
			{ Id = "prismShard", Name = "Prism Shard", Odds = 1 / 25, RichOnly = false, Color = Color3.fromRGB(255, 196, 240) },
			{ Id = "amethystSpire", Name = "Amethyst Spire", Odds = 1 / 120, RichOnly = false, Color = Color3.fromRGB(172, 104, 232) },
			{ Id = "resonantQuartz", Name = "Resonant Quartz", Odds = 1 / 600, RichOnly = false, Color = Color3.fromRGB(255, 120, 206) },
			{ Id = "voidDiamond", Name = "Void Diamond", Odds = 1 / 2500, RichOnly = true, Color = Color3.fromRGB(150, 92, 255) },
		},
	} :: Page,
} :: { [string]: Page }

return Index
