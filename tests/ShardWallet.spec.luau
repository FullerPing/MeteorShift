--!strict
return function(t)
	local Wallet = require(t.shared.ShardWallet) :: any

	t.test("bought shards are tracked apart from earned ones", function()
		local data = { shards = 0, paidShards = 0 }
		Wallet.add(data, 30)
		Wallet.add(data, 250, true)
		t.eq(data.shards, 280)
		t.eq(Wallet.paid(data), 250)
		t.eq(Wallet.earned(data), 30)
	end)

	t.test("restricted players can only open eggs with earned shards", function()
		local data = { shards = 280, paidShards = 250 }
		t.eq(Wallet.forEggs(data, true), 30)
		t.eq(Wallet.forEggs(data, false), 280)
	end)

	t.test("an egg spends earned shards first", function()
		local data = { shards = 280, paidShards = 250 }
		Wallet.spend(data, 30, true)
		t.eq(data.shards, 250)
		t.eq(Wallet.paid(data), 250, "the bought part is untouched")
		Wallet.spend(data, 100, true)
		t.eq(Wallet.paid(data), 150, "past the earned part, bought shards pay")
	end)

	t.test("fixed purchases spend bought shards first", function()
		local data = { shards = 280, paidShards = 250 }
		Wallet.spend(data, 200)
		t.eq(data.shards, 80)
		t.eq(Wallet.paid(data), 50)
		t.eq(Wallet.earned(data), 30, "earned shards are kept for eggs")
	end)

	t.test("bad or missing paid counts read as nothing bought", function()
		t.eq(Wallet.paid({ shards = 10 }), 0)
		t.eq(Wallet.paid({ shards = 10, paidShards = 0 / 0 }), 0)
		t.eq(Wallet.paid({ shards = 10, paidShards = 99 }), 10, "never more than the balance")
	end)
end
