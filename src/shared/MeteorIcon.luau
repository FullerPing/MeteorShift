--!strict
local HudIcons = require(script.Parent.Config.HudIcons)
local MeteorIcon = {}
local keys: { [string]: string } = table.freeze({
	Crystal = "meteorCrystal",
	Ice = "meteorIce",
	Frost = "meteorIce",
	Alien = "meteorAlien",
})

function MeteorIcon.resolve(typeId: string?): string
	local key = keys[typeId or ""]
	local image = if key then HudIcons[key] else nil
	return if typeof(image) == "string" and image ~= "" then image else HudIcons.meteor
end

return table.freeze(MeteorIcon)
