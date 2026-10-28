--!strict
-- The feedback prompt (Config.Feedback): the first time a session passes half an hour of play (once per player, ever:
-- FeedbackService:ShouldAsk), a small card at the right edge asks "Got feedback?". NO (or ignoring it for a minute) puts it away for the session; YES turns it into a writing box
-- in the middle of the screen whose SEND goes to FeedbackService, which keeps it for the team.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local Theme = require(script.Parent.Parent.MenuTheme)
local N = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer

local FeedbackPromptController = Knit.CreateController({ Name = "FeedbackPromptController" })

local ASK = Vector2.new(300, 132)
local WRITE = Vector2.new(460, 300)
local IGNORED_AFTER = 60 -- seconds the question waits before tucking itself away

function FeedbackPromptController:KnitStart()
	local FeedbackService = Knit.GetService("FeedbackService")
	-- once ever, after a rebirth: Roblox's favorite prompt, then a note asking for a like (no API can prompt a like)
	FeedbackService.AskFavorite:Connect(function()
		local AvatarEditorService = game:GetService("AvatarEditorService")
		local StarterGui = game:GetService("StarterGui")
		local function likeNote()
			pcall(function()
				StarterGui:SetCore("SendNotification", { Title = "Enjoying the game?", Text = "A thumbs up on the game page helps us a lot. Thanks!", Duration = 8 })
			end)
		end
		AvatarEditorService.PromptSetFavoriteCompleted:Once(likeNote)
		local ok = pcall(function() AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
		if not ok then likeNote() end
	end)
	local started = os.clock()
	task.delay(Config.Feedback.AskAfter, function()
		local ok, ask = pcall(function() return FeedbackService:ShouldAsk() end)
		if not ok or ask ~= true then return end
		local gui = N.create("ScreenGui", { Name = "FeedbackPrompt", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
		local panel = Theme.panel(gui, "Panel", UDim2.fromOffset(ASK.X, ASK.Y))
		panel.AnchorPoint, panel.Position = Vector2.new(1, 0.5), UDim2.new(1, -16, 0.55, 0)
		local scale = N.create("UIScale", { Scale = 0 }, panel) :: UIScale
		local camera = workspace.CurrentCamera
		local function fit(size: Vector2): number
			return math.min(1, (camera.ViewportSize.X - 32) / size.X, (camera.ViewportSize.Y - 32) / size.Y)
		end
		local function close()
			local away = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			away.Completed:Connect(function() gui:Destroy() end)
			away:Play()
		end

		-- the question
		local ask = N.create("Frame", { Name = "Ask", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, panel)
		Theme.icon(ask, "Icon", "settings", UDim2.fromOffset(16, 14), UDim2.fromOffset(40, 40)).ZIndex = 3
		local title = Theme.label(ask, "Title", "Got feedback?", 26, Palette.NAVY, Theme.TITLE_FONT, Enum.TextXAlignment.Left)
		title.Position, title.Size, title.ZIndex = UDim2.fromOffset(64, 12), UDim2.fromOffset(ASK.X - 80, 30), 3
		local sub = Theme.label(ask, "Sub", "Tell the dev what to fix or add!", 15, Palette.NAVY, nil, Enum.TextXAlignment.Left)
		sub.Position, sub.Size, sub.ZIndex = UDim2.fromOffset(64, 42), UDim2.fromOffset(ASK.X - 80, 20), 3
		local yes = Theme.button(ask, "Yes", "YES", "lime", 20)
		yes.Position, yes.Size = UDim2.fromOffset(16, 72), UDim2.fromOffset((ASK.X - 44) / 2, 46)
		local no = Theme.button(ask, "No", "NO THANKS", "red", 18)
		no.Position, no.Size = UDim2.fromOffset(28 + (ASK.X - 44) / 2, 72), UDim2.fromOffset((ASK.X - 44) / 2, 46)

		-- the writing box
		local write = N.create("Frame", { Name = "Write", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Visible = false }, panel)
		local heading = Theme.label(write, "Title", "Your feedback", 26, Palette.NAVY, Theme.TITLE_FONT, Enum.TextXAlignment.Left)
		heading.Position, heading.Size, heading.ZIndex = UDim2.fromOffset(20, 12), UDim2.fromOffset(WRITE.X - 40, 30), 3
		local well = Theme.whiteCard(write, "Well", 12)
		well.Position, well.Size, well.ZIndex = UDim2.fromOffset(20, 50), UDim2.fromOffset(WRITE.X - 40, 160), 3
		Theme.stroke(well, Palette.NAVY, 2.5)
		local box = N.create("TextBox", {
			Name = "Box", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16), BackgroundTransparency = 1, ZIndex = 4,
			Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = Palette.NAVY, PlaceholderText = "What should we fix or add? What did you like?",
			PlaceholderColor3 = Palette.NAVY:Lerp(Color3.new(1, 1, 1), 0.5), Text = "", ClearTextOnFocus = false, MultiLine = true,
			TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		}, well) :: TextBox
		local count = Theme.label(write, "Count", "", 14, Palette.NAVY, nil, Enum.TextXAlignment.Right)
		count.Position, count.Size, count.ZIndex = UDim2.fromOffset(20, 212), UDim2.fromOffset(WRITE.X - 40, 18), 3
		local send = Theme.button(write, "Send", "SEND", "lime", 20)
		send.Position, send.Size = UDim2.fromOffset(20, 236), UDim2.fromOffset((WRITE.X - 52) / 2, 46)
		local cancel = Theme.button(write, "Cancel", "CANCEL", "red", 18)
		cancel.Position, cancel.Size = UDim2.fromOffset(32 + (WRITE.X - 52) / 2, 236), UDim2.fromOffset((WRITE.X - 52) / 2, 46)

		local busy, answered = false, false
		local function refresh()
			if #box.Text > Config.Feedback.MaxLength then box.Text = string.sub(box.Text, 1, Config.Feedback.MaxLength) end
			count.Text = #box.Text .. " / " .. Config.Feedback.MaxLength
			Theme.state(send, not busy and #(string.match(box.Text, "^%s*(.-)%s*$") or "") >= Config.Feedback.MinLength, "lime")
		end
		box:GetPropertyChangedSignal("Text"):Connect(refresh)

		yes.Activated:Connect(function()
			answered = true
			ask.Visible, write.Visible = false, true
			panel.AnchorPoint, panel.Position, panel.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(WRITE.X, WRITE.Y)
			scale.Scale = fit(WRITE)
			refresh()
			box:CaptureFocus()
		end)
		no.Activated:Connect(function() answered = true; close() end)
		cancel.Activated:Connect(close)
		send.Activated:Connect(function()
			if busy then return end
			busy = true
			send.Text = "SENDING..."
			refresh()
			local ok, accepted = pcall(function() return FeedbackService:Send(box.Text, (os.clock() - started) / 60) end)
			busy = false
			if ok and accepted then
				Sfx.play("Bonus")
				heading.Text = "Thanks! The dev will read it."
				write.Well.Visible, count.Visible, send.Visible, cancel.Visible = false, false, false, false
				task.delay(2, close)
			else
				send.Text = "TRY AGAIN"
				heading.Text = "Couldn't send that. Try again in a minute."
				refresh()
			end
		end)

		gui.Parent = player:WaitForChild("PlayerGui")
		Sfx.play("Bonus")
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit(ASK) }):Play()
		task.delay(IGNORED_AFTER, function()
			if not answered and gui.Parent then close() end
		end)
	end)
end

return FeedbackPromptController
