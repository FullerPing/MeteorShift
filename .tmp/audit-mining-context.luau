local fs=require('@lune/fs');local luau=require('@lune/luau');local rb=require('@lune/roblox');local serde=require('@lune/serde')
local function signal()return{Connect=function()end,Fire=function()end}end
local config={Meteor={SwingTolerance=.8,MineRange=12,Twists={Resonance={Window=1.5}}}}
local awarded=0
local services={PlayerStateService={GetPickaxe=function()return{Tier=1,Swing=.6,OrePerHit=1,Damage=1}end,AddOre=function(_,_,_,n)awarded+=n return n end},ActivityService={Touch=function()end},MonetizationService={OreMult=function()return 1 end}}
local modules={Config=config,MiningPower={power=function()return 1 end},Signal={new=signal},Knit={CreateService=function(def)return def end,CreateSignal=signal,GetService=function(name)return assert(services[name])end}}
local storage={Packages={Knit='Knit',Signal='Signal'},Shared={Config='Config',MiningPower='MiningPower'}}
local svc=luau.load(fs.readFile('src/server/Services/NodeService.luau'),{debugName='MiningContextAudit',injectGlobals=true,environment={
 game={GetService=function(_,name)if name=='ReplicatedStorage'then return storage else return{}end end},
 require=function(name)return assert(modules[name])end,Vector3=rb.Vector3,os={clock=function()return 100 end},
}})()
svc:KnitInit()
local attrs={};local part={Parent=true,CFrame=rb.CFrame.new(2,0,0),Size=rb.Vector3.new(4,4,4),SetAttribute=function(_,k,v)attrs[k]=v end}
local root={Position=rb.Vector3.zero}
local actor={Character={FindFirstChild=function(_,name)if name=='HumanoidRootPart'then return root end return nil end,FindFirstChildOfClass=function(_,name)if name=='Humanoid'then return{Health=0}end return nil end}}
local id=svc:Register(part,{Kind='Debris',MaxHp=10,Ore='iron',OreMult=1})
local accepted=svc:Swing(actor,id)
local hp=svc:GetHp(id)
local report={acceptedWhileDeadWithoutEquippedTool=accepted,oreAwarded=awarded,hpRemaining=hp}
fs.writeFile('.tmp/audit-mining-context.json',serde.encode('json',report,true));print(serde.encode('json',report,true))
