--!strict
-- Draws the prize wheel: a thick outer rim, coloured segments with the prize
-- and its odds on each, a spin button at the hub and a ticker at the top.
--
-- Used twice over -- once at full size in the Wheel panel, once on the face of
-- the wheel standing in the hub -- so the two can't drift apart. Everything is
-- sized in scale, so the same drawing works at 340px and at 850.
--
-- Roblox GUIs can't draw a wedge, so each segment is fanned out of thin
-- rectangles pinned at the centre. They pile up in the middle, which is what
-- the hub covers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)

local Palette = Components.Palette
local Prizes = Config.Balance.Wheel.Prizes
local Theme = Config.Theme

-- Thin rectangles per segment. More is smoother, at one frame each.
local SLIVERS_PER_SEGMENT = 14
-- A shade wider than the gap they fill, so no seams show between them.
local SLIVER_OVERLAP = 1.08
-- Fractions of the wheel's width.
local RIM_THICKNESS = 0.055
local HUB_SIZE = 0.23
local LABEL_RADIUS = 0.31
local DIVIDER_WIDTH = 0.007

-- The box a segment's two lines are drawn in, as fractions of the wheel: length
-- runs along the radius, depth across the arc. Both lines are TextScaled, so
-- this box is the only thing deciding how big the writing comes out -- and the
-- depth is what was holding the odds down to a few pixels on the wheel standing
-- in the hub.
--
-- How deep it can go is set by its neighbours. Eight segments at a radius of
-- 0.31 leave about 0.24 of arc each, so the box has that much before two labels
-- start to touch. Its length is bounded the same way at both ends: the hub
-- reaches 0.115 and the dial ends at 0.5, so a box 0.32 long centred at 0.31
-- runs from 0.15 to 0.47 and clears both.
local LABEL_LENGTH = 0.32
local LABEL_DEPTH = 0.17
-- How that depth is split. The odds are the number players are actually reading
-- off a wheel, so they get more of it than the two-thirds they had.
local LABEL_NAME_SHARE = 0.56
local LABEL_ODDS_SHARE = 0.4

local WheelFace = {}

export type Face = {
	Instance: Frame,
	setRotation: (number) -> (),
	setSpinEnabled: (boolean) -> (),
}

local function circle(props: { [string]: any }): Frame
	local frame: Frame = Components.new("Frame", props)
	Components.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	return frame
end

-- One radial rectangle running from the hub out to the rim at `angle`.
--
-- Centred on the middle of the spoke, not pinned at the hub: Rotation pivots a
-- GuiObject about its own centre and ignores AnchorPoint entirely, so anchoring
-- at the hub left every spoke spinning about its own midpoint in the same spot
-- instead of fanning out around the wheel.
local function spoke(name: string, angle: number, width: number, color: Color3, parent: Instance): Frame
	local radians = math.rad(angle)
	return Components.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.sin(radians) * 0.25, 0.5 - math.cos(radians) * 0.25),
		Size = UDim2.fromScale(width, 0.5),
		Rotation = angle,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- `props` positions the square the wheel is drawn in; it must be square, or the
