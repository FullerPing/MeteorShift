--!strict
-- A soft copy of the authored stud material, drawn below foreground artwork.
-- Static, offset texture samples approximate a small Gaussian blur without
-- blurring the world, icons, captions, or the panel's outside border.
local StudSurface = {}
local TEXTURE = "rbxassetid://6927295847"
local WHITE = Color3.new(1, 1, 1)
local CYAN = Color3.fromRGB(37, 208, 255)
local SAMPLES = {
	{ -1, -1, 1 }, { 0, -1, 2 }, { 1, -1, 1 },
	{ -1, 0, 2 }, { 0, 0, 4 }, { 1, 0, 2 },
	{ -1, 1, 1 }, { 0, 1, 2 }, { 1, 1, 1 },
}

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local item = Instance.new(class)
	for name, value in props do item[name] = value end
	item.Parent = parent
	return item
end

local function sampledStuds(parent: GuiObject, tileSize: number, zIndex: number, shadow: boolean)
	local accumulated = 0
	for index, sample in SAMPLES do
		accumulated += sample[3]
		-- Alpha-over weights normalized by the accumulated sum yield the
		-- 1/2/1 x 1/2/1 kernel rather than nine full-strength stud images.
		local opacity = sample[3] / accumulated
		make("ImageLabel", {
			Name = (if shadow then "ShadowSample" else "FaceSample") .. index,
			Position = UDim2.fromOffset(-tileSize + sample[1] * 1.8, -tileSize + sample[2] * 1.8),
			Size = UDim2.new(1, tileSize * 2, 1, tileSize * 2),
			BackgroundColor3 = if shadow then Color3.fromRGB(79, 149, 255) else WHITE,
			BackgroundTransparency = if shadow then 1 - 0.25 * opacity else 1,
			BorderSizePixel = 0, Image = TEXTURE, ImageColor3 = WHITE,
			ImageTransparency = 1 - opacity, ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(tileSize, tileSize),
			ZIndex = zIndex, Active = false, Selectable = false,
		}, parent)
	end
end

function StudSurface.blur(parent: Instance?, tileSize: number, radius: number, zIndex: number): GuiObject
	local plate = make("CanvasGroup", {
		Name = "StudBlur", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
		BorderSizePixel = 0, ClipsDescendants = true, ZIndex = zIndex,
		Active = false, Selectable = false,
	}, nil) :: GuiObject
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, plate)
	sampledStuds(plate, tileSize, zIndex, false)
	local tint = make("Frame", {
		Name = "CyanTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = CYAN,
		BorderSizePixel = 0, ZIndex = zIndex, Active = false, Selectable = false,
	}, plate)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 166, 255)),
			ColorSequenceKeypoint.new(1, WHITE),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.50625),
			NumberSequenceKeypoint.new(0.501366, 0.24375),
			NumberSequenceKeypoint.new(1, 0.49375),
		}),
	}, tint)
	sampledStuds(plate, tileSize, zIndex, true)
	make("Frame", {
		Name = "SoftVeil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(87, 178, 226),
		BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = zIndex,
		Active = false, Selectable = false,
	}, plate)
	local sheen = make("Frame", {
		Name = "TopSheen", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.42, 0),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = zIndex,
		Active = false, Selectable = false,
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius - 3)) }, sheen)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.35, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	}) }, sheen)
	local rim = make("Frame", {
		Name = "BrightRim", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = zIndex,
		Active = false, Selectable = false,
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius - 3)) }, rim)
	make("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, rim)
	plate.Parent = parent
	return plate
end

return StudSurface
