--!strict
-- Policy lookups are external and yield; use a deterministic task queue while
-- exercising the real cache, validation, permissions and player lifecycle.

return function(t: any)
	local PlayerPolicies = require(t.lib.PlayerPolicies)
	local player = {}

	local function harness(lookup: (any) -> any)
		local queue: { { seconds: number, run: () -> () } } = {}
		local updates = {}
		local cache = PlayerPolicies.new({
			lookup = lookup,
			defer = function(run)
				table.insert(queue, { seconds = 0, run = run })
			end,
			delay = function(seconds, run)
				table.insert(queue, { seconds = seconds, run = run })
			end,
			changed = function(who, policy)
				table.insert(updates, { player = who, policy = policy })
			end,
		})
		local function nextTask(): () -> ()
			local item = table.remove(queue, 1)
			assert(item, "Expected a scheduled policy lookup")
			return item.run
		end
		return cache, queue, updates, nextTask
	end

	local function assertRestricted(cache)
		t.eq(cache:Get(player).ArePaidRandomItemsRestricted, true)
		t.eq(cache:Get(player).IsPaidItemTradingAllowed, false)
		t.eq(cache:CanUsePaidRandomItems(player), false)
		t.eq(cache:CanTradePaidItems(player), false)
	end

	t.test("unknown and loading players cannot use policy-restricted features", function()
		local calls = 0
		local cache, queue, updates = harness(function(who)
			t.eq(who, player)
			calls += 1
			return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
		end)
		assertRestricted(cache)
		cache:Add(player)
		t.eq(calls, 0, "Adding a player must not run a yielding lookup inline")
		t.eq(#queue, 1)
		t.eq(#updates, 1)
		t.eq(updates[1].player, player)
		t.eq(updates[1].policy.Status, "loading")
		assertRestricted(cache)
	end)

	t.test("valid policy combinations independently control paid random items and trading", function()
		for _, fixture in {
			{ restricted = true, trading = false, randomAllowed = false },
			{ restricted = false, trading = true, randomAllowed = true },
			{ restricted = false, trading = false, randomAllowed = true },
			{ restricted = true, trading = true, randomAllowed = false },
		} do
			local cache, queue, updates, nextTask = harness(function(who)
				t.eq(who, player)
				return {
					ArePaidRandomItemsRestricted = fixture.restricted,
					IsPaidItemTradingAllowed = fixture.trading,
				}
			end)
			cache:Add(player)
			nextTask()()
			t.eq(cache:Get(player).Status, "ready")
			t.eq(cache:CanUsePaidRandomItems(player), fixture.randomAllowed)
			t.eq(cache:CanTradePaidItems(player), fixture.trading)
			t.eq(updates[2].policy.Status, "ready")
			t.eq(#queue, 0)
		end
	end)

	t.test("failed lookups exhaust bounded delayed retries and remain conservative", function()
		local calls = 0
		local cache, queue, updates, nextTask = harness(function()
			calls += 1
			error("Policy API unavailable")
		end)
		cache:Add(player)
		nextTask()()
		t.eq(#queue, 1)
		t.ok(queue[1].seconds > 0, "Retries must yield between attempts")
		assertRestricted(cache)
		nextTask()()
		t.ok(queue[1].seconds > 0)
		nextTask()()
		t.eq(calls, 3)
		t.eq(#queue, 0, "Failed policy lookup must stop retrying")
		t.eq(cache:Get(player).Status, "unavailable")
		t.eq(updates[#updates].policy.Status, "unavailable")
		assertRestricted(cache)
	end)

	t.test("malformed and incomplete responses never permit restricted features", function()
		local responses: { any } = {
			false, "invalid", {},
			{ ArePaidRandomItemsRestricted = false },
			{ IsPaidItemTradingAllowed = true },
			{ ArePaidRandomItemsRestricted = 0, IsPaidItemTradingAllowed = true },
			{ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = "true" },
		}
		-- nil is a separate fixture because array iteration omits nil entries.
		for index = 0, #responses do
			local cache, queue, _, nextTask = harness(function()
				return responses[index]
			end)
			cache:Add(player)
			for _ = 1, 3 do nextTask()() end
			t.eq(#queue, 0)
			t.eq(cache:Get(player).Status, "unavailable")
			assertRestricted(cache)
		end
	end)

	t.test("a transient lookup failure recovers without publishing permissive loading values", function()
		local calls = 0
		local cache, queue, updates, nextTask = harness(function()
			calls += 1
			if calls == 1 then error("temporary outage") end
			return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
		end)
		cache:Add(player)
		nextTask()()
		assertRestricted(cache)
		nextTask()()
		t.eq(calls, 2)
		t.eq(#queue, 0)
		t.eq(#updates, 2)
		t.eq(cache:Get(player).Status, "ready")
		t.eq(cache:CanTradePaidItems(player), true)
	end)

	t.test("cached and replicated summaries discard extra fields and resist external mutation", function()
		local response = {
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = true,
			AllowedExternalLinkReferences = { "Discord" },
			IsEligibleToPurchaseCommerceProduct = true,
		}
		local cache, _, updates, nextTask = harness(function() return response end)
		cache:Add(player)
		nextTask()()
		local snapshot = cache:Get(player)
		local count = 0
		for _ in snapshot do count += 1 end
		t.eq(count, 3, "Only status and supported restriction flags should be exposed")
		t.eq(snapshot.AllowedExternalLinkReferences, nil)
		response.ArePaidRandomItemsRestricted = true
		snapshot.IsPaidItemTradingAllowed = false
		updates[2].policy.ArePaidRandomItemsRestricted = true
		t.eq(cache:CanUsePaidRandomItems(player), true)
		t.eq(cache:CanTradePaidItems(player), true)
		cache:Remove(player)
		assertRestricted(cache)
	end)

	t.test("duplicate player registration does not issue duplicate lookups", function()
		local calls = 0
		local cache, queue, updates, nextTask = harness(function()
			calls += 1
			return { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
		end)
		cache:Add(player)
		cache:Add(player)
		nextTask()()
		cache:Add(player)
		t.eq(calls, 1)
		t.eq(#queue, 0)
		t.eq(#updates, 2)
	end)

	t.test("different players keep independent eligibility and removal", function()
		local otherPlayer = {}
		local cache, _, updates, nextTask = harness(function(who)
			if who == player then
				return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
			end
			t.eq(who, otherPlayer)
			return { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
		end)
		cache:Add(player)
		cache:Add(otherPlayer)
		nextTask()()
		nextTask()()
		t.eq(cache:CanUsePaidRandomItems(player), true)
		t.eq(cache:CanTradePaidItems(player), true)
		t.eq(cache:CanUsePaidRandomItems(otherPlayer), false)
		t.eq(cache:CanTradePaidItems(otherPlayer), false)
		t.eq(updates[3].player, player)
		t.eq(updates[4].player, otherPlayer)
		cache:Remove(player)
		assertRestricted(cache)
		t.eq(cache:Get(otherPlayer).Status, "ready")
		t.eq(cache:Get(otherPlayer).ArePaidRandomItemsRestricted, true)
		t.eq(cache:Get(otherPlayer).IsPaidItemTradingAllowed, false)
	end)

	t.test("leaving before the deferred lookup prevents the API call", function()
		local calls = 0
		local cache, queue, updates, nextTask = harness(function()
			calls += 1
			return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
		end)
		cache:Add(player)
		cache:Remove(player)
		nextTask()()
		t.eq(calls, 0)
		t.eq(#queue, 0)
		t.eq(#updates, 1)
		assertRestricted(cache)
	end)

	t.test("leaving during a yielded lookup discards the completed response", function()
		local cache, queue, updates, nextTask = harness(function()
			coroutine.yield()
			return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
		end)
		cache:Add(player)
		local thread = coroutine.create(nextTask())
		t.ok(coroutine.resume(thread))
		cache:Remove(player)
		t.ok(coroutine.resume(thread))
		t.eq(coroutine.status(thread), "dead")
		t.eq(#updates, 1)
		t.eq(#queue, 0)
		assertRestricted(cache)
	end)

	t.test("leaving during retry delay prevents all further lookup attempts", function()
		local calls = 0
		local cache, queue, updates, nextTask = harness(function()
			calls += 1
			error("outage")
		end)
		cache:Add(player)
		nextTask()()
		cache:Remove(player)
		nextTask()()
		t.eq(calls, 1)
		t.eq(#queue, 0)
		t.eq(#updates, 1)
		assertRestricted(cache)
	end)

	t.test("a stale in-flight lookup cannot overwrite a new registration", function()
		local calls = 0
		local cache, _, updates, nextTask = harness(function()
			calls += 1
			if calls == 1 then
				coroutine.yield()
				return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
			end
			return { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
		end)
		cache:Add(player)
		local stale = coroutine.create(nextTask())
		t.ok(coroutine.resume(stale))
		cache:Remove(player)
		cache:Add(player)
		nextTask()()
		t.ok(coroutine.resume(stale))
		t.eq(cache:Get(player).Status, "ready")
		assertRestricted(cache)
		t.eq(#updates, 3)
	end)
end
