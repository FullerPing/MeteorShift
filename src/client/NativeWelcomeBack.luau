--!strict
-- Bind an authored offline-production report. HUDController retains the report
-- state and its Escape/ButtonB dismissal; this module creates no GUI controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Format)
local NativeUI = require(script.Parent.NativeUI)
local WelcomeBack = {}

-- Preserve the existing while-away report copy and formatting exactly.
local function formatReport(report: any): string
	if not report then return "" end
	local hours = report.away / 3600
	local awayText = if hours >= 1
		then string.format("%.1f hours", hours)
		else string.format("%d minutes", math.floor(report.away / 60))
	local lines = {
		"You were gone " .. awayText .. ".",
		"Your production line made " .. Format.number(report.bars) .. " bars (" .. Format.cash(report.value) .. ").",
	}
	if report.capped then
		table.insert(lines, "Offline time is capped at " .. math.floor(report.seconds / 3600) .. " hours.")
	end
	if report.blocked == "hopper" then
		table.insert(lines, "Your hopper ran dry. Fill it up before you log off!")
	elseif report.blocked == "collector" then
		table.insert(lines, "Your collection post filled up. Upgrade it to store more!")
	end
	table.insert(lines, "Pick them up at the refinery.")
	return table.concat(lines, "\n")
end

function WelcomeBack.start(onDismiss: () -> ()): (any?) -> ()
	local gui = NativeUI.get("WelcomeBack")
	local panel = gui:WaitForChild("Panel") :: Frame
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local reportText = body:WaitForChild("Report") :: TextLabel
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
	NativeUI.onLayoutChanged(function(layout)
		local width = math.min(390, math.max(1, layout.viewport.X - 24))
		local height = math.min(260, math.max(1, layout.viewport.Y - layout.inset - 24))
		panel.AnchorPoint = Vector2.zero
		panel.Position = UDim2.fromOffset((layout.viewport.X - width) / 2, layout.inset + (layout.viewport.Y - layout.inset - height) / 2)
		panel.Size = UDim2.fromOffset(width, height)
		body.Size = UDim2.new(1, -36, 0, math.max(0, height - 128))
	end)
	gui.Enabled = false
	return function(report: any?)
		gui.Enabled = report ~= nil
		reportText.Text = formatReport(report)
		if report then body.CanvasPosition = Vector2.zero end
	end
end

return WelcomeBack
