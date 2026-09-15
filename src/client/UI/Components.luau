--!strict
-- Themed UI builders. Every panel is built from these so a reskin only needs
-- to change the theme's palette and font.
--
-- The look follows Roblox's own UI guidance: one visual language reused
-- everywhere, buttons that read as physically pressable, size and colour used
-- to signal importance, and nothing on screen the player doesn't need now.
--
-- Dressed the way the front page of the platform dresses: every surface carries
-- a heavy near-black outline, corners are generous, fills ramp from light to
-- dark, buttons wear a gloss over the top half and sit on a lip they sink onto,
-- and text is outlined in the same near-black as the surfaces. It reads as one
-- material -- thick plastic -- rather than as flat panels, which is what makes
-- a screen full of it look built rather than assembled.
--
-- All of it is drawn from the theme's own palette and needs no artwork. The one
-- place art helps is the pattern behind a card, which a theme can point at with
-- Images.CardPattern; without one it's built from parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme
local Palette = Theme.Palette

local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- One radius and one rhythm, so every surface in the game matches. Generous,
-- because a chunky outline around a tight corner reads as a mistake.
local RADIUS = 18
local BUTTON_RADIUS = 16
local PANEL_RADIUS = 24
-- The lip under a button that makes it look raised. Pressing sinks onto it.
local BEVEL = 6

-- The near-black everything is outlined in. Derived from the theme's own
-- background rather than fixed, so a pale skin gets a dark grey rather than the
-- same black a dark one does -- but pushed far enough down that it always reads
-- as an outline instead of as another surface.
local OUTLINE = Palette.Background:Lerp(Color3.new(), 0.6)
-- Heavy on purpose. This single number is most of the difference between the
-- flat look and the moulded one, and it is the first thing to turn down if a
-- skin wants to be softer.
local OUTLINE_THICKNESS = 3
local PANEL_OUTLINE_THICKNESS = 4
local PILL_OUTLINE_THICKNESS = 3
-- A button wears two: the dark one on its lip, which draws the whole silhouette,
-- and a light one on the face, which catches the edge the way a moulded plastic
-- part does.
local FACE_OUTLINE_THICKNESS = 2
-- Bold text on a saturated fill needs its own outline to stay legible.
local TEXT_STROKE = 3
-- The pale counterpart to OUTLINE. Dark text is outlined in this instead.
local LIGHT_OUTLINE = Color3.new(1, 1, 1)
-- A pale halo reads heavier than a dark one of the same width, because it grows
-- outward into the fill where a dark one is read as part of the letterform. So
-- a light outline is drawn thinner to weigh the same.
local LIGHT_OUTLINE_WEIGHT = 0.7
-- Ceiling on an outline as a share of the text's own height. Past roughly this
-- the stroke starts closing the counters -- the holes in e, a and G -- and a
-- word turns into a row of blobs. It's the reason the cap matters as much as
-- the colour: an outline that fat is unreadable whatever colour it is.
local TEXT_STROKE_RATIO = 0.1
local MAX_TEXT_STROKE = 8

-- The checker behind a patterned card, when the theme supplies no image for it.
-- Kept small: the pattern is texture, and a texture you can count the squares of
-- is a graphic instead.
local CHECKER_COLUMNS = 8
local CHECKER_ROWS = 5
local CHECKER_STRENGTH = 0.82
-- Each column edge costs two keypoints, because a hard step is two stops a hair
-- apart, and a NumberSequence takes twenty. Ten columns is the ceiling, so this
-- says so here rather than throwing from inside a gradient when someone raises
-- it for a skin that wants a finer weave.
assert(
	2 + (CHECKER_COLUMNS - 1) * 2 <= 20,
	`CHECKER_COLUMNS of {CHECKER_COLUMNS} needs more keypoints than a NumberSequence holds`
)

