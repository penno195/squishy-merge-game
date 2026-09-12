--!strict
-- A yes/no dialog for anything destructive. Sits above the panels, so whatever
-- is already open stays put behind it.

local Components = require(script.Parent.Components)

local Palette = Components.Palette

-- Panels are built at the default ZIndex, so anything above that wins. With
-- Sibling behaviour the whole subtree comes with it.
local LAYER = 10

local Confirm = {}

export type Dialog = {
	ask: (message: string, highlight: string, onYes: () -> ()) -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

function Confirm.create(parent: Instance): Dialog
	local root: Frame = Components.card({
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(390, 226),
		BackgroundColor3 = Palette.Background,
		Visible = false,
		ZIndex = LAYER,
		Parent = parent,
	})
	Components.padding(18).Parent = root

	local messageLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		TextWrapped = true,
		MaxTextSize = 26,
		Parent = root,
	})
	local highlightLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 52),
		TextColor3 = Palette.Accent,
		Stroke = 2,
		MaxTextSize = 40,
		Parent = root,
	})

	-- `answer` is cleared before it runs, so a double tap can't fire it twice.
	local answer: (() -> ())? = nil

	local function close()
		answer = nil
		root.Visible = false
	end

	local yes = Components.button({
		Text = "Yes",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.48, 0, 0, 64),
		BackgroundColor3 = Palette.Positive,
		Parent = root,
	}, function()
		local callback = answer
		close()
		if callback then
			callback()
		end
	end)
	yes.Instance.Parent = root

	local no = Components.button({
		Text = "No",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.48, 0, 0, 64),
		BackgroundColor3 = Palette.Negative,
		Parent = root,
	}, close)
	no.Instance.Parent = root

	return {
		ask = function(message: string, highlight: string, onYes: () -> ())
			messageLabel.Text = message
			highlightLabel.Text = highlight
			answer = onYes
			root.Visible = true
		end,
		close = close,
		isOpen = function(): boolean
			return root.Visible
		end,
	}
end

return Confirm
