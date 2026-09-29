local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

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
				local data = PlayerStateService:Get(player)
				if not data then
					return nil
				end
				local ownTier, ownBackpack = data.backpackTier, table.clone(data.backpack)
				data.backpackTier = #Config.Backpacks
				table.clear(data.backpack)

				local sendsBefore = PlayerStateService:StateSendCount()
				local start = os.clock()
				for _ = 1, swings do
					PlayerStateService:AddOre(player, "iron", 1)
				end
				local elapsedMs = (os.clock() - start) * 1000
				task.wait(Config.Net.StateFlushInterval * 2)
				local sends = PlayerStateService:StateSendCount() - sendsBefore

				data.backpackTier = ownTier
				table.clear(data.backpack)
				for oreType, n in ownBackpack do
					data.backpack[oreType] = n
				end
				PlayerStateService:ReplicateNow(player)
				return { swings = swings, elapsedMs = elapsedMs, sends = sends }
			end
			bench.Parent = ServerStorage
		end
	end)
	:catch(warn)
