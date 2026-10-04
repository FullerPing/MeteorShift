-- Executes the production controller and UI helpers through a lightweight
-- Fusion/Roblox boundary adapter. This checks properties and callbacks, not pixels.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local passed, failed = 0, 0
local function check(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL: " .. name .. ": " .. tostring(err)) end
end
local function eq(actual, expected)
	assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback); return { Disconnect = function() end } end,
		fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local function read(value)
	if type(value) == "table" and value.__state then
		return if value.compute then value.compute(read) else value.value
	end
	return value
end
local function flatten(children, result)
	result = result or {}
	if type(children) == "table" then
		if children.ClassName then table.insert(result, children)
		else for _, child in children do flatten(child, result) end end
	end
	return result
end
local function value(initial)
	local state = { __state = true, value = initial, watchers = {} }
	function state:set(nextValue)
		self.value = nextValue
		for _, callback in self.watchers do callback() end
	end
	return state
end
local function scenario(width, height, live)
	local nodes, tasks, prompts, queries, warnings, notices = {}, {}, {}, {}, {}, {}
	local attributes, attributeSignals = {}, {}
	local player = { UserId = 1 }
	function player:GetAttribute(name) return attributes[name] end
	function player:SetAttribute(name, nextValue)
		attributes[name] = nextValue
		if attributeSignals[name] then attributeSignals[name]:fire() end
	end
	function player:GetAttributeChangedSignal(name)
		attributeSignals[name] = attributeSignals[name] or signal()
		return attributeSignals[name]
	end
	function player:WaitForChild(name) return { Name = name } end
	local owned, availability, playerState = {}, { available = true, reason = "" }, { credits = { callMeteor = 0 } }
	local ownedObserve, callObserve, playerObserve
	local monetization = {
		Owned = { Observe = function(_, callback) ownedObserve = callback; callback(owned) end },
		CallMeteor = { Observe = function(_, callback) callObserve = callback; callback(availability) end },
		Notice = signal(),
		creditCalls = 0,
	}
	function monetization:UseCallMeteorCredit() self.creditCalls += 1; return false, "Credit race guarded" end
	local playerService = { State = { Observe = function(_, callback) playerObserve = callback; callback(playerState) end } }
	local infoById = {}
	local marketplace = {}
	function marketplace:GetProductInfoAsync(id, kind)
		table.insert(queries, { id = id, kind = kind })
		local response = infoById[id]
		if response == "fail" then error("Lookup failed") end
		return response
	end
	function marketplace:PromptGamePassPurchase(_, id) table.insert(prompts, { kind = "pass", id = id }) end
	function marketplace:PromptProductPurchase(_, id) table.insert(prompts, { kind = "product", id = id }) end
	local input = { InputBegan = signal() }
	local services = {
		MarketplaceService = marketplace,
		Players = { LocalPlayer = player },
		ReplicatedStorage = { Packages = { Knit = "Knit", Fusion = "Fusion" }, Shared = { Config = "Config", Format = "Format", HudLayout = "HudLayout" } },
		TextChatService = { ChatVersion = "legacy" },
		UserInputService = input,
		GuiService = {},
	}
	services.ReplicatedStorage.Shared.Config = { HudIcons = "HudIcons" }
	local game = { GetService = function(_, name) return assert(services[name], name) end }
	local fusion = { Children = "Children", OnEvent = function(name) return "event:" .. name end, peek = read }
	local scope = {}
	function scope:Value(initial) return value(initial) end
	function scope:Computed(callback) return { __state = true, compute = callback } end
	function scope:Observer(state)
		return {
			onChange = function(_, callback) table.insert(state.watchers, callback) end,
			onBind = function(_, callback) table.insert(state.watchers, callback); callback() end,
		}
	end
	function scope:New(className)
		return function(props)
			local node = { ClassName = className, props = props, children = flatten(props.Children), Activated = signal() }
			function node:activate()
				if props["event:Activated"] then props["event:Activated"]() end
				self.Activated:fire()
			end
			table.insert(nodes, node)
			return node
		end
	end
	fusion.scoped = function() return scope end
	local knit = {
		CreateController = function(controller) return controller end,
		GetService = function(name) return if name == "MonetizationService" then monetization else playerService end,
		GetController = function() return { Toast = function(_, message) table.insert(notices, message) end } end,
	}
	local modules = { Knit = knit, Fusion = fusion, Sfx = { play = function() end }, HudLayout = {} }
	local globals = { game = game, Enum = roblox.Enum, Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Vector2 = roblox.Vector2, UDim = roblox.UDim,
		UDim2 = roblox.UDim2, task = { spawn = function(callback) table.insert(tasks, callback) end },
		warn = function(...) table.insert(warnings, { ... }) end }
	local function load(path, script)
		local environment = table.clone(globals)
		environment.script = script
		environment.require = function(name) return assert(modules[name], "Unknown module: " .. tostring(name)) end
		return luau.load(fs.readFile(path), { debugName = path, environment = environment, injectGlobals = true })()
	end
	modules.HudIcons = load("src/shared/Config/HudIcons.luau")
	modules.Monetization = load("src/shared/Config/Monetization.luau")
	modules.Config = { Monetization = modules.Monetization, HudIcons = modules.HudIcons }
	-- require(Config) and require(Config.HudIcons) refer to distinct module tokens.
	modules[services.ReplicatedStorage.Shared.Config] = modules.Config
	modules.Format = load("src/shared/Format.luau")
	if live then
		local id = 1000
		for _, entries in { modules.Monetization.Passes, modules.Monetization.Products } do
			for _, entry in entries do
				id += 1; entry.Id = id
				infoById[id] = { PriceInRobux = 199, IsForSale = true, IconImageAssetId = 5000 + id }
			end
		end
	end
	modules.UI = load("src/client/UI.luau", { Parent = { Sfx = "Sfx" } })
	local hud = value({ viewport = roblox.Vector2.new(width, height), inset = 36,
		buttons = { STORE = { x = 12, y = 100 } }, buttonBase = roblox.Vector2.new(90, 80), buttonScale = 1,
		buttonTextSize = 16, touch = false })
	modules.UI.hud = function() return hud end
	local controller = load("src/client/Controllers/StoreController.luau", { Parent = { Parent = { UI = "UI" } } })
	controller:KnitStart()
	local function find(name, list)
		for _, node in list or nodes do if node.props.Name == name then return node end end
		error("Missing node: " .. name)
	end
	local function child(node, name) return find(name, node.children) end
	local function flush()
		while #tasks > 0 do table.remove(tasks, 1)() end
	end
	local function card(key) return find(key) end
	return {
		find = find, child = child, card = card, read = read, flush = flush,
		prompts = prompts, queries = queries, warnings = warnings, notices = notices, infoById = infoById,
		setOwned = function(nextValue) ownedObserve(nextValue) end,
		setCall = function(nextValue) callObserve(nextValue) end,
		setPlayer = function(nextValue) playerObserve(nextValue) end,
		monetization = monetization, config = modules.Monetization, attributes = attributes, input = input,
	}
