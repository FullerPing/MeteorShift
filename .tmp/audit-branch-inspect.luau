local fs=require('@lune/fs')
local roblox=require('@lune/roblox')
local serde=require('@lune/serde')
local function get(root,names) local p=root for _,name in names do p=p and p:FindFirstChild(name) end return p end
local function read(p,k) local ok,v=pcall(function() return p[k] end) return if ok then tostring(v) else nil end
local sourceChecks={
 {disk='src/server/Services/DataService.luau',path={'ServerScriptService','Server','Services','DataService'}},
 {disk='src/client/Controllers/RebirthController.luau',path={'StarterPlayer','StarterPlayerScripts','Client','Controllers','RebirthController'}},
 {disk='src/client/Controllers/ShopController.luau',path={'StarterPlayer','StarterPlayerScripts','Client','Controllers','ShopController'}},
 {disk='src/server/Services/DebrisService.luau',path={'ServerScriptService','Server','Services','DebrisService'}},
 {disk='src/client/Controllers/LandingFXController.luau',path={'StarterPlayer','StarterPlayerScripts','Client','Controllers','LandingFXController'}},
}
local report={places={},exports={}}
for _,file in {'MeteorShift-newest.rbxl','MeteorShift-backpack-foundry.rbxl','MeteorShift-expanded-mining-pass.rbxl','MeteorShift-hud-redesign.rbxl','new.rbxl'} do
 local root=roblox.deserializePlace(fs.readFile(file))
 local map=get(root,{'Workspace','Map'})
 local row={file=file,classes={},sources={},outsideScripts={},decor={parts=0,collision=0,touch=0,query=0,shadow=0},parts=0,unanchored=0,preciseCollision=0}
 if map then
  for _,i in map:GetDescendants() do
   row.classes[i.ClassName]=(row.classes[i.ClassName] or 0)+1
   if i:IsA('BasePart') then
    row.parts+=1
    if not i.Anchored then row.unanchored+=1 end
    if read(i,'CollisionFidelity')=='Enum.CollisionFidelity.PreciseConvexDecomposition' then row.preciseCollision+=1 end
    if i:GetAttribute('MapArtOwned') then
     row.decor.parts+=1
     if i.CanCollide then row.decor.collision+=1 end
     if i.CanTouch then row.decor.touch+=1 end
     if i.CanQuery then row.decor.query+=1 end
     if i.CastShadow then row.decor.shadow+=1 end
    end
   end
  end
  local plots=map:FindFirstChild('Plots'); row.plots=plots and #plots:GetChildren()
  local debris=map:FindFirstChild('Debris'); row.debris=debris and #debris:GetChildren()
 end
 for _,c in sourceChecks do
  local actual=get(root,c.path)
  row.sources[c.disk]=actual and actual.Source:gsub('\r\n','\n')==fs.readFile(c.disk):gsub('\r\n','\n') or false
 end
 for _,i in root:GetDescendants() do
  if i:IsA('LuaSourceContainer') then
   local full=i:GetFullName()
   if not full:find('ServerScriptService.Server',1,true) and not full:find('ReplicatedStorage.',1,true) and not full:find('StarterPlayer.StarterPlayerScripts.Client',1,true) and not full:find('ServerStorage.Tests',1,true) then table.insert(row.outsideScripts,{path=full,class=i.ClassName,bytes=#i.Source}) end
  end
 end
 local w=root:FindFirstChild('Workspace');row.streaming=w and read(w,'StreamingEnabled')
 local players=root:FindFirstChild('Players');row.maxPlayers=players and read(players,'MaxPlayers')
 local stations=get(root,{'ServerStorage','Assets','PlotStations'})
 if stations then row.stationCount=#stations:GetDescendants();row.stationPrompts={};for _,i in stations:GetDescendants()do if i:IsA('ProximityPrompt')then table.insert(row.stationPrompts,i.Name)end end end
 table.insert(report.places,row)
 root:Destroy()
end
for _,file in {'assets/Map.rbxm','assets/ServerAssets.rbxm'} do
 local roots=roblox.deserializeModel(fs.readFile(file));local row={file=file,classes={},rootNames={}}
 for _,root in roots do table.insert(row.rootNames,root.Name);for _,i in root:GetDescendants()do row.classes[i.ClassName]=(row.classes[i.ClassName] or 0)+1 end root:Destroy()end
 table.insert(report.exports,row)
end
fs.writeFile('.tmp/audit-branch-inspect.json',serde.encode('json',report,true))
print(serde.encode('json',report,true))
