--!strict
-- Themed UI builders. Every panel is built from these so a reskin only needs
-- to change the theme's palette and font.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme
local Palette = Theme.Palette

local HOVER_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Components = {}

Components.Palette = Palette
Components.Font = Theme.Font

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

function Components.label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Palette.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in props do
		merged[key] = value
	end
	return Components.new("TextLabel", merged)
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
	Components.corner(12).Parent = frame
	Components.stroke(Palette.Background, 2).Parent = frame
	return frame
end

export type Button = {
	Instance: TextButton,
	setText: (string) -> (),
	setEnabled: (boolean) -> (),
}

function Components.button(props: { [string]: any }, onClick: () -> ()): Button
	local color = props.BackgroundColor3 or Palette.Primary
	local merged: { [string]: any } = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Theme.Font,
		TextColor3 = Palette.Text,
		TextScaled = true,
		Text = props.Text or "",
	}
	for key, value in props do
		merged[key] = value
	end

	local button: TextButton = Components.new("TextButton", merged)
	Components.corner(12).Parent = button
	Components.stroke(Palette.Background, 2).Parent = button
	Components.padding(6).Parent = button

	local enabled = true
	local function tweenTo(target: Color3)
		TweenService:Create(button, HOVER_TWEEN, { BackgroundColor3 = target }):Play()
	end

	button.MouseEnter:Connect(function()
		if enabled then
			tweenTo(color:Lerp(Color3.new(1, 1, 1), 0.2))
		end
	end)
	button.MouseLeave:Connect(function()
		if enabled then
			tweenTo(color)
		end
	end)
	button.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)

	return {
		Instance = button,
		setText = function(text: string)
			button.Text = text
		end,
		setEnabled = function(value: boolean)
			enabled = value
			button.AutoLocalize = true
			tweenTo(if value then color else Palette.Surface)
			button.TextTransparency = if value then 0 else 0.35
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
	Components.corner(12).Parent = fill
	return {
		Instance = container,
		setProgress = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
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

-- A centred pop-up panel with a title bar and close button.
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
	Components.padding(12).Parent = root

	local header: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = root,
	})
	Components.label({
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -48, 1, 0),
		Parent = header,
	})
	local close = Components.button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Palette.Negative,
		Parent = header,
	}, function()
		root.Visible = false
	end)
	close.Instance.Parent = header

	local content: Frame = Components.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
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
