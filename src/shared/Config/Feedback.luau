--!strict
-- The feedback prompt (FeedbackPromptController, FeedbackService): after AskAfter seconds of play in one
-- session a small card asks "Got feedback?"; YES opens a box whose text is saved for the team and, when
-- ServerStorage has a FeedbackWebhook attribute (a Discord webhook URL, kept out of git), posted to Discord.

return {
	AskAfter = 30 * 60, -- seconds of play in this session before the card shows (once a session)
	MaxLength = 500, -- characters a player can send
	MinLength = 3,
	Cooldown = 60, -- seconds between two sends from one player
	PerSession = 3, -- sends one player can make in a session
	Keep = 200, -- newest messages kept in the saved inbox (/feedback reads them)
}
