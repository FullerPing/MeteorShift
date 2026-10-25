--!strict
-- Rules for the like goal sign (Config.LikeGoal): reading the like count from a games/votes reply and picking the goal.
local LikeGoal = {}

-- The upvotes in a decoded games/votes reply ({ data = { { id, upVotes, downVotes } } }), or nil when it isn't one
function LikeGoal.likes(reply: any): number?
	local row = type(reply) == "table" and type(reply.data) == "table" and reply.data[1]
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
