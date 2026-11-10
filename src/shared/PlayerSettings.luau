--!strict
-- The Settings menu toggles that are saved on the profile (data.settings), with their defaults. The client keeps
-- each as a player attribute of the same name; PlayerStateService:SetSetting saves a change. Pure.

local PlayerSettings = {}

PlayerSettings.Defaults = {
	HudShowGuide = true,
	HudShowEventTips = true,
	ReduceCameraShake = false,
	ReduceEffects = false,
	MusicOn = true,
	SfxOn = true,
} :: { [string]: boolean }

-- A saved settings table with only known names and boolean values
function PlayerSettings.clean(saved: any): { [string]: boolean }
	local out = {}
	if type(saved) == "table" then
		for name in PlayerSettings.Defaults do
			if type(saved[name]) == "boolean" then
				out[name] = saved[name]
			end
		end
	end
	return out
end

return PlayerSettings