-- Props that position a widget rather than paint it. `button` puts these on
-- its outer frame and everything else on the clickable face inside.
local LAYOUT_PROPS: { [string]: boolean } = {
	Name = true,
	Parent = true,
	Position = true,
	Size = true,
	AnchorPoint = true,
	LayoutOrder = true,
	Visible = true,
	ZIndex = true,
}

local Components = {}

Components.Palette = Palette
Components.Font = Theme.Font
Components.Radius = RADIUS

-- What sits in front of what. The HUD is built at the default ZIndex, and with
-- Sibling behaviour a frame's whole subtree travels with it, so setting one
-- number on a panel's root lifts everything inside it. Without this the order
-- is decided by which was created first, which put the buy button in front of
-- every panel that opens over it.
Components.Layer = {
	Hud = 1,
	Panel = 5,
	-- Above the panels: a toast about what just happened is worth reading even
	-- while something is open.
	Toast = 8,
	-- Above everything, because it's asking a question about what's behind it.
	Dialog = 10,
}

function Components.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	-- Parent last so the instance is fully built when it enters the tree.
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

-- Rec. 709 relative luminance. Green is weighted heaviest because the eye
-- weighs it heaviest; a plain average calls gold and mid-blue equally bright,
-- which is exactly the pair this has to tell apart.
local function luminance(color: Color3): number
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

-- The outline for a piece of text, and how thick to draw it.
--
-- An outline is there to separate a glyph from whatever is behind it, so the
-- thing it has to contrast with is the glyph -- not the background. Outlining
-- dark text in near-black, which is what one fixed outline colour ends up doing,
-- contrasts 1.8:1 against the letterform: the halo is invisible and all it does
-- is fatten the glyph until its counters close. Flipping it to white on the same
-- text is 5.5:1, and the word reads.
local function outlineFor(textColor: Color3): (Color3, number)
	if luminance(textColor) > 0.5 then
		return OUTLINE, 1
	end
	return LIGHT_OUTLINE, LIGHT_OUTLINE_WEIGHT
end

function Components.corner(radius: number): UICorner
	return Components.new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Components.stroke(color: Color3, thickness: number): UIStroke
	return Components.new("UIStroke", { Color = color, Thickness = thickness })
end

function Components.padding(pixels: number): UIPadding
	local offset = UDim.new(0, pixels)
	return Components.new("UIPadding", {
		PaddingTop = offset,
		PaddingBottom = offset,
		PaddingLeft = offset,
		PaddingRight = offset,
	})
end

-- A top-to-bottom lightness ramp. Flat fills read as stickers; a slight ramp
-- gives a surface volume without needing any art.
function Components.gradient(strength: number): UIGradient
	return Components.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1 - strength, 1 - strength, 1 - strength)),
		}),
	})
end

-- The shine over the top half of a pressable surface. A flat gradient gives a
-- surface volume; this gives it a finish, which is the difference between a
-- coloured rectangle and something that looks moulded.
function Components.gloss(parent: GuiObject, radius: number): Frame
	local shine: Frame = Components.new("Frame", {
		Name = "Gloss",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0.5),
		-- Not a child of the input surface's own gradient chain, so it keeps its
		-- own ramp: bright at the crown, gone by the waist.
		Parent = parent,
	})
	Components.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shine,
	})
	Components.corner(radius).Parent = shine
	return shine
end

-- A hard-edged alternating ramp across one axis: the squares of one row of a
-- checker. UIGradient interpolates, so each edge is two keypoints a hair apart,
-- which is what makes the step rather than a blur. `offset` shifts the row by
-- half a square, which is what makes the rows below a checker and not stripes.
local function checkerRow(offset: boolean): NumberSequence
	local keypoints: { NumberSequenceKeypoint } = {}
	local step = 1 / CHECKER_COLUMNS
	local epsilon = 0.001

	local function valueAt(index: number): number
		local filled = (index % 2 == 0) ~= offset
		return if filled then CHECKER_STRENGTH else 1
	end

	table.insert(keypoints, NumberSequenceKeypoint.new(0, valueAt(0)))
	for index = 1, CHECKER_COLUMNS - 1 do
		local at = index * step
		table.insert(keypoints, NumberSequenceKeypoint.new(at - epsilon, valueAt(index - 1)))
		table.insert(keypoints, NumberSequenceKeypoint.new(at, valueAt(index)))
	end
	table.insert(keypoints, NumberSequenceKeypoint.new(1, valueAt(CHECKER_COLUMNS - 1)))
	return NumberSequence.new(keypoints)
