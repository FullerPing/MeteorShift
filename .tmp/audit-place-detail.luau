local fs=require('@lune/fs');local rb=require('@lune/roblox');local serde=require('@lune/serde')
local root=rb.deserializePlace(fs.readFile('MeteorShift-backpack-foundry.rbxl'))
local report={collision={},extraScripts={},assetLoadIds={},assetTemplates={}}
local function get(names)local p=root for _,n in names do p=p and p:FindFirstChild(n)end return p end
local map=get({'Workspace','Map'})
for _,p in map:GetDescendants()do
 if p:IsA('UnionOperation') then local ok,value=pcall(function()return p.CollisionFidelity end);local key=if ok then tostring(value)else 'UNAVAILABLE_IN_LUNE';report.collision[key]=(report.collision[key] or 0)+1 end
 if p:IsA('MeshPart')then local ok,value=pcall(function()return p.MeshId end);local id=if ok then tostring(value)else 'UNAVAILABLE_IN_LUNE';report.assetLoadIds[id]=(report.assetLoadIds[id] or 0)+1 end
end
local ss=get({'ServerScriptService'})
for _,i in ss:GetChildren()do if i:IsA('LuaSourceContainer')then table.insert(report.extraScripts,{path=i:GetFullName(),enabled=not i.Disabled,source=i.Source})end end
local assets=get({'ServerStorage','Assets'})
for _,i in assets:GetChildren()do report.assetTemplates[i.Name]={class=i.ClassName,descendants=#i:GetDescendants()}end
local core=get({'ServerStorage','Assets','Meteor','Core'});report.coreSlots=0
for _,i in core:GetChildren()do if i:IsA('Attachment')and i.Name=='NodeSlot'then report.coreSlots+=1 end end
local nodePieces=assets:FindFirstChild('NodePieces');report.nodePieceBounds={}
for _,i in nodePieces:GetChildren()do table.insert(report.nodePieceBounds,{name=i.Name,class=i.ClassName,descendants=#i:GetDescendants()})end
fs.writeFile('.tmp/audit-place-detail.json',serde.encode('json',report,true));print(serde.encode('json',report,true));root:Destroy()