-- segments come out as ellipse slices.
function WheelFace.create(props: { [string]: any }, onSpin: () -> ()): Face
	local segmentAngle = 360 / #Prizes
	local palette = Palette :: { [string]: Color3 }

	local merged: { [string]: any } = { BackgroundTransparency = 1 }
	for key, value in props do
		merged[key] = value
	end
	local root: Frame = Components.new("Frame", merged)

	-- The pale rim the segments sit inside.
	local rim = circle({
		Name = "Rim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.World.Border,
		BorderSizePixel = 0,
		Parent = root,
	})
	Components.stroke(Palette.Text, 4).Parent = rim

	local dial: Frame = Components.new("Frame", {
		Name = "Dial",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1 - RIM_THICKNESS * 2, 1 - RIM_THICKNESS * 2),
		BackgroundTransparency = 1,
		Parent = root,
	})

	local spinner: Frame = Components.new("Frame", {
		Name = "Spinner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = dial,
	})

	local art = if Theme.Images then Theme.Images.Wheel else nil
	if art then
		-- A supplied face replaces the drawn segments; the labels still go over
		-- it, so artwork only has to provide the colours and the dividers.
		Components.new("ImageLabel", {
			Name = "Art",
			BackgroundTransparency = 1,
			Image = art,
			Size = UDim2.fromScale(1, 1),
			Parent = spinner,
		})
	else
		local step = segmentAngle / SLIVERS_PER_SEGMENT
		local width = math.tan(math.rad(step / 2)) * SLIVER_OVERLAP
		for index, prize in Prizes do
			local base = palette[prize.Tone] or Palette.Primary
			-- Alternate segments a touch darker: that banding is most of what
			-- makes a wheel read as a wheel at a glance.
			local color = if index % 2 == 0 then base:Lerp(Color3.new(), 0.16) else base
			local start = (index - 1) * segmentAngle - segmentAngle / 2
			for slice = 1, SLIVERS_PER_SEGMENT do
				spoke(`Slice{index}_{slice}`, start + (slice - 0.5) * step, width, color, spinner)
			end
		end
		-- Dividers last, so they sit over the segments they separate.
		for index = 1, #Prizes do
			spoke(
				`Divider{index}`,
				(index - 1) * segmentAngle - segmentAngle / 2,
				DIVIDER_WIDTH,
				Palette.Background,
				spinner
			)
		end
	end

	-- Labels read along their wedge, the way a real wheel's do. A wedge is long
	-- and narrow, so radial text fits names like "Bonus Unit" that would crowd
	-- their neighbours laid across the arc.
	--
	-- Every one of them reads the same way: from the hub outward. Turning the
	-- far half round to keep its words upright is what a printed wheel does, but
	-- on a wheel that spins it reads as half the labels being wrong -- the eye
	-- takes the mixture for a mistake long before it thanks you for the two
	-- words it didn't have to tilt its head at.
	for index, prize in Prizes do
		local degrees = (index - 1) * segmentAngle
		local angle = math.rad(degrees)
		local holder: Frame = Components.new("Frame", {
			Name = `Label{index}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(angle) * LABEL_RADIUS, 0.5 - math.cos(angle) * LABEL_RADIUS),
			-- Width runs along the radius once rotated, height across the arc.
			Size = UDim2.fromScale(LABEL_LENGTH, LABEL_DEPTH),
			Rotation = degrees - 90,
			BackgroundTransparency = 1,
			Parent = spinner,
		})
		-- The name sits nearer the hub and the odds outside it, on every wedge.
		Components.label({
			Text = prize.Label,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, LABEL_NAME_SHARE),
			Stroke = 3,
			Parent = holder,
		})
		Components.label({
			Text = `{string.format("%.0f", Economy.prizeChance(index) * 100)}%`,
			Position = UDim2.fromScale(0, 1 - LABEL_ODDS_SHARE),
			Size = UDim2.fromScale(1, LABEL_ODDS_SHARE),
			TextColor3 = Palette.Accent,
			Stroke = 3,
			Parent = holder,
		})
	end

	-- The hub doubles as the spin button, the way the arcade ones do.
	local hub = Components.button({
		Name = "SpinButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(HUB_SIZE, HUB_SIZE),
		Text = "SPIN",
		BackgroundColor3 = Palette.Positive,
		Parent = dial,
	}, onSpin)
	-- Round it off, over the square corners `button` gives everything else, and
	-- ring it in gold. Only the lip and the face: the caption's own outline is
	-- nested inside the label, so this leaves the text crisp.
	for _, child in hub.Instance:GetChildren() do
		local corner = child:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		local outline = child:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Color = Palette.Accent
			outline.Thickness = 4
		end
	end

	-- The ticker, fixed to the rim so the dial turns under it.
	local pointer: Frame = Components.new("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.045),
		Size = UDim2.fromScale(0.095, 0.095),
		Rotation = 45,
		BackgroundColor3 = Palette.Negative,
		BorderSizePixel = 0,
		Parent = root,
	})
	Components.corner(4).Parent = pointer
	Components.stroke(Palette.Text, 3).Parent = pointer

	return {
		Instance = root,
		setRotation = function(degrees: number)
			spinner.Rotation = degrees
		end,
		setSpinEnabled = hub.setEnabled,
	}
end

return WheelFace
