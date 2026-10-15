--!strict
-- How the Store panel is laid out: one scrolling page of titled sections (the pass and
-- product keys of Config.Monetization), plus a tab on the left for each section that
-- jumps to it. `Style` picks the card: "tile" (icon on top, 3 across) or "wide" (icon on the
-- left, 2 across; a wide section with a single card is a full-width banner). `Color` tints the
-- section's icon wells (gold, blue, orange, green or purple; see NativeMenus.Store). Every pass and product
-- appears in exactly one section or in Elsewhere (checked by tests/StoreLayout.spec).

export type Section = {
	Id: string,
	Title: string,
	Tab: string?, -- tab caption; no tab when nil
	Icon: string, -- Config.HudIcons name for the tab
	Color: string,
	Style: "tile" | "wide",
	Keys: { string },
}

local Store = {}

-- Passes and products that are sold somewhere other than the Store panel
Store.Elsewhere = {
	TwoXOre = "an icon in the game (OfferController)",
	TwoXCash = "an icon in the game (OfferController)",
	RebirthKeep = "a button in the Rebirth menu",
} :: { [string]: string }

Store.Sections = {
	-- the one-per-player value pack opens the page as a full-width banner (the in-game offer icon sells it too)
	{ Id = "featured", Title = "FEATURED", Tab = "Featured", Icon = "bars", Color = "gold", Style = "wide", Keys = { "StarterPack" } },
	{ Id = "passes", Title = "PASSES", Tab = "Passes", Icon = "premium", Color = "gold", Style = "wide",
		Keys = { "BiggerBackpack", "OfflineHours", "AutoDeposit", "VIP", "Drillbot", "SolarPhoenix" } },
	{ Id = "shards", Title = "CORE SHARDS", Tab = "Shards", Icon = "crystal", Color = "blue", Style = "tile",
		Keys = { "Shards50", "Shards250", "Shards1000" } },
	{ Id = "meteors", Title = "METEORS", Tab = "Meteors", Icon = "meteor", Color = "orange", Style = "tile",
		Keys = { "CallMeteor", "BossMeteor", "OreRush" } },
	{ Id = "cash", Title = "CASH", Tab = "Cash", Icon = "coin", Color = "green", Style = "tile",
		Keys = { "PocketChange", "CashBundle" } },
	{ Id = "boosts", Title = "BOOSTS", Tab = "Boosts", Icon = "foundry", Color = "purple", Style = "tile",
		Keys = { "Overclock", "MiniOverclock", "StreakShield" } },
	{ Id = "pets", Title = "PETS", Tab = "Pets", Icon = "pets", Color = "purple", Style = "tile",
		Keys = { "PetSlot", "PetMax" } },
	{ Id = "support", Title = "SUPPORT", Icon = "premium", Color = "blue", Style = "tile", Keys = { "TipJar" } },
} :: { Section }

return Store
