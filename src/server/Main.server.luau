--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)

Knit.AddServices(script.Parent.Services)

Knit.Start()
	:andThen(function()
		print("[MeteorShift] server started")
		if RunService:IsStudio() then
			local PlayerStateService = Knit.GetService("PlayerStateService")

			-- Studio only: a hook the command bar can call to hand out cash, ore and shards for
			-- testing. The optional pickaxeTier sets the player's pickaxe tier (clamped to
			-- Config.Pickaxes) and restyles the tool, e.g. tier 5 to mine Crystal meteors.
			local hook = Instance.new("BindableFunction")
			hook.Name = "DevGrant"
			hook.OnInvoke = function(player: Player, cash: number?, ore: number?, shards: number?, pickaxeTier: number?)
				if cash then
					PlayerStateService:AddCash(player, cash)
				end
				if ore then
					PlayerStateService:AddOre(player, "iron", ore)
				end
				if shards then
					PlayerStateService:AddShards(player, shards)
				end
				local data = PlayerStateService:Get(player)
				if pickaxeTier and data then
					data.pickaxeTier = math.clamp(math.floor(pickaxeTier), 1, #Config.Pickaxes)
					data.pickaxeStats = Gear.freshPickaxeStats(data.pickaxeTier)
					Knit.GetService("ShopService"):ApplyPickaxe(player)
				end
				PlayerStateService:ReplicateNow(player)
				return PlayerStateService:Get(player)
			end
			hook.Parent = ServerStorage

			-- Studio only: adds one mineral to the player's mineral index (spec §8.2) through
			-- the real award path (toast, page announcement, title), since the rarest ones
			-- need rich nodes and long odds. A page id ("Iron") adds one of every mineral on
			-- that page. Returns the player's index.
			-- game.ServerStorage.DevMineral:Invoke(game.Players:GetPlayers()[1], "Iron")
			local mineralHook = Instance.new("BindableFunction")
			mineralHook.Name = "DevMineral"
			mineralHook.OnInvoke = function(player: Player, id: string)
				local IndexService = Knit.GetService("IndexService")
				local page = Config.Index.Pages[id]
				if page then
					for _, mineral in page.Minerals do
						IndexService:Award(player, mineral.Id)
					end
				else
					IndexService:Award(player, id)
				end
				local data = PlayerStateService:Get(player)
				return if data then data.index else nil
			end
			mineralHook.Parent = ServerStorage

			-- Studio only: measures the ore hot path (spec §12.3). Calls AddOre `swings`
			-- times, waits for the next State flush, and reports the elapsed ms of the
			-- calls and how many State snapshots went out. The player borrows the
			-- biggest empty backpack meanwhile so every call really adds ore, and gets
			-- their own back afterwards.
			-- game.ServerStorage.DevBench:Invoke(game.Players:GetPlayers()[1], 1000)
			local bench = Instance.new("BindableFunction")
			bench.Name = "DevBench"
			bench.OnInvoke = function(player: Player, swings: number)
				if typeof(swings) ~= "number" or swings < 1 then
					return nil
				end
				local data = PlayerStateService:Get(player)
				if not data then
					return nil
				end
				local ownTier, ownStats, ownBackpack = data.backpackTier, data.backpackStats, table.clone(data.backpack)
				data.backpackTier = #Config.Backpacks
				data.backpackStats = { capacity = Gear.cap(#Config.Backpacks) }
				table.clear(data.backpack)

				local result
				local ok, err = pcall(function()
					local sendsBefore = PlayerStateService:StateSendCount()
					local start = os.clock()
					for _ = 1, swings do
						PlayerStateService:AddOre(player, "iron", 1)
					end
					local elapsedMs = (os.clock() - start) * 1000
					task.wait(Config.Net.StateFlushInterval * 2)
					local sends = PlayerStateService:StateSendCount() - sendsBefore
					result = { swings = swings, elapsedMs = elapsedMs, sends = sends }
				end)
				if not ok then
					warn("[DevBench] failed:", err)
				end

				-- always give the player their own backpack back
				data.backpackTier = ownTier
				data.backpackStats = ownStats
				table.clear(data.backpack)
				for oreType, n in ownBackpack do
					data.backpack[oreType] = n
				end
				PlayerStateService:ReplicateNow(player)
				return result
			end
			bench.Parent = ServerStorage

			-- Studio only: brings down a meteor of the given type (Iron, Ice or Crystal) soon,
			-- ending the one that is down if there is one (MeteorService:DevSpawn).
			-- game.ServerStorage.DevMeteor:Invoke("Crystal")
			local MeteorService = Knit.GetService("MeteorService")
			local meteorHook = Instance.new("BindableFunction")
			meteorHook.Name = "DevMeteor"
			meteorHook.OnInvoke = function(typeId: string): string
				return MeteorService:DevSpawn(typeId)
			end
			meteorHook.Parent = ServerStorage

			-- Studio only: sets the player's pickaxe and/or backpack to a tier (1 to 8, see
			-- Config.Pickaxes and Config.Backpacks; nil leaves it as is) and restyles the
			-- pickaxe. Returns what the player now has.
			-- game.ServerStorage.DevGear:Invoke(game.Players:GetPlayers()[1], 5, 8)
			-- (stat levels start at the first level of the tier, as after evolving)
			local ShopService = Knit.GetService("ShopService")
			local function setGear(player: Player, pickaxeTier: number?, backpackTier: number?): string
				local data = PlayerStateService:Get(player)
				if not data then
					return "No profile loaded yet"
				end
				if pickaxeTier then
					data.pickaxeTier = math.clamp(math.floor(pickaxeTier), 1, #Config.Pickaxes)
					data.pickaxeStats = Gear.freshPickaxeStats(data.pickaxeTier)
					ShopService:ApplyPickaxe(player)
				end
				if backpackTier then
					data.backpackTier = math.clamp(math.floor(backpackTier), 1, #Config.Backpacks)
					data.backpackStats = Gear.freshBackpackStats(data.backpackTier)
				end
				PlayerStateService:ReplicateNow(player)
				return string.format("%s, %s", Config.Pickaxes[data.pickaxeTier].Name, Config.Backpacks[data.backpackTier].Name)
			end
			-- Studio only: gives the player a pet at a level and equips it if a slot is free (ignores
			-- the shard price). Returns the player's pets.
			-- game.ServerStorage.DevPet:Invoke(game.Players:GetPlayers()[1], "packMule", 10)
			local Pets = require(ReplicatedStorage.Shared.Pets)
			local petHook = Instance.new("BindableFunction")
			petHook.Name = "DevPet"
			petHook.OnInvoke = function(player: Player, petId: string, level: number?)
				local data = PlayerStateService:Get(player)
				if not data or not Pets.def(petId) then
					return nil
				end
				data.pets.owned[petId] = { level = math.clamp(math.floor(level or 1), 1, Config.Pets.MaxLevel), xp = 0 }
				if not table.find(data.pets.equipped, petId) and #data.pets.equipped < Pets.slots(data.rebirths, Knit.GetService("MonetizationService"):HasPass(player, "ExtraPetSlot")) then
					table.insert(data.pets.equipped, petId)
				end
				PlayerStateService:ReplicateNow(player)
				return data.pets
			end
			petHook.Parent = ServerStorage

			-- Studio only: sets the player level (clears XP). Returns the level.
			-- game.ServerStorage.DevLevel:Invoke(game.Players:GetPlayers()[1], 7)
			local Levels = require(ReplicatedStorage.Shared.Levels)
			local levelHook = Instance.new("BindableFunction")
			levelHook.Name = "DevLevel"
			levelHook.OnInvoke = function(player: Player, level: number)
				local data = PlayerStateService:Get(player)
				if not data then
					return nil
				end
				local progress = Levels.clean(level, 0)
				data.level, data.xp = progress.level, progress.xp
				PlayerStateService:ReplicateNow(player)
				return data.level
			end
			levelHook.Parent = ServerStorage

			local gearHook = Instance.new("BindableFunction")
			gearHook.Name = "DevGear"
			gearHook.OnInvoke = setGear
			gearHook.Parent = ServerStorage

			-- Studio only: the same as chat commands, so they work in Play without switching
			-- the command bar to the server. The reply shows as a notice on the HUD.
			--   /meteor <Iron|Ice|Crystal>   /pickaxe <1-8>   /backpack <1-8>
			local TextChatService = game:GetService("TextChatService")
			local function chatCommand(alias: string, run: (Player, string?) -> string)
				local command = Instance.new("TextChatCommand")
				command.Name = "Dev" .. string.sub(alias, 2)
				command.PrimaryAlias = alias
				command.Triggered:Connect(function(source: TextSource, text: string)
					local player = Players:GetPlayerByUserId(source.UserId)
					if player then
						local reply = run(player, string.match(text, "^%S+%s+(%S+)"))
						print("[Dev] " .. text .. ": " .. reply)
						ShopService.Client.Notice:Fire(player, reply)
					end
				end)
				command.Parent = TextChatService
			end
			chatCommand("/meteor", function(_player, typeId)
				return MeteorService:DevSpawn(typeId or "")
			end)
			chatCommand("/pickaxe", function(player, tier)
				local number = tonumber(tier)
				return if number then setGear(player, number, nil) else "Usage: /pickaxe 1-" .. #Config.Pickaxes
			end)
			chatCommand("/backpack", function(player, tier)
				local number = tonumber(tier)
				return if number then setGear(player, nil, number) else "Usage: /backpack 1-" .. #Config.Backpacks
			end)
		end
	end)
	:catch(warn)
