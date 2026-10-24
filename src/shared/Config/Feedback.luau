--!strict
-- The feedback prompt (FeedbackPromptController, FeedbackService): the first time a session reaches AskAfter seconds
-- of play (once per player, ever) a small card asks "Got feedback?"; YES opens a box whose text is saved for the team and, when
-- ServerStorage has a FeedbackWebhook attribute (a Discord webhook URL, kept out of git), posted to Discord.

return {
	AskAfter = 30 * 60, -- seconds of play in one session before the card shows (only the first time ever)
	MaxLength = 500, -- characters a player can send
	MinLength = 3,
	Cooldown = 60, -- seconds between two sends from one player
	PerSession = 3, -- sends one player can make in a session
	FavoriteDelay = 4, -- seconds after the first rebirth (once ever) before Roblox's favorite prompt, after the celebration
	Keep = 200, -- newest messages kept in the saved inbox (/feedback reads them)
}
