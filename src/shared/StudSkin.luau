--!strict
-- The map's stud texture (tools/map-redesign/StudStyle) for parts made at runtime, so meteor crust and
-- debris rocks match the studded world. Only plain block Parts take it: a Texture does not follow a
-- union's or mesh's shape. It goes on the top face and follows the part's colour.
local StudSkin = {}

StudSkin.Texture = "rbxassetid://6927295847"
StudSkin.Name = "SkinStuds"
StudSkin.MinArea = 24 -- smallest top face (studs squared) worth texturing

function StudSkin.eligible(className: string, isBlock: boolean, sizeX: number, sizeZ: number): boolean
	return className == "Part" and isBlock and sizeX * sizeZ >= StudSkin.MinArea
end

-- Adds or refreshes the studs on `part`; removes them when the part no longer qualifies.
function StudSkin.apply(part: BasePart)
	local studs = part:FindFirstChild(StudSkin.Name) :: Texture?
	local block = part.ClassName == "Part" and (part :: Part).Shape == Enum.PartType.Block
	if not StudSkin.eligible(part.ClassName, block, part.Size.X, part.Size.Z) then
		if studs then studs:Destroy() end
		return
	end
	if not studs then
		studs = Instance.new("Texture")
		studs.Name = StudSkin.Name
		studs.Face = Enum.NormalId.Top
		studs.Texture = StudSkin.Texture
		studs.StudsPerTileU, studs.StudsPerTileV = 4, 4
		studs.Parent = part
	end
	(studs :: Texture).Color3 = part.Color
end

return StudSkin
