--!strict
-- Game passes and developer products (spec §9). Config.Monetization lists them; a
-- pass or product with Id = 0 is not on sale: it is never looked up or prompted.
--
-- Passes: ownership is resolved on join (UserOwnsGamePassAsync, pcall'd) and when a
-- purchase finishes in game (PromptGamePassPurchaseFinished). In Studio a
-- ServerStorage string attribute DevPasses ("TwoXOre,VIP") grants passes for
-- testing. Other services read the effects from here:
--   2x Ore          NodeService doubles the ore quantity per hit (OreMult). Mineral
--                   odds are never touched: IndexService rolls on its own (§9.4)
--   Bigger Backpack PlayerStateService doubles backpack capacity (BackpackMult)
--   Offline Hours+  RefineryService caps offline catch-up at Home.OfflineCapPass
--   Auto-Deposit    PlayerStateService puts mined ore straight into the hopper,
--                   overflowing into the backpack (HasAutoDeposit)
--   VIP             EconomyService adds VIPBarBonus to bar sales (VIPMult); the
--                   player's VIP attribute lets clients add a chat tag
--
-- Products (ProcessReceipt): processed PurchaseIds are kept in the profile (the last
-- Config.Monetization.ReceiptHistory) so a receipt is only granted once, and the
-- profile is saved before Roblox hears PurchaseGranted. No profile yet, or a failed
-- save, returns NotProcessedYet and Roblox retries.
--   Call a Meteor   re-checks MeteorService:CanCallMeteor. If the meteor can no
--                   longer be called, the buyer gets a grant of equal value instead
--                   (spec §9.2): a Call a Meteor credit (credits.callMeteor), usable
--                   from the store once calling is available again
--   Overclock       adds Overclock.Duration seconds of ×SpeedMult refinery speed,
--                   counted down by RefineryService's online tick only
--
-- Call a Meteor availability is published to every client (the CallMeteor property)
-- so the store can disable the button with the reason, and nobody pays for nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Monetization = Config.Monetization

local MonetizationService = Knit.CreateService({
	Name = "MonetizationService",
	Client = {
		Owned = Knit.CreateProperty(nil), -- per player: { [passKey]: true }
		CallMeteor = Knit.CreateProperty({ available = false, reason = "" }), -- { available, reason }
		Notice = Knit.CreateSignal(), -- (text)
	},
})

MonetizationService.PassBought = Signal.new() -- (player, passKey) after an in-game pass purchase
-- (player, productKey, outcome) after a product receipt is granted; outcome is
-- "called" or "credited" for Call a Meteor, "granted" for the others
MonetizationService.ProductBought = Signal.new()

local DataService
local PlayerStateService
local MeteorService

local owned: { [Player]: { [string]: boolean } } = {}
local resolved: { [Player]: boolean } = {}
local passById: { [number]: string } = {}
local productById: { [number]: string } = {}

-- Passes granted by the Studio-only DevPasses attribute, e.g. "TwoXOre,VIP".
local function devPasses(): { string }
	local list = {}
	local value = ServerStorage:GetAttribute("DevPasses")
	if not RunService:IsStudio() or typeof(value) ~= "string" then
		return list
	end
	for key in string.gmatch(value, "[^,%s]+") do
		if Monetization.Passes[key] then
			table.insert(list, key)
		end
	end
	return list
end

function MonetizationService:HasPass(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

-- Waits (up to `timeout` seconds) until the player's pass ownership has been looked
-- up, e.g. before offline catch-up reads the Offline Hours+ cap.
function MonetizationService:WaitForPasses(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	while player.Parent and not resolved[player] and os.clock() < deadline do
		task.wait(0.1)
	end
end

function MonetizationService:OreMult(player: Player): number
	return if self:HasPass(player, "TwoXOre") then Monetization.OreMult else 1
end

function MonetizationService:BackpackMult(player: Player): number
	return if self:HasPass(player, "BiggerBackpack") then Monetization.BackpackMult else 1
end

function MonetizationService:OfflineCap(player: Player): number
	return if self:HasPass(player, "OfflineHours") then Config.Home.OfflineCapPass else Config.Home.OfflineCap
end

function MonetizationService:HasAutoDeposit(player: Player): boolean
	return self:HasPass(player, "AutoDeposit")
end

function MonetizationService:VIPMult(player: Player): number
	return if self:HasPass(player, "VIP") then 1 + Monetization.VIPBarBonus else 1
end

-- Refinery speed multiplier while Overclock time is left (online only).
function MonetizationService:RefinerySpeedMult(data: any): number
	return if data and (data.overclockLeft or 0) > 0 then Monetization.Overclock.SpeedMult else 1
end

-- Publishes the player's passes and refreshes what depends on them.
function MonetizationService:_apply(player: Player)
	local set = owned[player]
	if not set or not player.Parent then
		return
	end
	self.Client.Owned:SetFor(player, table.clone(set))
	player:SetAttribute("VIP", if set.VIP then true else nil)
	PlayerStateService:ReplicateNow(player) -- backpack capacity
end

function MonetizationService:_grantPasses(player: Player, keys: { string })
	local set = owned[player]
	if not set then
		set = {}
		owned[player] = set
	end
	for _, key in keys do
		set[key] = true
	end
	self:_apply(player)
end

function MonetizationService:_resolve(player: Player)
	local found = devPasses()
	for _, key in Monetization.PassOrder do
		local pass = Monetization.Passes[key]
		if pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				table.insert(found, key)
			elseif not ok then
				warn("[MonetizationService] UserOwnsGamePassAsync failed for", player.Name, key, has)
			end
		end
	end
	if not player.Parent then
		return
	end
	self:_grantPasses(player, found)
	resolved[player] = true
end

function MonetizationService:_grantProduct(player: Player, data: any, key: string)
	local outcome = "granted"
	if key == "CallMeteor" then
		local ok, reason = MeteorService:CallMeteor(player)
		if ok then
			outcome = "called"
		else
			outcome = "credited"
			data.credits.callMeteor = (data.credits.callMeteor or 0) + 1
			self.Client.Notice:Fire(
				player,
				(reason or "The meteor can't be called right now.")
					.. " You got a Call a Meteor credit instead: use it from the STORE later."
			)
		end
	elseif key == "Overclock" then
		data.overclockLeft = (data.overclockLeft or 0) + Monetization.Overclock.Duration
		self.Client.Notice:Fire(
			player,
			"Refinery Overclock! ×"
				.. Format.number(Monetization.Overclock.SpeedMult)
				.. " refinery speed for "
				.. Format.number(math.ceil(data.overclockLeft / 60))
				.. " min."
		)
	end
	PlayerStateService:ReplicateNow(player)
	self.ProductBought:Fire(player, key, outcome)
end

function MonetizationService:_processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = if player then PlayerStateService:Get(player) else nil
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productById[receipt.ProductId]
	if not key then
		warn("[MonetizationService] receipt for an unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receipt.PurchaseId)
	if not table.find(data.receipts, purchaseId) then
		self:_grantProduct(player, data, key)
		table.insert(data.receipts, purchaseId)
		while #data.receipts > Monetization.ReceiptHistory do
			table.remove(data.receipts, 1)
		end
	end
	-- Already granted receipts land here too: they are only confirmed once saved
	if DataService:Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Spends one Call a Meteor credit, if calling is available now.
function MonetizationService:UseCallMeteorCredit(player: Player): (boolean, string?)
	local data = PlayerStateService:Get(player)
	if not data or (data.credits.callMeteor or 0) <= 0 then
		return false, "You have no Call a Meteor credits."
	end
	local ok, reason = MeteorService:CallMeteor(player)
	if ok then
		data.credits.callMeteor -= 1
		PlayerStateService:ReplicateNow(player)
	end
	return ok, reason
end

function MonetizationService.Client:UseCallMeteorCredit(player: Player): (boolean, string?)
	return self.Server:UseCallMeteorCredit(player)
end

function MonetizationService:_publishAvailability()
	local ok, reason = MeteorService:CanCallMeteor()
	local current = self.Client.CallMeteor:Get()
	local text = reason or ""
	if not current or current.available ~= ok or current.reason ~= text then
		self.Client.CallMeteor:Set({ available = ok, reason = text })
	end
end

function MonetizationService:KnitInit()
	DataService = Knit.GetService("DataService")
	PlayerStateService = Knit.GetService("PlayerStateService")
	MeteorService = Knit.GetService("MeteorService")
	for key, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			passById[pass.Id] = key
		end
	end
	for key, product in Monetization.Products do
		if product.Id ~= 0 then
			productById[product.Id] = key
		end
	end
end

function MonetizationService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_resolve(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._resolve, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		resolved[player] = nil
	end)
	-- The profile may load after the passes resolved; send State with the right capacity
	DataService.ProfileLoaded:Connect(function(player)
		self:_apply(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key and not self:HasPass(player, key) then
			self:_grantPasses(player, { key })
			self.PassBought:Fire(player, key)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local ok, decision = pcall(self._processReceipt, self, receipt)
		if ok then
			return decision
		end
		warn("[MonetizationService] ProcessReceipt failed:", decision)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if RunService:IsStudio() then
		ServerStorage:GetAttributeChangedSignal("DevPasses"):Connect(function()
			for _, player in Players:GetPlayers() do
				self:_grantPasses(player, devPasses())
			end
		end)
	end

	task.spawn(function()
		while true do
			self:_publishAvailability()
			task.wait(Monetization.AvailabilityInterval)
		end
	end)
end

return MonetizationService
