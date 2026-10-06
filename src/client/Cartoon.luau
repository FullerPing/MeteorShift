--!strict
-- Bright glossy cartoon surfaces for the HUD and menus: saturated vertical
-- gradients, a thick ink outline, a darker lip underneath, a soft top shine,
-- diagonal gloss stripes, a light inner rim and a faint stud texture.
-- Builders return plain Instances so Fusion views and native menus share them.
-- Every decoration is passive (Active = false) and sits at ZIndex 0 unless told
-- otherwise, so sibling text and buttons always draw above it.

local Cartoon = {}

local WHITE = Color3.new(1, 1, 1)
local STUD_TEXTURE = "rbxassetid://6927295847"

Cartoon.FONT = Enum.Font.FredokaOne
Cartoon.INK = Color3.fromRGB(14, 24, 52)
Cartoon.WHITE = WHITE
-- Text colours that read on the white inner panels.
Cartoon.INK_BLUE = Color3.fromRGB(24, 70, 160)
Cartoon.INK_SOFT = Color3.fromRGB(78, 104, 150)
Cartoon.GOLD = Color3.fromRGB(255, 222, 74)
Cartoon.LIME = Color3.fromRGB(176, 255, 92)
Cartoon.ICE = Color3.fromRGB(196, 242, 255)

