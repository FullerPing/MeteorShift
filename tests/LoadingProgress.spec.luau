--!strict
return function(t: any)
	t.test("loading progress module is available before startup", function()
		t.ok(t.shared:FindFirstChild("LoadingProgress"), "LoadingProgress module missing")
	end)
	local module = t.shared:FindFirstChild("LoadingProgress")
	if not module then return end
	local Progress = require(module)
	t.test("completed weighted stages reach exactly one", function()
		local config = require(t.shared.Config.Loading)
		local sum = 0
		for _, weight in config.Weights do sum += weight end
		t.near(sum, 1, 1e-8)
		local p = Progress.new(config.Weights)
		p:setStage("engine", 1)
		t.near(p:total(), config.Weights.engine, 1e-8)
		p:setStage("assets", .5)
		t.near(p:total(), config.Weights.engine + config.Weights.assets * .5, 1e-8)
		p:setStage("assets", 1)
		p:setStage("world", 1)
		p:setStage("state", 1)
		p:setStage("hud", 1)
		t.eq(p:total(), 1)
	end)
	t.test("decimal roundoff cannot keep completed stages below ready", function()
		local weights = {}
		for index = 1, 10 do weights[tostring(index)] = .1 end
		local p = Progress.new(weights)
		for name in weights do p:setStage(name, 1) end
		t.eq(p:total(), 1)
		t.ok(Progress.shouldFinish(3, p:total(), 2.5, 25))
	end)
	t.test("stage updates clamp and never lower the high water mark", function()
		local p = Progress.new({ a = .5, b = .5 })
		p:setStage("a", -2)
		t.eq(p:total(), 0)
		p:setStage("a", 2)
		t.eq(p:total(), .5)
		p:setStage("a", 0)
		t.eq(p:total(), .5)
		p:setStage("b", 1)
		t.eq(p:total(), .5)
		p:setStage("a", 1)
		t.eq(p:total(), 1)
	end)
	t.test("ease converges without reversing or overshooting", function()
		local display = 0
		for _ = 1, 200 do
			local nextValue = Progress.ease(display, .8, 1 / 60)
			t.ok(nextValue >= display and nextValue <= .8)
			display = nextValue
		end
		t.eq(display, .8)
		t.eq(Progress.ease(.8, .4, 1), .8)
		t.eq(Progress.ease(.2, .8, 0), .2)
		t.eq(Progress.ease(.2, .8, -1), .2)
		t.eq(Progress.ease(.2, .8, 100), .8)
	end)
	t.test("status changes at the documented stage boundaries", function()
		for _, pair in {
			{ 0, "Waking up the crater..." }, { 14.9, "Waking up the crater..." },
			{ 15, "Polishing the pickaxes..." }, { 54.9, "Polishing the pickaxes..." },
			{ 55, "Counting your ore..." }, { 84.9, "Counting your ore..." },
			{ 85, "Firing up the foundry..." }, { 99.9, "Firing up the foundry..." },
			{ 100, "Ready!" },
		} do t.eq(Progress.status(pair[1]), pair[2]) end
	end)
	t.test("seeded tips cover every index without consecutive repeats", function()
		local seed, previous, seen = 73, nil, {}
		for _ = 1, 200 do
			local index, nextSeed = Progress.nextTip(14, previous, seed)
			local replay, replaySeed = Progress.nextTip(14, previous, seed)
			t.eq(index, replay)
			t.eq(nextSeed, replaySeed)
			t.ok(index >= 1 and index <= 14 and index ~= previous)
			seen[index] = true
			previous, seed = index, nextSeed
		end
		for index = 1, 14 do t.ok(seen[index], "tip never visited") end
		t.eq(Progress.nextTip(1, 1, 5), 1)
		t.eq(Progress.nextTip(0, nil, 5), 0)
	end)
	t.test("finish waits for minimum visibility but stalls hit deadline", function()
		t.eq(Progress.shouldFinish(0, 1, 2.5, 25), false)
		t.eq(Progress.shouldFinish(2.49, 1, 2.5, 25), false)
		t.eq(Progress.shouldFinish(2.5, 1, 2.5, 25), true)
		t.eq(Progress.shouldFinish(24.99, .99, 2.5, 25), false)
		t.eq(Progress.shouldFinish(25, 0, 2.5, 25), true)
		t.eq(Progress.shouldFinish(26, .5, 2.5, 25), true)
	end)
end