end

-- The pattern behind a card's contents. A theme with `Images.CardPattern` gets
-- that tiled; without one it's built from a handful of rows, each a single
-- gradient of hard-edged squares. One frame per row rather than one per square:
-- a forty-square checker built literally is forty instances per card, and a
-- garden's worth of cards is then a few thousand for a texture.
function Components.pattern(parent: GuiObject): Frame
	local holder: Frame = Components.new("Frame", {
		Name = "Pattern",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		-- Under everything the card puts in it. The pattern is texture; anything
		-- that has to be read sits on top of it.
		ZIndex = 0,
		ClipsDescendants = true,
		Parent = parent,
	})
	Components.corner(RADIUS).Parent = holder

	local image = Theme.Images and Theme.Images.CardPattern
	if image then
		Components.new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = image,
			ImageTransparency = CHECKER_STRENGTH,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(32, 32),
			Parent = holder,
		})
		return holder
	end

	for row = 1, CHECKER_ROWS do
		local strip: Frame = Components.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1 / CHECKER_ROWS),
			Position = UDim2.fromScale(0, (row - 1) / CHECKER_ROWS),
			Parent = holder,
		})
		Components.new("UIGradient", {
			Transparency = checkerRow(row % 2 == 0),
			Parent = strip,
		})
	end
	return holder
end

-- A dark slab behind a panel, offset down. Without one a panel floats on the 3D
-- world with nothing separating it from the scenery; with one it sits over it.
--
-- A sibling of the panel rather than a child of it, which is the whole reason
-- this is a function and not three lines inside `panel`. A child always draws in
-- front of its parent's own background whatever its ZIndex, so a shadow parented
-- to the panel would be a dark border painted across the front of it. It mirrors
-- the panel's geometry instead, and is shown and hidden alongside it.
function Components.shadow(parent: Instance, size: UDim2, radius: number, zIndex: number): Frame
	local shade: Frame = Components.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = OUTLINE,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(size.X.Scale, size.X.Offset + 14, size.Y.Scale, size.Y.Offset + 14),
		Visible = false,
		ZIndex = zIndex,
		Parent = parent,
	})
	Components.corner(radius + 4).Parent = shade
	return shade
end

function Components.listLayout(props: { [string]: any }?): UIListLayout
	local merged: { [string]: any } = {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}
	local overrides: { [string]: any } = props or {}
	for key, value in overrides do
		merged[key] = value
	end
	return Components.new("UIListLayout", merged)
end

-- `Stroke` outlines the text. Roblox's guidance is to outline any text drawn
-- over the 3D world, which is every label on the garden board.
function Components.label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Palette.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	local stroke: number? = nil
	local maxTextSize: number? = nil
	for key, value in props do
		if key == "Stroke" then
			stroke = value
		elseif key == "MaxTextSize" then
			maxTextSize = value
		else
			merged[key] = value
		end
	end

	local label: TextLabel = Components.new("TextLabel", merged)
	if stroke then
		local color, weight = outlineFor(merged.TextColor3)
		Components.new("UIStroke", {
			Color = color,
			Thickness = stroke * weight,
			Parent = label,
		})
	end
	if maxTextSize then
		Components.new("UITextSizeConstraint", { MaxTextSize = maxTextSize, Parent = label })
	end
	return label
end

