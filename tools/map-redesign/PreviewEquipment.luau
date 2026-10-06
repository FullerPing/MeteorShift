-- Static Edit art preview only. Does not implement state, rotation or gameplay.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
local hall=workspace.Map_Redesign.TownSquare.GearHall
local builders=require(game.ReplicatedStorage.Shared.EquipmentModels)
local previous=hall:FindFirstChild("EquipmentArtPreview")
if previous then
	assert(previous:GetAttribute("PreviewOnly"), "Unowned equipment preview")
	previous:Destroy()
end
local preview=Instance.new("Folder")
preview.Name="EquipmentArtPreview"
preview:SetAttribute("PreviewOnly",true)
preview:SetAttribute("MapRedesignOwned",true)
local models,parts=0,0
local function mount(kind,tier,frame,scale,bottomY,name)
	local model=builders[kind](tier)
	model.Name=name
	model:SetAttribute("PreviewOnly",true)
	model:SetAttribute("EquipmentKind",kind)
	model:SetAttribute("EquipmentTier",tier)
	model:ScaleTo(scale)
	model:PivotTo(frame)
	if bottomY then
		local box,size=model:GetBoundingBox()
		model:PivotTo(model:GetPivot()+Vector3.new(0,bottomY-(box.Position.Y-size.Y/2),0))
	end
	for _,v in model:GetDescendants() do
		assert(not v:IsA("LuaSourceContainer"),"Code in equipment art")
		if v:IsA("BasePart") then
			v.Anchored=true
			v.CanCollide,v.CanTouch,v.CanQuery=false,false,false
			parts+=1
		end
	end
	model.Parent=preview
	models+=1
end
for _,card in hall.TierWalls:GetChildren() do
	mount(card:GetAttribute("EquipmentKind"),card:GetAttribute("EquipmentTier"),
		card.CFrame*card:GetAttribute("DisplayOffset"),card:GetAttribute("DisplayScale"),nil,card.Name)
end
for _,stand in hall.CurrentStands:GetChildren() do
	local bottom=stand:GetPivot():PointToWorldSpace(stand:GetAttribute("DisplayBottomOffset")).Y
	mount(stand:GetAttribute("EquipmentKind"),1,stand:GetPivot()*stand:GetAttribute("DisplayOffset"),
		stand:GetAttribute("DisplayScale"),bottom,"CurrentArt_"..stand.Name)
end
assert(models==18 and parts<=650,"Equipment preview budget")
preview.Parent=hall
return {previewOnly=true,models=models,parts=parts,livePlayerStateConnected=false}
