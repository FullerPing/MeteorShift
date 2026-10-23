--!strict
-- The two leaderboards beside the Foundry (Map.TownSquare.Leaderboards.<Id>.Screen). LeaderboardService saves each
-- online player's score to the board's OrderedDataStore and shows the top rows of every server; when DataStores are
-- unavailable (an unpublished Studio place) it ranks the players in this server instead.
export type Board = { Id: string, Title: string, Unit: string, Store: string, Path: { string },
	Time: boolean? } -- Time: the score is seconds, shown as "12h 30m" (Shared.Leaderboards.display)

return {
	RefreshInterval = 60, -- seconds between saving scores and reloading the top rows
	Rows = 10,
	Boards = {
		-- Path: where the score is in the player's profile (Lib.ProfileTemplate)
		{ Id = "BarsSold", Title = "TOP MINERS", Unit = "bars sold", Store = "Leaderboard_BarsSold_v1", Path = { "stats", "barsSold" } },
		{ Id = "Rebirths", Title = "TOP REBIRTHS", Unit = "rebirths", Store = "Leaderboard_Rebirths_v1", Path = { "rebirths" } },
		-- No stand placed for it in the map yet: LeaderboardService clones the last one and continues the row
		{ Id = "Playtime", Title = "TOP PLAYTIME", Unit = "time played", Store = "Leaderboard_Playtime_v1", Path = { "stats", "playSeconds" }, Time = true },
	} :: { Board },
}
