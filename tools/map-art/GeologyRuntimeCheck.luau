-- Inject as a temporary SERVER Script during Play; never save into the place.
local H=game:GetService("HttpService")
local R=game:GetService("ReplicatedStorage")
local S=game:GetService("ServerStorage")
local result={types={}}
local function run()
	assert(game.PlaceId==0,"QA only in an unpublished local place")
	local Knit=require(R.Packages.Knit)
	local player=game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
	local state=Knit.GetService("PlayerStateService")
	local timeout=os.clock()+30
	while not state:Get(player) and os.clock()<timeout do task.wait(.2) end
	assert(state:Get(player),"Local profile failed to load")
	local meteor=Knit.GetService("MeteorService")
	local nodes=Knit.GetService("NodeService")
	local config=require(R.Shared.Config)
	meteor:SetCountdownRemaining(100)
	for _,id in {"Iron","Ice","Crystal"} do
		local m=meteor:_spawnMeteor(config.Meteor.Types[id])
		local crust=m.Model.Crust:GetChildren()
		assert(#crust==m.CrustTotal and #crust>0,"Missing assembled crust")
		local ore,rich,veins=0,0,0
		for _,p in crust do
			assert(p:IsA("UnionOperation"),"Primitive crust root")
			local isRich=p:GetAttribute("Rich")==true
			if isRich then rich+=1 end
			for _,c in p:GetDescendants() do if c:IsA("BasePart") then
				assert(c:IsA("UnionOperation"),"Primitive square crust decoration")
				if c.Name=="Ore" then
					ore+=1
					assert(c.Color==(isRich and config.Index.RichColor or config.Meteor.Types[id].OreColor),"Ore recolor mismatch")
				end
			end end
		end
		for _,p in m.Core:GetDescendants() do if p:IsA("BasePart") and p.Name=="Vein" then assert(p:IsA("UnionOperation")) assert(p.Color==config.Meteor.Types[id].GlowColor) veins+=1 end end
		meteor:_breakPart(crust[1])
		assert(crust[1].Transparency==1)
		for _,p in crust[1]:GetDescendants() do if p:IsA("BasePart") then assert(p.Transparency==1,"Detached visible chunk after break") end end
		meteor:_unlockCore(m)
		for _,p in m.Core:GetDescendants() do if p:IsA("BasePart") and p.Name=="Vein" then assert(p.Transparency==1,"Core seam did not hide") end end
		result.types[id]={crust=#crust,orePieces=ore,rich=rich,veins=veins,breakHidden=true,unlockHidden=true}
		meteor:_cleanup(m)
	end
	local stations=Knit.GetService("PlotService"):GetStations(player)
	assert(stations and stations:FindFirstChild("Hopper") and stations:FindFirstChild("CollectionPost"),"Production stations missing")
	result.plotAssigned=true
	local root=(player.Character or player.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
	local rock=workspace.Map.Debris:GetChildren()[1]
	local target=rock:GetAttribute("TargetId") assert(target,"Debris registration missing")
	root.Anchored=true root.CFrame=rock.CFrame*CFrame.new(0,4,6)
	local swings=0
	while rock.Transparency<1 and swings<12 do
		task.wait(1.2) assert(nodes:Swing(player,target),"Valid debris swing rejected") swings+=1
	end
	assert(rock.Transparency==1,"Debris failed to break")
	for _,p in rock:GetDescendants() do if p:IsA("BasePart") then assert(p.Transparency==1) end end
	result.debrisBreak={swings=swings,hidden=true}
	state:AddOre(player,"iron",20)
	local refinery=Knit.GetService("RefineryService")
	result.deposited=refinery:Deposit(player) assert(result.deposited>0)
	refinery:CatchUp(player,3600)
	result.collected=refinery:Collect(player) assert(result.collected>0)
	result.sold=Knit.GetService("EconomyService"):SellAll(player) assert(result.sold>0)
	local limit=os.clock()+65
	while rock.Transparency==1 and os.clock()<limit do task.wait(.5) end
	assert(rock.Transparency==0,"Debris failed to respawn")
	for _,p in rock:GetDescendants() do if p:IsA("BasePart") then assert(p.Transparency==0) end end
	result.debrisRespawn=true
	root.Anchored=false
	-- Exercise the real active-event CanHit and OnBroken path as well. Only this
	-- temporary QA target gets one HP; saved tuning and assets remain untouched.
	meteor:SetCountdownRemaining(0)
	local eventLimit=os.clock()+15
	repeat task.wait(.2) until meteor:GetPhase()=="Active" or os.clock()>eventLimit
	assert(meteor:GetPhase()=="Active","Meteor failed to reach Active")
	local active=workspace.Map.Crater.ActiveMeteor:GetChildren()[1]
	assert(active and active:FindFirstChild("Crust"))
	local crust=active.Crust:GetChildren()[1]
	root.Anchored=true root.CFrame=crust.CFrame*CFrame.new(0,2,6)
	local crustId=crust:GetAttribute("TargetId")
	nodes:SetMaxHp(crustId,1) task.wait(1.2)
	assert(nodes:Swing(player,crustId),"Valid active crust swing rejected")
	assert(crust.Transparency==1)
	for _,p in crust:GetDescendants() do if p:IsA("BasePart") then assert(p.Transparency==1) end end
	result.activeCrustSwing=true result.crustFixtureHp=1
	root.Anchored=false
end
local ok,err=xpcall(run,debug.traceback)
result.ok=ok result.error=not ok and tostring(err) or nil
S:SetAttribute("GeologyQAResult",H:JSONEncode(result))
print("[GeologyQA]",H:JSONEncode(result))
