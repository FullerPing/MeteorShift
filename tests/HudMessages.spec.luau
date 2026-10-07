--!strict
return function(t: any)
	local Messages = require(t.shared.HudMessages)
	t.test("ordinary notices cannot introduce rich text markup", function()
		t.eq(Messages.toast('A & B <ready> "now"'), 'A &amp; B &lt;ready&gt; &quot;now&quot;')
	end)
	t.test("mineral discovery colors only the mineral name", function()
		t.eq(Messages.toast("New mineral: Crystal!", Color3.fromRGB(221, 161, 255), "Crystal"),
			'New mineral: <font color="#DDA1FF">Crystal</font>!')
	end)
	t.test("mineral names remain escaped inside their colored span", function()
		t.eq(Messages.toast("New mineral: A&B!", Color3.fromRGB(123, 230, 239), "A&B"),
			'New mineral: <font color="#7BE6EF">A&amp;B</font>!')
	end)
	t.test("missing highlight falls back to the complete notice", function()
		t.eq(Messages.toast("Backpack full!", Color3.new(1, 1, 1), "Crystal"), "Backpack full!")
	end)
	t.test("sale notice includes the actual awarded cash in the same line", function()
		t.eq(Messages.sale(26, 12400), 'Sold 26 bars <font color="#8BF0C3">+$12.4k</font>')
		t.eq(Messages.sale(1, 0), 'Sold 1 bar <font color="#8BF0C3">+$0</font>')
	end)
	t.test("meteor reward shows the awarded total and first-place bonus without adding it twice", function()
		t.eq(Messages.meteorReward(25, 10, { 10, 6, 3 }),
			'<font color="#71CDFF">25</font> shards received (<font color="#FFD166">#1</font> <font color="#71CDFF">+10</font>)')
	end)
	t.test("reward podium uses silver and bronze and follows configured bonus values", function()
		t.eq(Messages.meteorReward(19, 6, { 10, 6, 3 }),
			'<font color="#71CDFF">19</font> shards received (<font color="#CCD6E0">#2</font> <font color="#71CDFF">+6</font>)')
		t.eq(Messages.meteorReward(14, 3, { 10, 6, 3 }),
			'<font color="#71CDFF">14</font> shards received (<font color="#D49261">#3</font> <font color="#71CDFF">+3</font>)')
		t.eq(Messages.meteorReward(30, 12, { 20, 12, 4 }),
			'<font color="#71CDFF">30</font> shards received (<font color="#CCD6E0">#2</font> <font color="#71CDFF">+12</font>)')
	end)
	t.test("zero and non-podium rewards have no placement or bonus suffix", function()
		t.eq(Messages.meteorReward(0, 0, { 10, 6, 3 }), '<font color="#71CDFF">0</font> shards received')
		t.eq(Messages.meteorReward(7, 0, { 10, 6, 3 }), '<font color="#71CDFF">7</font> shards received')
		t.eq(Messages.meteorReward(1, 0, { 10, 6, 3 }), '<font color="#71CDFF">1</font> shard received')
	end)
	t.test("personal meteor outcome explains a crack and the ore kept", function()
		t.eq(Messages.meteorOutcome(true, 12), "Core cracked! Kept 12 ore.")
		t.eq(Messages.meteorOutcome(true, 0), "Core cracked! Kept 0 ore.")
		t.eq(Messages.meteorOutcome(true, 1.375), "Core cracked! Kept 1.375 ore.")
	end)
	t.test("a cooled meteor explains the unbroken core and preserves earned ore", function()
		t.eq(Messages.meteorOutcome(false, 18), "Cooled: core unbroken. Kept 18 ore.")
		t.eq(Messages.meteorOutcome(false, 0), "Cooled: core unbroken. Kept 0 ore.")
	end)
	t.test("personal payout shows awarded shards and fractional XP without a podium", function()
		t.eq(Messages.meteorReward(7, 0, { 10, 6, 3 }, 2.375),
			'<font color="#71CDFF">7</font> shards received · <font color="#FFD166">+2.375 XP</font>')
		t.eq(Messages.meteorReward(0, 0, { 10, 6, 3 }, 0.375),
			'<font color="#71CDFF">0</font> shards received · <font color="#FFD166">+0.375 XP</font>')
	end)
	t.test("XP accompanies the actual shard total without adding the podium bonus again", function()
		t.eq(Messages.meteorReward(30, 10, { 10, 6, 3 }, 31.5),
			'<font color="#71CDFF">30</font> shards received · <font color="#FFD166">+31.5 XP</font> (<font color="#FFD166">#1</font> <font color="#71CDFF">+10</font>)')
	end)
	t.test("zero and invalid XP never display a non-finite or negative award", function()
		for _, xp in { 0, -1, math.huge, -math.huge, 0 / 0 } do
			t.eq(Messages.meteorReward(0, 0, { 10, 6, 3 }, xp),
				'<font color="#71CDFF">0</font> shards received · <font color="#FFD166">+0 XP</font>')
		end
	end)
	t.test("personal payout uses XP earned through level-ups rather than the remaining XP bar", function()
		local Levels = require(t.shared.Levels)
		local Pets = require(t.shared.Pets)
		local progress = { level = 1, xp = 29 }
		local hit = Pets.playerXp(Levels.hitXp("iron", "Core"), 0.2)
		local crack = Pets.playerXp(Levels.crackXp("iron"), 0.2)
		Levels.addXp(progress, hit)
		Levels.addXp(progress, crack)
		-- the same 29 + hit + crack XP, spent level by level on the current curve
		local left, level = 29 + hit + crack, 1
		while Levels.xpToNext(level) and left >= (Levels.xpToNext(level) :: number) do
			left -= Levels.xpToNext(level) :: number
			level += 1
		end
		t.eq(progress.level, level)
		t.near(progress.xp, left, 1e-6)
		t.eq(Messages.meteorReward(25, 0, { 10, 6, 3 }, hit + crack),
			'<font color="#71CDFF">25</font> shards received · <font color="#FFD166">+30.6 XP</font>')
	end)
end
