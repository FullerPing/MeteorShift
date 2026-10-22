--!strict
-- Profile v13 to v14: a rebirth used to multiply bar sales x5 (x2 a rank past the 16th) and now multiplies them x2.
-- A returning player's rebirth count becomes the smallest new rank whose multiplier is at least the old one, so their
-- bars sell for at least what they did (rank 11 becomes 26). Cash, gear, pets and everything else stay as saved.
-- The old constants live here only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Shared.Rebirth)

local OLD_CASH_MULT = 5
local OLD_LISTED = 16 -- ranks the old x5 covered; past them each rank was x2
local OLD_LEGACY_MULT = 2

local RebirthMigration = {}

-- The old sale multiplier of `rebirths`
function RebirthMigration.oldMultiplier(rebirths: number): number
	local listed = math.min(rebirths, OLD_LISTED)
	return OLD_CASH_MULT ^ listed * OLD_LEGACY_MULT ^ math.max(rebirths - OLD_LISTED, 0)
end

-- The new rebirth count for a saved old one: the smallest whose multiplier is at least the old multiplier
function RebirthMigration.rank(saved: any): number
	if type(saved) ~= "number" or saved ~= saved or saved <= 0 then
		return 0
	end
	local old = math.floor(math.min(saved, 1e4))
	local target = RebirthMigration.oldMultiplier(old) * (1 - 1e-9) -- float slack: 2^n meets 5^k exactly where it should
	local rank = old
	while Rebirth.multiplier(rank) < target do
		rank += 1
	end
	return rank
end

return RebirthMigration
