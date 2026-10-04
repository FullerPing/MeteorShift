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
end