-- A rounded surface used for pills, cards and panel bodies.
--
-- `Pattern = true` puts the checker behind whatever the caller fills it with.
-- Opt-in rather than everywhere, because most cards here are small chips and a
-- texture inside a 30-pixel row is noise.
function Components.card(props: { [string]: any }, children: { Instance }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Palette.Surface,
		BorderSizePixel = 0,
	}
	local patterned = false
	for key, value in props do
		if key == "Pattern" then
			patterned = value == true
		else
			merged[key] = value
		end
	end
	local frame = Components.new("Frame", merged, children)
	Components.corner(RADIUS).Parent = frame
	Components.stroke(OUTLINE, OUTLINE_THICKNESS).Parent = frame
	Components.gradient(0.18).Parent = frame
	if patterned then
		Components.pattern(frame)
	end
	return frame
end

export type Button = {
	Instance: Frame,
	setText: (string) -> (),
	setIcon: (string) -> (),
	setBadge: (string?) -> (),
	setEnabled: (boolean) -> (),
}

-- A raised button sitting on a darker lip, which it sinks onto when pressed.
-- Roblox's guidance is that a button needs a container with shading to read as
-- pressable at all, and that a press must visibly answer the player.
function Components.button(props: { [string]: any }, onClick: () -> ()): Button
	local color = props.BackgroundColor3 or Palette.Primary
	local textColor = props.TextColor3 or Palette.Text
	-- How big the caption may grow. The default suits a button on the screen;
	-- one drawn on a SurfaceGui is measured in that surface's own pixels, where
	-- a board 1900 across gives a tile a caption box 130 tall and this cap is
	-- what decides whether the price in it is readable from the gate or not.
	local maxTextSize = props.MaxTextSize or 28

	local layout: { [string]: any } = { BackgroundTransparency = 1 }
	local face: { [string]: any } = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		-- The caption is a child label, so the face's own gradient can't tint it.
		Text = "",
	}
	for key, value in props do
		if LAYOUT_PROPS[key] then
			layout[key] = value
		elseif key ~= "Text" and key ~= "TextColor3" and key ~= "MaxTextSize" then
			face[key] = value
		end
	end

	local wrapper: Frame = Components.new("Frame", layout)

	-- The lip. Sized to the whole button so it shows below the face.
	local lip: Frame = Components.new("Frame", {
		BackgroundColor3 = color:Lerp(Color3.new(), 0.45),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = wrapper,
	})
	Components.corner(BUTTON_RADIUS).Parent = lip
	-- The dark outline goes on the lip, which is the full silhouette: put on the
	-- face instead it would draw a line across the middle of the button where
	-- the face ends and the lip below it begins.
	Components.stroke(OUTLINE, OUTLINE_THICKNESS).Parent = lip

	face.Size = UDim2.new(1, 0, 1, -BEVEL)
	face.Position = UDim2.fromOffset(0, 0)
	local button: TextButton = Components.new("TextButton", face)
	Components.corner(BUTTON_RADIUS).Parent = button
	Components.gradient(0.26).Parent = button
	-- The light edge, inside the dark one. Two outlines is what a moulded
	-- plastic part looks like: a dark seam and a lit edge just inside it.
	Components.stroke(color:Lerp(Color3.new(1, 1, 1), 0.55), FACE_OUTLINE_THICKNESS).Parent = button
	Components.gloss(button, BUTTON_RADIUS)
	button.Parent = wrapper

	-- A plain label rather than the button's own Text: a UIGradient shades the
	-- text of whatever it sits on, which would dim the caption along with the
	-- face. TextLabels don't take input, so clicks still reach the button.
	local caption: TextLabel = Components.label({
		Text = props.Text or "",
		Size = UDim2.new(1, -18, 1, -14),
		Position = UDim2.fromOffset(9, 7),
		TextColor3 = textColor,
		-- Scaled off how big the caption may grow rather than fixed. The same
		-- three pixels that suit a 28px caption on a phone are a hairline on the
		-- 83px one the garden board draws, and a caption's outline should carry
		-- the same weight at both.
		Stroke = math.min(maxTextSize * TEXT_STROKE_RATIO, MAX_TEXT_STROKE),
		-- Over the gloss, which is a sibling drawn after it.
		ZIndex = 2,
		-- TextScaled alone lets short labels balloon on a big button.
		MaxTextSize = maxTextSize,
		Parent = button,
	})

	-- A count clipped to the top-right corner, like "x10" on a shop button.
	-- Hidden until something is put in it.
	local badge: Frame = Components.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -8),
		Size = UDim2.fromOffset(44, 26),
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	})
	Components.corner(10).Parent = badge
	Components.stroke(Palette.Text, 2).Parent = badge
	local badgeLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, -8, 1, -6),
		Position = UDim2.fromOffset(4, 3),
		MaxTextSize = 18,
		Parent = badge,
	})

	local enabled = true
	local icon = ""
	local text = props.Text or ""

	local function tweenColor(target: Color3)
		TweenService:Create(button, HOVER_TWEEN, { BackgroundColor3 = target }):Play()
		TweenService:Create(lip, HOVER_TWEEN, { BackgroundColor3 = target:Lerp(Color3.new(), 0.45) }):Play()
	end

	local function setPressed(pressed: boolean)
		TweenService:Create(button, PRESS_TWEEN, {
			Position = UDim2.fromOffset(0, if pressed then BEVEL else 0),
		}):Play()
	end

	local function render()
		caption.Text = if icon ~= "" and text ~= "" then `{icon}  {text}` elseif icon ~= "" then icon else text
	end

	button.MouseEnter:Connect(function()
		if enabled then
			tweenColor(color:Lerp(Color3.new(1, 1, 1), 0.18))
		end
	end)
	button.MouseLeave:Connect(function()
		if enabled then
			tweenColor(color)
			setPressed(false)
		end
	end)
	button.MouseButton1Down:Connect(function()
		if enabled then
			setPressed(true)
		end
	end)
	button.MouseButton1Up:Connect(function()
		if enabled then
			setPressed(false)
		end
	end)
	button.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)

	return {
		Instance = wrapper,
		setText = function(value: string)
			text = value
			render()
		end,
		setIcon = function(value: string)
			icon = value
			render()
		end,
		setBadge = function(value: string?)
			badge.Visible = value ~= nil
			badgeLabel.Text = value or ""
		end,
		-- Grey and flat: the convention players already read as "can't use this".
		setEnabled = function(value: boolean)
			if value == enabled then
				return
			end
			enabled = value
			tweenColor(if value then color else Palette.Surface)
			caption.TextTransparency = if value then 0 else 0.4
			setPressed(false)
		end,
	}