export type Swatch = { top: Color3, bottom: Color3, lip: Color3, rim: Color3 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Cartoon.Palette = {
	blue = { top = rgb(86, 186, 255), bottom = rgb(30, 104, 232), lip = rgb(16, 58, 150), rim = rgb(178, 228, 255) },
	deep = { top = rgb(56, 138, 240), bottom = rgb(22, 72, 190), lip = rgb(12, 40, 112), rim = rgb(140, 200, 255) },
	green = { top = rgb(178, 255, 74), bottom = rgb(50, 196, 30), lip = rgb(22, 110, 18), rim = rgb(220, 255, 170) },
	orange = { top = rgb(255, 210, 80), bottom = rgb(255, 128, 26), lip = rgb(170, 70, 8), rim = rgb(255, 236, 170) },
	purple = { top = rgb(212, 128, 255), bottom = rgb(140, 50, 232), lip = rgb(84, 22, 150), rim = rgb(236, 200, 255) },
	red = { top = rgb(255, 104, 118), bottom = rgb(226, 26, 56), lip = rgb(140, 10, 30), rim = rgb(255, 196, 202) },
	gold = { top = rgb(255, 240, 120), bottom = rgb(255, 178, 30), lip = rgb(176, 104, 6), rim = rgb(255, 250, 200) },
	white = { top = rgb(255, 255, 255), bottom = rgb(214, 234, 252), lip = rgb(120, 156, 210), rim = rgb(255, 255, 255) },
	slate = { top = rgb(170, 184, 204), bottom = rgb(112, 128, 152), lip = rgb(66, 78, 98), rim = rgb(214, 222, 234) },
	dark = { top = rgb(42, 58, 96), bottom = rgb(20, 30, 58), lip = rgb(8, 14, 30), rim = rgb(90, 120, 180) },
} :: { [string]: Swatch }

export type SurfaceOptions = {
	radius: number?, -- corner radius in px (default 14); use 0.5 scale via `round`
	round: boolean?, -- fully round (circles and pills)
	edge: number?, -- ink outline thickness (default 3)
	lip: number?, -- darker 3D lip under the body in px (default 4, 0 for none)
	studs: number?, -- stud texture transparency (nil = none, 0.85 is subtle)
	studSize: number?,
	stripes: boolean?, -- diagonal gloss stripes (default true)
	shine: boolean?, -- soft top highlight (default true)
	rim: boolean?, -- light inner rim (default true)
	zIndex: number?,
	name: string?,
}

local function make(class: string, props: { [string]: any }, children: { Instance }?): any
	local item = Instance.new(class)
	for key, value in props do
		(item :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = item
		end
	end
	return item
end

local function corner(radius: number, round: boolean?): UICorner
	return make("UICorner", { CornerRadius = if round then UDim.new(0.5, 0) else UDim.new(0, radius) })
end

local function passive(props: { [string]: any }, zIndex: number): { [string]: any }
	props.BorderSizePixel = 0
	props.Active = false
	props.Selectable = false
	props.ZIndex = zIndex
	return props
end

function Cartoon.swatch(kind: string): Swatch
	return Cartoon.Palette[kind] or Cartoon.Palette.blue
end

-- A full-size decorated surface for a transparent container. The container
-- keeps its own size/position; this only paints it.
function Cartoon.surface(kind: string, options: SurfaceOptions?): Frame
	local o: SurfaceOptions = options or {}
	local swatch = Cartoon.swatch(kind)
	local radius = o.radius or 14
	local edge = o.edge or 3
	local lip = o.lip or 4
	local z = o.zIndex or 0
	local inner = math.max(0, radius - 3)

	local bodyChildren: { Instance } = {
		corner(radius, o.round),
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(swatch.top, swatch.bottom) }),
		make("UIStroke", {
			Color = Cartoon.INK, Thickness = edge, LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}
	if o.studs then
		local size = o.studSize or 40
		table.insert(bodyChildren, make("ImageLabel", passive({
			Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Image = STUD_TEXTURE, ImageColor3 = WHITE, ImageTransparency = o.studs,
			ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(size, size),
		}, z), { corner(radius, o.round) }))
	end
	if o.stripes ~= false then
		-- Two hard-edged light bands across the face, like a glossy sticker.
		table.insert(bodyChildren, make("Frame", passive({
			Name = "Stripes", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE,
		}, z), {
			corner(radius, o.round),
			make("UIGradient", {
				Rotation = -62,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.50, 1),
					NumberSequenceKeypoint.new(0.501, 0.78),
					NumberSequenceKeypoint.new(0.60, 0.78),
					NumberSequenceKeypoint.new(0.601, 1),
					NumberSequenceKeypoint.new(0.66, 1),
					NumberSequenceKeypoint.new(0.661, 0.84),
					NumberSequenceKeypoint.new(0.70, 0.84),
					NumberSequenceKeypoint.new(0.701, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}))
	end
	if o.shine ~= false then
		table.insert(bodyChildren, make("Frame", passive({
			Name = "Shine", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.5, -3),
			BackgroundColor3 = WHITE,
		}, z), {
			corner(inner, o.round),
			make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}) }),
		}))
	end
	if o.rim ~= false then
		table.insert(bodyChildren, make("Frame", passive({
			Name = "Rim", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
		}, z), {
			corner(math.max(0, radius - 2), o.round),
			make("UIStroke", { Color = swatch.rim, Thickness = 2, Transparency = 0.25,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}))
	end

	local body = make("Frame", passive({
		Name = "Body", Position = UDim2.fromOffset(0, -lip), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
	}, z), bodyChildren)

	-- The lip is the parent so the body always draws above it.
	local lipFrame = make("Frame", passive({
		Name = "Lip", Position = UDim2.fromOffset(0, lip), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = swatch.lip, BackgroundTransparency = if lip > 0 then 0 else 1,
	}, z), {
		corner(radius, o.round),
		make("UIStroke", { Color = Cartoon.INK, Thickness = edge, LineJoinMode = Enum.LineJoinMode.Round,
			Transparency = if lip > 0 then 0 else 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		body,
	})

	return make("Frame", passive({
		Name = o.name or "CartoonSurface", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	}, z), { lipFrame })
end

-- Thick rounded ink outline for a TextLabel/TextButton. Size-aware by default.
function Cartoon.textStroke(thickness: number?, color: Color3?, transparency: number?): UIStroke
	return make("UIStroke", {
		Name = "TextOutline", Color = color or Cartoon.INK, Thickness = thickness or 2.5,
		Transparency = transparency or 0, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Cartoon.strokeFor(textSize: number): number
	return math.clamp(textSize * 0.13, 2, 4.5)
end

-- Restyles an existing label in place: chunky font, white fill, ink outline.
function Cartoon.outlineLabel(label: TextLabel | TextButton | TextBox, thickness: number?)
	label.Font = Cartoon.FONT
	label.TextStrokeTransparency = 1
	local existing = label:FindFirstChild("TextOutline")
	if existing then existing:Destroy() end
	Cartoon.textStroke(thickness or Cartoon.strokeFor(label.TextSize)).Parent = label
end

-- A small "progress meter": ink track with a rounded coloured fill. Returns the
-- track and its fill so callers can drive Size.
function Cartoon.meterTrack(): (Frame, Frame)
	local fill = make("Frame", {
		Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Cartoon.LIME, BorderSizePixel = 0,
	}, {
		corner(0, true),
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 200)) }),
	})
	local track = make("Frame", {
		Name = "Track", BackgroundColor3 = Color3.fromRGB(10, 22, 56), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, {
		corner(0, true),
		make("UIStroke", { Color = Cartoon.INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		fill,
	})
	return track, fill
end

return Cartoon

