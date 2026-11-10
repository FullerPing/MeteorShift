--!strict
-- Spec for Lib.Feedback: tidying a player's feedback, the Discord proxy URL and the capped inbox.

return function(t: any)
	local Feedback = require(t.lib.Feedback)
	local Config = require(t.shared.Config).Feedback

	t.test("clean trims, cuts to the limit and refuses too-short or non-text input", function()
		t.eq(Feedback.clean("  more pets please \n"), "more pets please")
		t.eq(Feedback.clean("ok"), nil)
		t.eq(Feedback.clean("     "), nil)
		t.eq(Feedback.clean(42), nil)
		t.eq(#(Feedback.clean(string.rep("a", Config.MaxLength + 50)) :: string), Config.MaxLength)
	end)

	t.test("a Discord webhook goes through the proxy, other URLs are left alone", function()
		t.eq(Feedback.proxied("https://discord.com/api/webhooks/1/abc"), "https://webhook.lewisakura.moe/api/webhooks/1/abc")
		t.eq(Feedback.proxied("https://discordapp.com/api/webhooks/1/abc"), "https://webhook.lewisakura.moe/api/webhooks/1/abc")
		t.eq(Feedback.proxied("https://example.com/hook"), "https://example.com/hook")
	end)

	t.test("the inbox puts the newest first and keeps only Keep", function()
		local inbox = Feedback.push(nil, "a")
		inbox = Feedback.push(inbox, "b")
		t.eq(inbox[1], "b")
		t.eq(inbox[2], "a")
		local full = {}
		for index = 1, Config.Keep do full[index] = index end
		local pushed = Feedback.push(full, "new")
		t.eq(#pushed, Config.Keep)
		t.eq(pushed[1], "new")
		t.eq(pushed[Config.Keep], Config.Keep - 1)
	end)
end
