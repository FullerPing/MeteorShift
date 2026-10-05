--!strict
-- Both follower and hatch previews use the same saved geometry conventions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Effect = { instance: any, enabled: boolean, brightness: number? }
export type Piece = { part: BasePart, rest: CFrame, group: string, pivot: Vector3, color: Color3 }
export type Visual = { model: Model, pieces: { Piece }, effects: { Effect }, flying: boolean, style: string, height: number, groundOffset: number }

local PetModel = {}
local hiddenWork = {
	WorkingRing = true, SparkLink = true, GreyChip = true, CoinGlint = true, TargetShard = true,
	TunnelLight = true, TunnelOre = true, FlameBreath = true, ArrivalStreak = true, HeatWave = true, ScorchGlow = true,
}

function PetModel.source(id: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local model = folder and folder:FindFirstChild(id)
	return if model and model:IsA("Model") then model else nil
end

function PetModel.clone(id: string, level: number): Visual?
	local source = PetModel.source(id)
	if not source then return nil end
	local ok, clone = pcall(function() return source:Clone() end)
	if not ok or not clone then return nil end
	local model = clone :: Model
	local upgraded = model:FindFirstChild("Level10")
	if upgraded and upgraded:IsA("Folder") then
		if level >= 10 then
			for _, item in model:GetChildren() do
				if item ~= upgraded then item:Destroy() end
			end
			for _, item in upgraded:GetChildren() do item.Parent = model end
		end
		upgraded:Destroy()
	end
	local body = model:FindFirstChild("Body", true)
	if not body or not body:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = body
	local tint = model:GetAttribute("PetColor")
	local pivot = model:GetPivot()
	local pieces: { Piece } = {}
	local effects: { Effect } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
			item.Massless = true
			if item.Name == "Body" and typeof(tint) == "Color3" then item.Color = tint end
			if hiddenWork[item:GetAttribute("AnimationGroup")] then item.Transparency = 1 end
			if level >= 5 and level < 10 and item:GetAttribute("Pannier") == true then item.Size *= 1.15 end
			local group = item:GetAttribute("AnimationGroup")
			local localPivot = item:GetAttribute("AnimationPivot")
			table.insert(pieces, {
				part = item, rest = pivot:ToObjectSpace(item.CFrame),
				group = if typeof(group) == "string" then group else item.Name,
				pivot = if typeof(localPivot) == "Vector3" then pivot:PointToObjectSpace(localPivot) else Vector3.zero,
				color = item.Color,
			})
		elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") or item:IsA("Light") then
			table.insert(effects, { instance = item, enabled = item.Enabled, brightness = if item:IsA("Light") then item.Brightness else nil })
		end
	end
	local boundsFrame, bounds = model:GetBoundingBox()
	return {
		model = model, pieces = pieces, effects = effects,
		flying = model:GetAttribute("Flying") == true,
		style = tostring(model:GetAttribute("WorkingStyle") or "dig"), height = bounds.Y,
		groundOffset = pivot.Position.Y - (boundsFrame.Position.Y - bounds.Y / 2),
	}
end

function PetModel.reduce(visual: Visual, reduced: boolean)
	for _, effect in visual.effects do effect.instance.Enabled = not reduced and effect.enabled end
end

function PetModel.burst(visual: Visual)
	for _, effect in visual.effects do
		if effect.instance:IsA("ParticleEmitter") and effect.instance:GetAttribute("WorkingBurst") == true then
			effect.instance:Emit(6)
		end
	end
end

return PetModel
