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
-- Products (ProcessReceipt): processed PurchaseIds are kept permanently in the
-- profile so a receipt is only granted once. The profile is saved before Roblox
-- hears PurchaseGranted. No profile yet, or a failed
-- save, returns NotProcessedYet and Roblox retries.
--   Call a Meteor   re-checks MeteorService:CanCallMeteor. If the meteor can no
--                   longer be called, the buyer gets a grant of equal value instead
--                   (spec §9.2): a Call a Meteor credit (credits.callMeteor), usable
--                   from the store once calling is available again
--   Overclock       adds Overclock.Duration seconds of ×SpeedMult refinery speed,
--                   counted down by RefineryService's online tick only
--   Micro-purchases fixed cash, equipped-pet XP, online boost time, or session-only
--                   Tip Jar cosmetics (Shared.Purchases); never shards or randomness
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
local Purchases = require(ReplicatedStorage.Shared.Purchases)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Refining = require(script.Parent.Parent.Lib.Refining)

local Monetization = Config.Monetization

local MonetizationService = Knit.CreateService({
	Name = "MonetizationService",
	Client = {
		Owned = Knit.CreateProperty(nil), -- per player: { [passKey]: true }
		CallMeteor = Knit.CreateProperty({ available = false, reason = "" }), -- { available, reason }
		Notice = Knit.CreateSignal(), -- (text)
		Supporter = Knit.CreateSignal(), -- session-only Tip Jar confetti and thank-you toast
	},
})

MonetizationService.PassBought = Signal.new() -- (player, passKey) after an in-game pass purchase
MonetizationService.PassesReady = Signal.new() -- (player) after ownership is available or changes in Studio
-- (player, productKey, outcome) after a product receipt is granted; outcome is
-- "called" or "credited" for Call a Meteor, "granted" for the others
MonetizationService.ProductBought = Signal.new()

local DataService
local PlayerStateService
local MeteorService
local EconomyService
local PetService

local owned: { [Player]: { [string]: boolean } } = {}
local resolved: { [Player]: boolean } = {}
local passById: { [number]: string } = {}
local productById: { [number]: string } = {}
local processing: { [Player]: boolean } = {}
type ProductEffect = { key: string, outcome: string, notice: string? }
local pendingEffects: { [Player]: { [string]: ProductEffect } } = {}
local lastCreditRequest: { [Player]: number } = {}

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

-- By default wait for ownership or departure, so slow lookups cannot discard an
-- extra slot or shorten offline catch-up. Callers may request a bounded timeout.
function MonetizationService:WaitForPasses(player: Player, timeout: number?)
	local deadline = if timeout then os.clock() + math.max(timeout, 0) else math.huge
	while player.Parent and not resolved[player] and os.clock() < deadline do
		task.wait(0.1)
	end
end

function MonetizationService:PassesResolved(player: Player): boolean
	return resolved[player] == true
end

function MonetizationService:OreMult(player: Player): number
	local data = PlayerStateService:Get(player)
	return Purchases.oreMultiplier(self:HasPass(player, "TwoXOre"), if data then data.oreBoostLeft else nil)
end

function MonetizationService:ExtraPetSlots(player: Player): number
	return if self:HasPass(player, "ExtraPetSlot") then 1 else 0
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
	self.PassesReady:Fire(player)
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
	resolved[player] = true
	self:_grantPasses(player, found)
end