end

export type Bar = {
	Instance: Frame,
	setProgress: (number) -> (),
}

function Components.bar(props: { [string]: any }): Bar
	local container = Components.card(props)
	container.BackgroundColor3 = Palette.Background
	local fill: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = container,
	})
	Components.corner(RADIUS).Parent = fill
	Components.gradient(0.2).Parent = fill
	return {
		Instance = container,
		setProgress = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		end,
	}
end

export type Pill = {
	Instance: Frame,
	setText: (string) -> (),
	setVisible: (boolean) -> (),
}

-- An icon-and-value chip for a single stat. Icons carry the meaning at a
-- glance, which matters most on a phone where there's no room for words.
function Components.pill(props: { [string]: any }, icon: string, color: Color3?): Pill
	local merged: { [string]: any } = { BackgroundColor3 = Palette.Surface }
	for key, value in props do
		merged[key] = value
	end
	local frame = Components.card(merged)
	local outline = frame:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Thickness = PILL_OUTLINE_THICKNESS
	end

	Components.label({
		Text = icon,
		Stroke = TEXT_STROKE,
		Size = UDim2.new(0, 34, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Parent = frame,
	})
	local valueLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, -52, 1, -10),
		Position = UDim2.fromOffset(46, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or Palette.Text,
		Stroke = TEXT_STROKE,
		Parent = frame,
	})
	return {
		Instance = frame,
		setText = function(value: string)
			valueLabel.Text = value
		end,
		setVisible = function(visible: boolean)
			frame.Visible = visible
		end,
	}
