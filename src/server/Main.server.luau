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

			-- Studio only: a hook the command bar can call to hand out cash, ore and shards for testing
			local hook = Instance.new("BindableFunction")
			hook.Name = "DevGrant"
			hook.OnInvoke = function(player: Player, cash: number?, ore: number?, shards: number?)
				if cash then
					PlayerStateService:AddCash(player, cash)
				end
				if ore then
					PlayerStateService:AddOre(player, "iron", ore)
				end
				if shards then
					PlayerStateService:AddShards(player, shards)
				end
				PlayerStateService:ReplicateNow(player)
				return PlayerStateService:Get(player)
			end
			hook.Parent = ServerStorage

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
