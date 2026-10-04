-- Keep child names understood by paintCluster/markRich and the core unlock path.
for _,piece in ipairs(Assets.NodePieces:GetChildren()) do
	if piece:IsA("BasePart") then
		local art=group(piece,"MineralDetails")
		for i=1,3 do
			local a=i*math.pi*2/3
			local cf=piece.CFrame*CFrame.new(math.cos(a)*piece.Size.X*0.33,piece.Size.Y*0.18,math.sin(a)*piece.Size.Z*0.33)*CFrame.Angles(0,a,0.3)
			block(art,"Rock",{1.7,1.15,1.5},cf,piece.Color,piece.Material)
			block(art,"Ore",{0.35,1.3,0.4},cf*CFrame.new(0.15,0.85,0),C.copper,M.Metal)
		end
	end
end
local core=Assets.Meteor.Core
local art=group(core,"CoreDetails")
for i=1,8 do
	local a=i*math.pi/4
	local cf=core.CFrame*CFrame.Angles(0,a,0)*CFrame.new(0,2.2,8.4)*CFrame.Angles(-0.22,0,0.15)
	block(art,"Vein",{0.2,2.6,0.28},cf,C.glow,M.Neon)
end
return {stage="Meteor",assetsParts=count(Assets)}
