--!strict
-- Core Shards with the Robux-bought part tracked (data.paidShards). Eggs are random, so under Roblox's paid
-- random items rules a player whose PolicyService says paid random items are restricted may only open eggs
-- with shards they earned. Fixed purchases (perks, evolves) spend bought shards first, keeping earned ones
-- for eggs; eggs spend earned shards first. Pure; covered by tests/ShardWallet.spec.

local ShardWallet = {}

-- Bought shards still in the balance, never more than the balance
function ShardWallet.paid(data: any): number
	local paid = data.paidShards
	if type(paid) ~= "number" or paid ~= paid or paid < 0 then
		return 0
	end
	return math.min(paid, math.max(data.shards or 0, 0))
end

function ShardWallet.earned(data: any): number
	return math.max((data.shards or 0) - ShardWallet.paid(data), 0)
end

function ShardWallet.add(data: any, amount: number, bought: boolean?)
	data.shards += amount
	data.paidShards = ShardWallet.paid(data) + (if bought then amount else 0)
	data.paidShards = math.min(data.paidShards, data.shards)
end

-- Shards that can pay for an egg; `restricted` is PolicyService's ArePaidRandomItemsRestricted
function ShardWallet.forEggs(data: any, restricted: boolean): number
	return if restricted then ShardWallet.earned(data) else data.shards or 0
end

-- Takes `amount` (already checked affordable). `random` marks an egg: earned shards go first.
function ShardWallet.spend(data: any, amount: number, random: boolean?)
	local paid = ShardWallet.paid(data)
	data.shards -= amount
	if random then
		data.paidShards = math.min(paid, math.max(data.shards, 0))
	else
		data.paidShards = math.max(paid - amount, 0)
	end
end

return ShardWallet
