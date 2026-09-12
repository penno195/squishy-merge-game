--!strict
-- Themed UI builders. Every panel is built from these so a reskin only needs
-- to change the theme's palette and font.
--
-- The look follows Roblox's own UI guidance: one visual language reused
-- everywhere, buttons that read as physically pressable, size and colour used
-- to signal importance, and nothing on screen the player doesn't need now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme
local Palette = Theme.Palette

local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- One radius and one rhythm, so every surface in the game matches.
local RADIUS = 14
local BUTTON_RADIUS = 14
-- The lip under a button that makes it look raised. Pressing sinks onto it.
local BEVEL = 6
-- The pale outline around anything you can press or read a number off. It's
-- what gives the chunky mobile-game look its edge, and it reads against both
-- the 3D world behind a surface and a panel background.
local OUTLINE_THICKNESS = 3
local PILL_OUTLINE_THICKNESS = 2.5
-- Bold text on a saturated fill needs its own outline to stay legible.
local TEXT_STROKE = 2

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
		Components.new("UIStroke", {
			Color = Palette.Background,
			Thickness = stroke,
			Parent = label,
		})
	end
	if maxTextSize then
		Components.new("UITextSizeConstraint", { MaxTextSize = maxTextSize, Parent = label })
	end
	return label
end

-- A rounded surface used for pills, cards and panel bodies.
function Components.card(props: { [string]: any }, children: { Instance }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Palette.Surface,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame = Components.new("Frame", merged, children)
	Components.corner(RADIUS).Parent = frame
	Components.stroke(Palette.Background, 2).Parent = frame
	Components.gradient(0.1).Parent = frame
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
		elseif key ~= "Text" and key ~= "TextColor3" then
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

	face.Size = UDim2.new(1, 0, 1, -BEVEL)
	face.Position = UDim2.fromOffset(0, 0)
	local button: TextButton = Components.new("TextButton", face)
	Components.corner(BUTTON_RADIUS).Parent = button
	Components.gradient(0.22).Parent = button
	Components.stroke(Palette.Text, OUTLINE_THICKNESS).Parent = button
	button.Parent = wrapper

	-- A plain label rather than the button's own Text: a UIGradient shades the
	-- text of whatever it sits on, which would dim the caption along with the
	-- face. TextLabels don't take input, so clicks still reach the button.
	local caption: TextLabel = Components.label({
		Text = props.Text or "",
		Size = UDim2.new(1, -18, 1, -14),
		Position = UDim2.fromOffset(9, 7),
		TextColor3 = textColor,
		Stroke = TEXT_STROKE,
		-- TextScaled alone lets short labels balloon on a big button.
		MaxTextSize = 28,
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
		outline.Color = Palette.Text
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
		Parent = parent,
	})
	Components.padding(14).Parent = root

	local header: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = root,
	})
	Components.label({
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		Size = UDim2.new(1, -56, 1, 0),
		MaxTextSize = 34,
		Parent = header,
	})
	local close = Components.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Palette.Negative,
		Parent = header,
	}, function()
		root.Visible = false
	end)
	close.Instance.Parent = header

	local content: Frame = Components.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		Parent = root,
	})

	return {
		Instance = root,
		Content = content,
		setOpen = function(open: boolean)
			root.Visible = open
		end,
		isOpen = function(): boolean
			return root.Visible
		end,
	}
end

return Components
