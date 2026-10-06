--!strict
-- Pure workshop presentation: decorative slots summarize actual stock without
-- changing it, and station upgrade pieces unlock at their own minimum level.
local Presentation = {}

-- Keep the existing meteor ore identities. Bars have a lighter finished surface.
local ORE_COLORS: { [string]: Color3 } = {
	iron = Color3.fromRGB(196, 170, 150),
	frost = Color3.fromRGB(96, 226, 255),
	crystal = Color3.fromRGB(255, 122, 214),
}
local NEUTRAL = Color3.fromRGB(144, 144, 144)
local WHITE = Color3.new(1, 1, 1)

function Presentation.fillCount(amount: any): number
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	-- One ore still shows one piece; large inventories never create more than
	-- the eight authored slots. Fractions cannot make negative slot counts.
	if amount < 1 then return 1 end
	if amount >= 128 then return 8 end
	return 1 + math.floor(math.log(amount, 2))
end

local function safeLevel(value: any): number
	return if type(value) == "number" and value == value and value >= 1 and value < math.huge then math.floor(value) else 1
end

function Presentation.levelVisible(level: any, minLevel: any): boolean
	return safeLevel(level) >= safeLevel(minLevel)
end

function Presentation.color(oreId: string, payload: "ore" | "bar"): Color3
	local ore = ORE_COLORS[oreId] or NEUTRAL
	return if payload == "bar" then ore:Lerp(WHITE, 0.24) else ore
end

return Presentation
