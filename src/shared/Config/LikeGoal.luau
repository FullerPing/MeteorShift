--!strict
-- The like goal hologram by the crater (Map.TownSquare.LikeGoal.Anchor, drawn by LikeGoalService). Roblox servers may not
-- call roblox.com, so the count comes through a public mirror of the games API (a `%d` in Url is filled with the
-- universe id); when the mirror fails the sign shows the /likes count, or the goal without a count.
return {
	-- the sign aims at the first goal above the current likes; past the last it thanks everyone
	Goals = { 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 },
	Reward = "LIKE FOR NEW CODES!", -- the line under the bar
	-- the codes the hologram shows (the public ones; Config.Codes also holds giveaway codes that aren't announced)
	Codes = { "METEOR", "FOXFRIEND" },
	Url = "https://games.roproxy.com/v1/games/10769303069/votes",
	RefreshSeconds = 120,
}
