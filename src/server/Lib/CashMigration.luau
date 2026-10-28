--!strict
-- Profile v13 to v14: rebirths used to raise every cash price x3 (x1.2 a rank past the 16th); now prices never rise.
-- The rebirth count stays as saved, and saved cash is divided by the old price multiplier so it buys what it did
-- (owner, 2026-10-24). The old constants live here only.
local OLD_PRICE_GROWTH = 3
local OLD_LISTED = 16 -- ranks the old x3 covered
local OLD_LEGACY_GROWTH = 1.2

local CashMigration = {}

-- The old cash price multiplier of `rebirths`
function CashMigration.oldPriceMult(rebirths: any): number
	local n = if type(rebirths) == "number" and rebirths == rebirths and rebirths > 0 then math.floor(math.min(rebirths, 1e4)) else 0
	return OLD_PRICE_GROWTH ^ math.min(n, OLD_LISTED) * OLD_LEGACY_GROWTH ^ math.max(n - OLD_LISTED, 0)
end

-- Saved cash at `rebirths` in today's flat prices (bad or negative amounts become 0)
function CashMigration.convert(cash: any, rebirths: any): number
	if type(cash) ~= "number" or cash ~= cash or cash <= 0 then
		return 0
	end
	return math.floor(cash / CashMigration.oldPriceMult(rebirths))
end

return CashMigration
