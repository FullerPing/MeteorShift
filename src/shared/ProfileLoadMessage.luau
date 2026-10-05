--!strict
-- Player-facing load failures; raw DataStore details stay in server warnings.

local ProfileLoadMessage = {}

function ProfileLoadMessage.message(reason: string): string
	if reason == "unavailable" then
		return "Saving is temporarily unavailable. Please rejoin in a few minutes so your progress can be saved."
	elseif reason == "locked" then
		return "Your save is still open on another server. Please leave that session, wait a minute, and rejoin."
	end
	return "A temporary error stopped us loading your save. Please rejoin in a minute."
end

return ProfileLoadMessage
