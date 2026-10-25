--!strict
return function(t)
	local LikeGoal = require(t.shared.LikeGoal)

	t.test("reads the upvotes from a games/votes reply", function()
		t.eq(LikeGoal.likes({ data = { { id = 1, upVotes = 9, downVotes = 4 } } }), 9)
		t.eq(LikeGoal.likes({ data = {} }), nil, "no row")
		t.eq(LikeGoal.likes({ errors = { { code = 0 } } }), nil, "an error reply")
		t.eq(LikeGoal.likes("<html>"), nil, "not json")
		t.eq(LikeGoal.likes({ data = { { upVotes = -1 } } }), nil, "nonsense count")
	end)

	t.test("aims at the first goal above the likes", function()
		local goals = { 20, 50, 100 }
		t.eq(LikeGoal.goal(goals, 0), 20)
		t.eq(LikeGoal.goal(goals, 19), 20)
		t.eq(LikeGoal.goal(goals, 20), 50, "a reached goal moves on")
		t.eq(LikeGoal.goal(goals, 100), nil, "every goal passed")
	end)
end
