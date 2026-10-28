--!strict
-- Pure helpers behind FeedbackService: tidying a player's text, the Discord proxy URL and the capped inbox.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Feedback = {}

-- The player's text trimmed and cut to MaxLength, or nil when it is too short to send
function Feedback.clean(text: any): string?
	if typeof(text) ~= "string" then
		return nil
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	trimmed = string.sub(trimmed, 1, Config.Feedback.MaxLength)
	return if #trimmed >= Config.Feedback.MinLength then trimmed else nil
end

-- Discord refuses requests from Roblox servers, so a Discord webhook is sent through the public
-- webhook proxy at webhook.lewisakura.moe (same path). Any other URL is used as it is.
function Feedback.proxied(url: string): string
	return (string.gsub(url, "^https://discord%.com/api/webhooks/", "https://webhook.lewisakura.moe/api/webhooks/", 1)
		:gsub("^https://discordapp%.com/api/webhooks/", "https://webhook.lewisakura.moe/api/webhooks/", 1))
end

-- The inbox with `entry` added at the front, keeping the newest Keep
function Feedback.push(inbox: { any }?, entry: any): { any }
	local out = { entry }
	for _, old in inbox or {} do
		if #out >= Config.Feedback.Keep then
			break
		end
		table.insert(out, old)
	end
	return out
end

return Feedback