function MonetizationService:_grantProduct(player: Player, data: any, key: string): ProductEffect?
	local pack = Monetization.CashPacks[key]
	local cash = if pack then Purchases.cashGrant(
		pack.Minutes,
		Refining.lineRate(data, self:RefinerySpeedMult(data)),
		Purchases.averageBarPrice(data.level or 1),
		EconomyService:SaleMultiplier(player),
		pack.Floor,
		Rebirth.cost(data.rebirths) * pack.CeilingShare
	) else nil
	local grant = Purchases.grant(data, key, cash)
	if not grant then
		return nil
	end
	local effect: ProductEffect = { key = key, outcome = "granted", notice = nil }
	if key == "CallMeteor" then
		local worked, called, reason = pcall(function()
			return MeteorService:CallMeteor(player)
		end)
		if worked and called then
			data.credits.callMeteor -= 1 -- spend the credit the pure grant just added
			effect.outcome = "called"
		else
			if not worked then warn("[MonetizationService] meteor call failed:", called) end
			effect.outcome = "credited"
			local message = (if worked then reason else nil) or "The meteor can't be called right now."
			effect.notice = message .. " You got a Call a Meteor credit instead: use it from the STORE later."
		end
	elseif key == "Overclock" or key == "MiniOverclock" then
		effect.notice = "Refinery Overclock! ×" .. Format.number(Monetization.Overclock.SpeedMult)
			.. " refinery speed for " .. Format.number(math.ceil(data.overclockLeft / 60)) .. " min."
	elseif key == "OreRush" then
		effect.notice = "Ore Rush! ×2 ore per hit for " .. Format.number(math.ceil(data.oreBoostLeft / 60)) .. " min."
	elseif grant.cash > 0 then
		effect.notice = "+$" .. Format.number(grant.cash) .. " from " .. Monetization.Products[key].Name .. "."
	elseif key == "PetTreat" or key == "PetFeast" then
		effect.notice = Format.number(Monetization.PetXp[key]) .. " XP given to each equipped pet!"
	end
	-- The state change is done; a throw in the trailing effects must not make the
	-- receipt retry (and call the meteor again)
	local sideOk, sideErr = pcall(function()
		PlayerStateService:ReplicateNow(player)
		for petId, level in grant.leveled do
			PetService.Client.Leveled:Fire(player, petId, level)
		end
	end)
	if not sideOk then
		warn("[MonetizationService] side effects failed after granting", key, sideErr)
	end
	return effect
end

-- Cosmetic purchase effects happen only once the grant and receipt are saved.
function MonetizationService:_finishProduct(player: Player, effect: ProductEffect)
	local ok, err = pcall(function()
		if effect.key == "TipJar" then
			player:SetAttribute("Supporter", true)
			self.Client.Supporter:Fire(player)
		elseif effect.notice then
			self.Client.Notice:Fire(player, effect.notice)
		end
		self.ProductBought:Fire(player, effect.key, effect.outcome)
	end)
	if not ok then warn("[MonetizationService] saved product effects failed:", err) end
end

function MonetizationService:_processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = if player then PlayerStateService:Get(player) else nil
	if not player or not data or not DataService:GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productById[receipt.ProductId]
	if not key then
		warn("[MonetizationService] receipt for an unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.PurchaseId == nil or processing[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local effects = pendingEffects[player] or {}
	pendingEffects[player] = effects
	processing[player] = true
	local ok, saved = pcall(function()
		return Purchases.receipt(data, purchaseId, function(): boolean
			local effect = self:_grantProduct(player, data, key)
			if not effect then return false end
			effects[purchaseId] = effect
			return true
		end, function(): boolean
			return DataService:Save(player)
		end)
	end)
	processing[player] = nil
	if ok and saved then
		local effect = effects[purchaseId]
		effects[purchaseId] = nil
		if effect then self:_finishProduct(player, effect) end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not ok then warn("[MonetizationService] receipt transaction failed:", saved) end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Studio command-bar testing follows the real grant and save path, without
-- inventing a paid receipt or touching MarketplaceService.
function MonetizationService:DevProduct(player: Player, key: string): (boolean, string?)
	if not RunService:IsStudio() then return false, "DevProduct only works in Studio." end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(key) ~= "string" or not Monetization.Products[key] then
		return false, "Choose a player and a configured product key."
	end
	local data = PlayerStateService:Get(player)
	if not data or not DataService:GetProfile(player) or processing[player] then return false, "The profile is not ready." end
	processing[player] = true
	local ok, effect, saved = pcall(function()
		local grant = self:_grantProduct(player, data, key)
		return grant, if grant then DataService:Save(player) else false
	end)
	processing[player] = nil
	if not ok then return false, tostring(effect) end
	if not effect then return false, "The product could not be granted." end
	if not saved then return false, "The grant is in memory, but its save failed." end
	self:_finishProduct(player, effect)
	return true, nil
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
		-- Save now so a crash can't hand the spent credit back (off-thread: Save yields)
		task.spawn(function()
			DataService:Save(player)
		end)
	end
	return ok, reason
end

function MonetizationService.Client:UseCallMeteorCredit(player: Player): (boolean, string?)
	local now = os.clock()
	if now - (lastCreditRequest[player] or 0) < 0.5 then return false, "Please wait before calling again." end
	lastCreditRequest[player] = now
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
	EconomyService = Knit.GetService("EconomyService")
	PetService = Knit.GetService("PetService")
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
		pendingEffects[player] = nil
		lastCreditRequest[player] = nil
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
		local hook = Instance.new("BindableFunction")
		hook.Name = "DevProduct"
		hook.OnInvoke = function(player: Player, key: string)
			return self:DevProduct(player, key)
		end
		hook.Parent = ServerStorage
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
