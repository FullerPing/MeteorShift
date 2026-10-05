--!strict
-- Load failures explain the retry action without claiming every error is a session lock.

return function(t: any)
	local module = t.shared:FindFirstChild("ProfileLoadMessage")
	t.test("profile load messages are available", function()
		t.ok(module ~= nil, "Shared.ProfileLoadMessage is present")
	end)
	if not module then return end
	local ProfileLoadMessage = require(module)

	t.test("an unavailable store explains that saving is temporarily unavailable", function()
		t.eq(ProfileLoadMessage.message("unavailable"), "Saving is temporarily unavailable. Please rejoin in a few minutes so your progress can be saved.")
	end)

	t.test("an active foreign session tells the player to leave that session before retrying", function()
		t.eq(ProfileLoadMessage.message("locked"), "Your save is still open on another server. Please leave that session, wait a minute, and rejoin.")
	end)

	t.test("a transient read failure never blames another server or exposes the store error", function()
		local message = ProfileLoadMessage.message("error: HTTP 503 for private_player_key")
		t.eq(message, "A temporary error stopped us loading your save. Please rejoin in a minute.")
		t.eq(string.find(message, "another server", 1, true), nil)
		t.eq(string.find(message, "private_player_key", 1, true), nil)
	end)

	t.test("only an exact lock reason claims that another session is open", function()
		local temporary = ProfileLoadMessage.message("error: request locked by network failure")
		for _, reason in { "unknown", "error: unavailable", "locked request failed", "" } do
			t.eq(ProfileLoadMessage.message(reason), temporary)
		end
		t.ok(ProfileLoadMessage.message("locked") ~= temporary)
		t.ok(ProfileLoadMessage.message("unavailable") ~= temporary)
	end)
end
