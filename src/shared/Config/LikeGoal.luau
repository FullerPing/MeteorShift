--!strict
-- The like goal hologram by the crater (Map.TownSquare.LikeGoal.Anchor, drawn by LikeGoalService). Roblox servers may not
-- call roblox.com, so the count comes through a public mirror of the games API (`%d` is the universe id); when the
-- mirror fails the sign shows the goal without a count.
return {
	-- the sign aims at the first goal above the current likes; past the last it thanks everyone
	Goals = { 20, 50, 100, 250, 500, 1000, 2500, 5000, 10000 },
	Reward = "LIKE FOR NEW CODES!", -- the line under the bar
	Url = "https://games.roproxy.com/v1/games/votes?universeIds=%d",
	RefreshSeconds = 120,
}
