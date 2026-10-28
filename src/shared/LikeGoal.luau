--!strict
-- Rules for the like goal sign (Config.LikeGoal): reading the like count from a games/votes reply and picking the goal.
local LikeGoal = {}

-- The upvotes in a decoded votes reply, or nil when it isn't one: /v1/games/<id>/votes answers { id, upVotes,
-- downVotes }, /v1/games/votes?universeIds= wraps that row in { data = { ... } }
function LikeGoal.likes(reply: any): number?
	local row = if type(reply) == "table" and type(reply.data) == "table" then reply.data[1] else reply
	local up = type(row) == "table" and row.upVotes
	return if type(up) == "number" and up >= 0 and up == up then math.floor(up) else nil
end

-- The goal the sign aims at: the first one above `likes`, or nil once every goal is passed
function LikeGoal.goal(goals: { number }, likes: number): number?
	for _, goal in goals do
		if likes < goal then return goal end
	end
	return nil
end

return LikeGoal