end

-- A SurfaceGui that draws true.
--
-- SizingMode is the whole point of this existing. A SurfaceGui defaults to
-- FixedSize with an 800x600 canvas, which is then stretched over the part's
-- face whatever shape that face is -- so PixelsPerStud is quietly ignored and
-- everything drawn on it is scaled differently across than down. On the wheel
-- that turned a circle into an ellipse 0.875 as wide as it was tall; on the
-- garden board, whose face is 2.85:1, it stretched everything 2.14x across.
--
-- With PixelsPerStud the canvas takes the face's own proportions and a square
-- face gets a square canvas, which is what every drawing here assumes.
function Components.surface(props: { [string]: any }): SurfaceGui
	local merged: { [string]: any } = {
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		Face = Enum.NormalId.Front,
		LightInfluence = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return Components.new("SurfaceGui", merged)
end

function Components.scroller(props: { [string]: any }): ScrollingFrame
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.TextMuted,
	}
	for key, value in props do
		merged[key] = value
	end
	return Components.new("ScrollingFrame", merged)
end

export type Panel = {
	Instance: Frame,
	Content: Frame,
	setOpen: (boolean) -> (),
	isOpen: () -> boolean,
}

-- A centred pop-up panel with a title bar and close button. The X sits top
-- right on every panel, because a close button that moves is a close button
-- players have to hunt for.
function Components.panel(title: string, size: UDim2, parent: Instance): Panel
	local root: Frame = Components.card({
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Palette.Background,
		Visible = false,
		ZIndex = Components.Layer.Panel,
		Parent = parent,
	})
	local rootCorner = root:FindFirstChildOfClass("UICorner")
	if rootCorner then
		rootCorner.CornerRadius = UDim.new(0, PANEL_RADIUS)
	end
	local rootStroke = root:FindFirstChildOfClass("UIStroke")
	if rootStroke then
		rootStroke.Thickness = PANEL_OUTLINE_THICKNESS
	end
	local shade = Components.shadow(parent, size, PANEL_RADIUS, Components.Layer.Panel - 1)
	Components.padding(14).Parent = root

	-- A coloured bar rather than a bare line of text. It is the one element that
	-- says which panel this is, and a title floating on the background reads as
	-- a caption where a bar reads as a header.
	local header: Frame = Components.card({
		BackgroundColor3 = Palette.Secondary,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = root,
	})
	Components.gloss(header, RADIUS)
	Components.label({
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Text,
		Stroke = TEXT_STROKE,
		Size = UDim2.new(1, -72, 1, -12),
		Position = UDim2.fromOffset(14, 6),
		MaxTextSize = 30,
		ZIndex = 2,
		Parent = header,
	})
	-- Modal on the close button is what keeps the cursor usable: while a Modal
	-- button is on screen Roblox unlocks the mouse, and the close button is
	-- visible for exactly as long as the panel is. Without it, a panel opened
	-- while the camera has the mouse captured leaves the cursor pinned and the
	-- panel unclickable. It goes on the face rather than the wrapper because
	-- Modal is a GuiButton property, which is where `button` routes it.
	local close = Components.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(46, 40),
		BackgroundColor3 = Palette.Negative,
		Modal = true,
		ZIndex = 2,
		Parent = header,
	}, function()
		root.Visible = false
		shade.Visible = false
	end)
	close.Instance.Parent = header

	local content: Frame = Components.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		Parent = root,
	})

	return {
		Instance = root,
		Content = content,
		setOpen = function(open: boolean)
			root.Visible = open
			shade.Visible = open
		end,
		isOpen = function(): boolean
			return root.Visible
		end,
	}
end

return Components
