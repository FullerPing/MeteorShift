--!strict
-- Bind an authored offline-production report. HUDController retains the report
-- state and its Escape/ButtonB dismissal; this module creates no GUI controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Format)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local NativeUI = require(script.Parent.NativeUI)
local Menu = require(script.Parent.NativeMenus.WelcomeBack)
local WelcomeBack = {}

-- "2h 14m", "40m", "1m"
local function duration(seconds: number): string
	local minutes = math.max(1, math.floor(seconds / 60))
	local hours = math.floor(minutes / 60)
	if hours >= 1 then
		local rest = minutes % 60
		return if rest > 0 then string.format("%dh %dm", hours, rest) else string.format("%dh", hours)
	end
	return string.format("%dm", minutes)
end

-- The line under the offline time: why the line stopped, if it did, then where to pick the bars up
local function noteText(report: any): string
	if report.blocked == "hopper" then return "Your hopper ran dry. Fill it up before you log off!" end
	if report.blocked == "collector" then return "Your collection post filled up. Upgrade it to store more!" end
	if report.capped then return "The Offline Training perk keeps your line going longer. Pick your bars up at the Foundry." end
	return "Pick your bars up at the Foundry, then sell them at the Trading Post."
end

function WelcomeBack.start(onDismiss: () -> ()): (any?) -> ()
	local gui = NativeUI.getFresh("WelcomeBack", Menu.build, Menu.LAYOUT)
	local panel = gui:WaitForChild("Panel") :: Frame
	local intro = panel:WaitForChild("Intro") :: TextLabel
	local report = panel:WaitForChild("Report") :: Frame
	local bars = report:WaitForChild("Bars"):WaitForChild("Value") :: TextLabel
	local worth = report:WaitForChild("Worth"):WaitForChild("Value") :: TextLabel
	local time = panel:WaitForChild("Time") :: Frame
	local used = time:WaitForChild("Used") :: TextLabel
	local fill = time:WaitForChild("Bar"):WaitForChild("Fill") :: Frame
	local note = panel:WaitForChild("Note") :: TextLabel
	local nice = panel:WaitForChild("Nice") :: TextButton
	local close = panel:WaitForChild("Close") :: TextButton
	local dimmer = gui:WaitForChild("Dimmer") :: TextButton
	local function dismiss()
		if not gui.Enabled then return end
		gui.Enabled = false
		onDismiss()
	end
	nice.Activated:Connect(dismiss)
	close.Activated:Connect(dismiss)
	dimmer.Activated:Connect(dismiss)
	NativeUI.fitWhole(panel, Menu.SIZE)
	gui.Enabled = false
	return function(data: any?)
		gui.Enabled = data ~= nil
		if not data then return end
		intro.Text = string.format("While you were away for <font color=\"#%s\">%s</font>, your production line kept working.",
			Palette.UP:ToHex(), duration(data.away))
		bars.Text = Format.number(data.bars)
		worth.Text = Format.cash(data.value)
		-- the cap only shows when it was hit: the time used of the cap, a full orange bar
		local capped = data.capped == true
		used.Text = if capped then duration(data.seconds) .. " of " .. duration(data.seconds) .. " · capped" else duration(data.seconds)
		used.TextColor3 = if capped then Palette.UNMET else Palette.UP
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = if capped then Palette.ORANGE_FILL else Palette.LIME_BOTTOM
		note.Text = noteText(data)
	end
end

return WelcomeBack