end

for _, dimensions in { { 1280, 720 }, { 1920, 1080 }, { 844, 390 }, { 390, 844 }, { 320, 568 } } do
	local name = dimensions[1] .. "x" .. dimensions[2]
	check("geometry " .. name, function()
		local s = scenario(dimensions[1], dimensions[2], false)
		local panel, list = s.find("Panel"), s.find("List")
		local panelSize = read(panel.props.Size)
		assert(panelSize.X.Offset <= dimensions[1] - 24)
		assert(panelSize.Y.Offset <= dimensions[2] - 36 - 24)
		local grid
		for _, node in list.children do if node.ClassName == "UIGridLayout" then grid = node end end
		assert(grid, "Grid missing")
		eq(grid.props.FillDirectionMaxCells, 3)
		local size, gap = read(grid.props.CellSize), read(grid.props.CellPadding)
		local padding
		for _, node in list.children do if node.ClassName == "UIPadding" then padding = read(node.props.PaddingLeft).Offset end end
		local available = panelSize.X.Offset - 28 - 2 * padding - list.props.ScrollBarThickness
		assert(3 * size.X.Offset + 2 * gap.X.Offset <= available, "Three cards exceed grid width")
		local cards = {}
		for _, node in list.children do if node.ClassName == "Frame" then table.insert(cards, node) end end
		eq(#cards, 7)
		local rowBottom = padding + 3 * size.Y.Offset + 2 * gap.Y.Offset
		assert(read(list.props.CanvasSize).Y.Offset >= rowBottom + padding, "Last row is outside canvas")
		local listHeight = panelSize.Y.Offset - 126
		local maxScroll = read(list.props.CanvasSize).Y.Offset - listHeight
		assert(maxScroll + listHeight >= rowBottom, "Last row is unreachable")
		for _, card in cards do
			local icon, price, title, description, status, buy = s.child(card, "IconWell"), s.child(card, "Price"), s.child(card, "Title"), s.child(card, "Description"), s.child(card, "Status"), s.child(card, "Buy")
			assert(read(price.props.Position).Y.Offset > icon.props.Position.Y.Offset + read(icon.props.Size).Y.Offset, "Price not below icon")
			assert(read(title.props.Position).Y.Offset >= read(price.props.Position).Y.Offset + read(price.props.Size).Y.Offset)
			assert(read(description.props.Position).Y.Offset >= read(title.props.Position).Y.Offset + read(title.props.Size).Y.Offset)
			assert(read(status.props.Position).Y.Offset >= read(description.props.Position).Y.Offset + read(description.props.Size).Y.Offset)
			assert(read(status.props.Position).Y.Offset + read(status.props.Size).Y.Offset <= size.Y.Offset - 12 - read(buy.props.Size).Y.Offset)
			assert(read(description.props.TextSize) >= 12)
			eq(read(buy.props.Size).Y.Offset, 44)
		end
		print(name .. ": panel " .. panelSize.X.Offset .. "x" .. panelSize.Y.Offset .. ", 3 columns of " .. size.X.Offset .. "x" .. size.Y.Offset .. ", last row reachable")
	end)
end

check("zero IDs never query or prompt; ownership still wins", function()
	local s = scenario(390, 844, false)
	s.flush(); eq(#s.queries, 0)
	for _, key in { "TwoXOre", "BiggerBackpack", "OfflineHours", "AutoDeposit", "VIP", "CallMeteor", "Overclock" } do
		local button = s.child(s.card(key), "Buy")
		eq(read(button.props.Text), "NOT ON SALE YET"); button:activate()
	end
	eq(#s.prompts, 0)
	s.setOwned({ VIP = true })
	eq(read(s.child(s.card("VIP"), "Buy").props.Text), "OWNED")
	s.child(s.card("VIP"), "Buy"):activate(); eq(#s.prompts, 0)
end)
check("loading price disables purchase; live pass/product use their original prompt", function()
	local s = scenario(1280, 720, true)
	local pass, product = s.child(s.card("TwoXOre"), "Buy"), s.child(s.card("Overclock"), "Buy")
	eq(read(pass.props.Text), "LOADING"); pass:activate(); product:activate(); eq(#s.prompts, 0)
	s.flush(); eq(#s.queries, 7)
	local passIds = {}
	for _, pass in s.config.Passes do passIds[pass.Id] = true end
	for _, query in s.queries do
		eq(query.kind, if passIds[query.id] then roblox.Enum.InfoType.GamePass else roblox.Enum.InfoType.Product)
	end
	eq(read(s.child(s.card("TwoXOre"), "Price").props.Text), "R$ 199")
	pass:activate(); product:activate(); eq(#s.prompts, 2)
	eq(s.prompts[1].kind, "pass"); eq(s.prompts[1].id, s.config.Passes.TwoXOre.Id)
	eq(s.prompts[2].kind, "product"); eq(s.prompts[2].id, s.config.Products.Overclock.Id)
	s.setOwned({ TwoXOre = true }); pass:activate(); eq(#s.prompts, 2)
end)
check("Call Meteor availability, credit guard and notice survive", function()
	local s = scenario(390, 844, false)
	local call = s.card("CallMeteor")
	s.setCall({ available = false, reason = "This server has called enough meteors this hour." })
	s.setPlayer({ credits = { callMeteor = 2 }, overclockLeft = 125 })
	assert(string.find(read(s.child(call, "Status").props.Text), "Credits: 2", 1, true))
	assert(string.find(read(s.child(call, "Status").props.Text), "This server has called enough", 1, true))
	s.child(call, "Buy"):activate(); s.flush(); eq(s.monetization.creditCalls, 0)
	s.setCall({ available = true, reason = "" })
	eq(read(s.child(call, "Buy").props.Text), "USE CREDIT (2)")
	eq(read(s.child(call, "Price").props.Text), "1 CREDIT")
	s.child(call, "Buy"):activate(); s.flush(); eq(s.monetization.creditCalls, 1); eq(#s.prompts, 0)
	eq(s.notices[1], "Credit race guarded")
	eq(read(s.child(s.card("Overclock"), "Status").props.Text), "Active: 3 min left")
end)
check("live Call Meteor remains unavailable during a blocked call, and credits bypass price loading", function()
	local s = scenario(390, 844, true)
	local button = s.child(s.card("CallMeteor"), "Buy")
	s.setCall({ available = false, reason = "A meteor is already here." })
	eq(read(button.props.Text), "UNAVAILABLE")
	button:activate(); eq(#s.prompts, 0)
	s.setPlayer({ credits = { callMeteor = 3 } })
	button:activate(); eq(s.monetization.creditCalls, 0)
	s.setCall({ available = true, reason = "" })
	eq(read(button.props.Text), "USE CREDIT (3)")
	button:activate(); s.flush(); eq(s.monetization.creditCalls, 1); eq(#s.prompts, 0)
	s.monetization.Notice:fire("A store notice")
	eq(s.notices[#s.notices], "A store notice")
end)
check("metadata off-sale, failure and reopen retry", function()
	local s = scenario(390, 844, true)
	local vipId, oreId = s.config.Passes.VIP.Id, s.config.Passes.TwoXOre.Id
	s.infoById[vipId] = { PriceInRobux = 199, IsForSale = false }
	s.infoById[oreId] = "fail"
	s.flush()
	local vip, ore = s.child(s.card("VIP"), "Buy"), s.child(s.card("TwoXOre"), "Buy")
	eq(read(vip.props.Text), "NOT ON SALE YET"); eq(read(ore.props.Text), "UNAVAILABLE")
	vip:activate(); ore:activate(); eq(#s.prompts, 0)
	s.infoById[oreId] = { PriceInRobux = 250, IsForSale = true }
	s.find("StoreButton"):activate(); eq(read(ore.props.Text), "LOADING")
	s.flush(); eq(read(ore.props.Text), "BUY"); eq(read(s.child(s.card("TwoXOre"), "Price").props.Text), "R$ 250")
	eq(#s.queries, 8)
end)
check("close, dimmer, Escape and ButtonB update StoreOpen", function()
	local s = scenario(390, 844, false)
	for _, name in { "Close", "Dimmer" } do
		s.find("StoreButton"):activate(); eq(s.attributes.StoreOpen, true)
		s.find(name):activate(); eq(s.attributes.StoreOpen, false)
	end
	for _, key in { roblox.Enum.KeyCode.Escape, roblox.Enum.KeyCode.ButtonB } do
		s.find("StoreButton"):activate(); s.input.InputBegan:fire({ KeyCode = key }); eq(s.attributes.StoreOpen, false)
	end
end)

-- Conservative typical Fredoka uppercase advance estimates. The engine's
-- TextService is unavailable here, so these are explicit text-fit estimates.
local advance = { I = 0.30, L = 0.52, J = 0.50, M = 0.84, W = 0.92, [" "] = 0.28 }
local function wordWidth(word, size)
	local width = 0
	for character in string.gmatch(word, ".") do width += (advance[character] or 0.65) * size end
	return width
end
local function estimatedLines(text, width, size)
	local lines, used = 1, 0
	for word in string.gmatch(text, "%S+") do
		local wordSize = wordWidth(word, size)
		if wordSize > width then
			if used > 0 then lines += 1; used = 0 end
			local fragments = math.ceil(wordSize / width)
			lines += fragments - 1
			used = wordSize - (fragments - 1) * width
		elseif used > 0 and used + size * 0.28 + wordSize > width then lines += 1; used = wordSize
		else used += (if used > 0 then size * 0.28 else 0) + wordSize end
	end
	return lines
end
check("minimum-phone price placeholders fit estimated two-line height", function()
	local s = scenario(320, 568, true)
	s.infoById[s.config.Passes.TwoXOre.Id] = "fail"
	local price = s.child(s.card("TwoXOre"), "Price")
	local bounds = read(price.props.Size)
	local loading = read(price.props.Text)
	s.flush()
	local unavailable = read(price.props.Text)
	for _, text in { loading, unavailable, "NOT ON SALE", "1 CREDIT", "R$ 999,999" } do
		local lines = estimatedLines(text, bounds.X.Offset, 12)
		print("Estimated Fredoka 12 px in " .. bounds.X.Offset .. "x" .. bounds.Y.Offset .. ": " .. text .. " = " .. lines .. " lines")
		assert(lines * 14 <= bounds.Y.Offset, text .. " needs estimated " .. lines * 14 .. "px height")
	end
end)

print("Store QA: " .. passed .. " passed, " .. failed .. " failed; property/state checks only, text estimates are not engine visual verification")
assert(failed == 0, "Store QA failures")
