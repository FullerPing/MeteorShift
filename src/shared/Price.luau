--!strict
-- Prices in cash + Core Shards (spec §7): the text shown for them and the
-- "you can't afford this" message. Shared so the shop, the station prompts and
-- the server's checks all say the same thing.

local Format = require(script.Parent.Format)

local Price = {}

export type Wallet = { cash: number, shards: number }

-- "$750", "$1.2M + 25 ◆", "Free"
function Price.text(cash: number, shards: number): string
	if cash <= 0 and shards <= 0 then
		return "Free"
	end
	local text = if cash > 0 then Format.cash(cash) else ""
	if shards > 0 then
		text ..= (if text ~= "" then " + " else "") .. shards .. " ◆"
	end
	return text
end

function Price.canAfford(wallet: Wallet, cash: number, shards: number): boolean
	return wallet.cash >= cash and wallet.shards >= shards
end

-- Why the wallet can't pay for `what`, or nil when it can.
function Price.shortfall(wallet: Wallet, cash: number, shards: number, what: string): string?
	if wallet.cash < cash then
		return string.format("Need %s for %s (you have %s).", Format.cash(cash), what, Format.cash(wallet.cash))
	end
	if wallet.shards < shards then
		return string.format("Need %d Core Shards for %s. Crack meteor cores to earn them!", shards, what)
	end
	return nil
end

return Price
