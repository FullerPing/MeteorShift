--!strict
-- The group stand by the spawn (PetService:_wireGroupStand, Config.Pets.GroupReward): its prompt shows Roblox's join
-- dialog, then asks the server for the group pet. Roblox can take a few seconds to report a new member, so the claim
-- is retried a few times (the server allows one fresh lookup every 5 s). HUDController toasts the pet when it arrives.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local GroupStandController = Knit.CreateController({ Name = "GroupStandController" })

local function notify(text: string)
	pcall(function() StarterGui:SetCore("SendNotification", { Title = "Free Pet", Text = text, Duration = 5 }) end)
end

function GroupStandController:KnitStart()
	local PetService = Knit.GetService("PetService")
	local state: any = nil
	local busy = false
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state = snapshot end)
	PetService.GroupStand:Connect(function()
		local reward = Config.Pets.GroupReward
		local def = Pets.def(reward.Pet)
		local name = if def then def.Name else "the pet"
		if busy or reward.GroupId == 0 then return end
		if state and state.pets and state.pets.owned[reward.Pet] then
			notify("You already have " .. name .. ". Thanks for being in the group!")
			return
		end
		busy = true
		task.spawn(function()
			pcall(function() GroupService:PromptJoinAsync(reward.GroupId) end)
			local got = false
			for attempt = 1, 3 do
				local ok, result = pcall(function() return PetService:ClaimGroupPet() end)
				got = ok and result == true
				if got or attempt == 3 then break end
				task.wait(5.5)
			end
			if not got then notify("Join the group, then use the stand again for " .. name .. ".") end
			busy = false
		end)
	end)
end

return GroupStandController
