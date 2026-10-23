--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)
local AdminGive = require(script.Parent.Lib.AdminGive)
local Admins = require(script.Parent.Lib.Admins)

Knit.AddServices(script.Parent.Services)

Knit.Start()
	:andThen(function()
		print("[MeteorShift] server started")
		local PlayerStateService = Knit.GetService("PlayerStateService")
		local MeteorService = Knit.GetService("MeteorService")
		local ShopService = Knit.GetService("ShopService")

		-- Sets the player's pickaxe and/or backpack to a tier (1 to 8, see
		-- Config.Pickaxes and Config.Backpacks; nil leaves it as is) and restyles the
		-- pickaxe. Returns what the player now has.
		-- game.ServerStorage.DevGear:Invoke(game.Players:GetPlayers()[1], 5, 8)
		-- (the level starts at the first level of the tier, as after evolving)
		local function setGear(player: Player, pickaxeTier: number?, backpackTier: number?): string
			local data = PlayerStateService:Get(player)
			if not data then
				return "No profile loaded yet"
			end
			if pickaxeTier then
				data.pickaxeTier = math.clamp(math.floor(pickaxeTier), 1, #Config.Pickaxes)
				data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)
			end
			if backpackTier then
				data.backpackTier = math.clamp(math.floor(backpackTier), 1, #Config.Backpacks)
				data.backpackLevel = Gear.levelsForTier(data.backpackTier)
			end
			ShopService:ApplyPickaxe(player) -- restyles the pickaxe tool and swaps the backpack on the character
			PlayerStateService:ReplicateNow(player)
			return string.format("%s, %s", Config.Pickaxes[data.pickaxeTier].Name, Config.Backpacks[data.backpackTier].Name)
		end

		if RunService:IsStudio() then
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
					data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)
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
				local ownTier, ownLevel, ownBackpack = data.backpackTier, data.backpackLevel, table.clone(data.backpack)
				data.backpackTier = #Config.Backpacks
				data.backpackLevel = Gear.cap(#Config.Backpacks)
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
				data.backpackLevel = ownLevel
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
			local meteorHook = Instance.new("BindableFunction")
			meteorHook.Name = "DevMeteor"
			meteorHook.OnInvoke = function(typeId: string): string
				return MeteorService:DevSpawn(typeId)
			end
			meteorHook.Parent = ServerStorage

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
				local old = data.pets.owned[petId]
				data.pets.owned[petId] = { level = math.clamp(math.floor(level or 1), 1, Config.Pets.MaxLevel), xp = 0, copies = old and old.copies }
				if not table.find(data.pets.equipped, petId) and #data.pets.equipped < PlayerStateService:PetSlots(player) then
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

			-- game.ServerStorage.DevQuest:Invoke(game.Players:GetPlayers()[1], 3, 2): jump to a quest-line step (and its event count)
			local questHook = Instance.new("BindableFunction")
			questHook.Name = "DevQuest"
			questHook.OnInvoke = function(player: Player, step: number, count: number?)
				local data = PlayerStateService:Get(player)
				if not data then
					return nil
				end
				data.quest = { step = math.max(1, math.floor(step)), progress = math.max(0, count or 0) }
				return data.quest.step
			end
			questHook.Parent = ServerStorage

			local gearHook = Instance.new("BindableFunction")
			gearHook.Name = "DevGear"
			gearHook.OnInvoke = setGear
			gearHook.Parent = ServerStorage
		end

		-- Dev chat commands, for Studio and for the user ids in Lib.Admins on a live server (anyone
		-- else typing them is ignored without a reply). The reply shows as a notice on the HUD.
		--   /meteor <Iron|Ice|Crystal|Alien|Admin>   /pickaxe <1-8>   /backpack <1-8>   (Admin: the beginners' gift meteor)
		--   /give <player|all> cash|shards <amount> | pickaxe|backpack <tier> | pet <pet> [level]   (Lib.AdminGive)
		--   /giveall <item> ... [message]   the same as /give all ...: everyone, announced as "[DEV] Name: message"
		--   /announce <message>   a "[DEV] Name: message" banner for everyone (AnnounceService)
		--   /setlevel <player|all> <level>   sets the player level (XP cleared), up or down; the player is told
		--   /feedback [count]   prints the newest player feedback (FeedbackService) to the output (F9 on a live server)
		local TextChatService = game:GetService("TextChatService")
		local function chatCommand(alias: string, run: (Player, string?, string) -> string)
			local command = Instance.new("TextChatCommand")
			command.Name = "Dev" .. string.sub(alias, 2)
			command.PrimaryAlias = alias
			command.Triggered:Connect(function(source: TextSource, text: string)
				if not Admins.can(source.UserId, RunService:IsStudio()) then
					return
				end
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					local reply = run(player, string.match(text, "^%S+%s+(%S+)"), text)
					print("[Dev] " .. player.Name .. " " .. text .. ": " .. reply)
					ShopService.Client.Notice:Fire(player, reply)
				end
			end)
			command.Parent = TextChatService
		end
		chatCommand("/meteor", function(player, typeId)
			local reply = MeteorService:DevSpawn(typeId or "")
			if string.lower(typeId or "") == "admin" then
				Knit.GetService("AnnounceService"):Dev(player, string.format("ADMIN METEOR incoming! Everyone can mine it: %dx ore!",
					Config.Hooks.AdminMeteor.PayMult))
			end
			return reply
		end)
		chatCommand("/pickaxe", function(player, tier)
			local number = tonumber(tier)
			return if number then setGear(player, number, nil) else "Usage: /pickaxe 1-" .. #Config.Pickaxes
		end)
		chatCommand("/backpack", function(player, tier)
			local number = tonumber(tier)
			return if number then setGear(player, nil, number) else "Usage: /backpack 1-" .. #Config.Backpacks
		end)
		-- Gives a player in this server (or everyone: "all") cash, shards, a gear tier or a pet. The giver is told what
		-- happened; each recipient gets a notice. Gifts only add (AdminGive.apply), so nothing is taken away.
		local AnnounceService = Knit.GetService("AnnounceService")
		-- `quiet`: a gift to everyone is announced with one banner instead of a notice each
		local function giveTo(player: Player, recipient: Player, gift: any, quiet: boolean?): (boolean, string)
			local data = PlayerStateService:Get(recipient)
			if not data then
				return false, recipient.Name .. " has no profile loaded yet"
			end
			local result = AdminGive.apply(data, gift, PlayerStateService:PetSlots(recipient))
			if not result.changed then
				return false, recipient.Name .. " " .. result.text
			end
			if result.gear then
				ShopService:ApplyPickaxe(recipient)
			end
			PlayerStateService:ReplicateNow(recipient)
			if recipient ~= player and not quiet then
				ShopService.Client.Notice:Fire(recipient, player.DisplayName .. " gave you " .. result.text)
			end
			print(string.format("[Give] %s (%d) gave %s (%d) %s", player.Name, player.UserId, recipient.Name, recipient.UserId, result.text))
			return true, result.text
		end
		local function give(player: Player, text: string): string
			local targetName, gift, problem, message = AdminGive.parse(text)
			if not targetName or not gift then
				return problem or AdminGive.Usage
			end
			local list = Players:GetPlayers()
			if AdminGive.isEveryone(targetName) then
				local count, what, received = 0, "", {}
				for _, recipient in list do
					local ok, said = giveTo(player, recipient, gift, true)
					if ok then count += 1; what = said; received[recipient] = true end
				end
				if count > 0 then
					AnnounceService:Dev(player, message or "Gifts for everyone!", "Received " .. string.upper(what) .. "!", gift.kind, received)
				end
				return if count > 0 then string.format("Gave %d player%s %s", count, if count == 1 then "" else "s", what)
					else "Nobody here could get that (they already have it, or no profile is loaded)"
			end
			local index, reason = AdminGive.findPlayer(targetName, list, table.find(list, player))
			if not index then
				return reason or "No such player"
			end
			local ok, said = giveTo(player, list[index], gift)
			return if ok then "Gave " .. list[index].Name .. " " .. said else said
		end
		chatCommand("/give", function(player, _first, text)
			return give(player, text)
		end)
		chatCommand("/giveall", function(player, _first, text)
			return give(player, (string.gsub(text, "^%S+", "/give all", 1)))
		end)
		chatCommand("/setlevel", function(player, _first, text)
			local targetName, wanted = string.match(text, "^%S+%s+(%S+)%s+(%d+)%s*$")
			if not targetName then
				return "Usage: /setlevel <player|all> <level>"
			end
			local Levels = require(ReplicatedStorage.Shared.Levels)
			local list = Players:GetPlayers()
			local targets = list
			if not AdminGive.isEveryone(targetName) then
				local index, reason = AdminGive.findPlayer(targetName, list, table.find(list, player))
				if not index then
					return reason or "No such player"
				end
				targets = { list[index] }
			end
			local count, level = 0, 0
			for _, target in targets do
				local data = PlayerStateService:Get(target)
				if data then
					local progress = Levels.clean(tonumber(wanted), 0)
					data.level, data.xp, level = progress.level, progress.xp, progress.level
					PlayerStateService:ReplicateNow(target)
					count += 1
					if target ~= player then
						ShopService.Client.Notice:Fire(target, player.DisplayName .. " set your level to " .. level)
					end
					print(string.format("[SetLevel] %s (%d) set %s (%d) to level %d", player.Name, player.UserId, target.Name, target.UserId, level))
				end
			end
			if count == 0 then
				return "No profile loaded for that player yet"
			end
			return if #targets == 1 then targets[1].Name .. " is now level " .. level else string.format("Set %d players to level %d", count, level)
		end)
		chatCommand("/announce", function(player, _first, text)
			local message = string.match(text, "^%S+%s+(.-)%s*$")
			if not message or message == "" then
				return "Usage: /announce <message>"
			end
			return if AnnounceService:Dev(player, message) then "Announced" else "Could not announce that (text filtering failed)"
		end)
		chatCommand("/feedback", function(_player, first)
			local recent = Knit.GetService("FeedbackService"):Recent(math.clamp(tonumber(first) or 10, 1, 50))
			for _, entry in recent do
				print(string.format("[Feedback] %s %s (level %s, %d min): %s", os.date("!%Y-%m-%d %H:%M", entry.at), entry.name,
					tostring(entry.level), entry.minutes or 0, entry.text))
			end
			return #recent .. " feedback messages printed to the output (F9)"
		end)
	end)
	:catch(warn)
