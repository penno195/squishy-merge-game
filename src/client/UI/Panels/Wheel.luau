--!strict
-- The prize wheel panel. The wheel is the panel: odds are written on the
-- segments rather than listed beside them, so there's nothing to read off to
-- one side. The same dial is drawn on the wheel standing out in the hub, and
-- both turn together.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Reveal = require(script.Parent.Parent.Reveal)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)
local WheelController = require(script.Parent.Parent.Parent.Controllers.WheelController)
local WheelFace = require(script.Parent.Parent.WheelFace)

local Palette = Components.Palette
local Prizes = Config.Balance.Wheel.Prizes
local Theme = Config.Theme

local WHEEL_SIZE = 330

local Wheel = {}

function Wheel.create(parent: Instance)
	-- Tall enough for the hint under the buttons: the content runs to 552, and
	-- the panel owes it that plus the title bar and its own padding.
	local panel = Components.panel("Prize Wheel", UDim2.fromOffset(430, 640), parent)

	local face = WheelFace.create({
		Name = "Dial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE),
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		WheelController.requestSpin()
	end)
	WheelController.register(face)

	local resultLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, -16, 0, 46),
		Position = UDim2.fromOffset(8, WHEEL_SIZE + 6),
		TextColor3 = Palette.Accent,
		TextWrapped = true,
		Stroke = 2,
		MaxTextSize = 22,
		Parent = panel.Content,
	})

	-- Spin shares its row with the auto toggle, which only appears once there's
	-- more than one spin to spend; alone, Spin takes the whole row back.
	local spinButton = Components.button({
		Text = "Spin!",
		Position = UDim2.fromOffset(12, WHEEL_SIZE + 58),
		Size = UDim2.new(1, -24, 0, 66),
		BackgroundColor3 = Palette.Positive,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		WheelController.requestSpin()
	end)

	-- Auto takes a third of the row from the right, Spin two thirds from the
	-- left, and the twelve studs each of them gives up in the middle is the gap
	-- between them: 12 + (0.66W - 24) leaves Spin's edge at 0.66W - 12, and
	-- W - 12 - (0.34W - 12) puts Auto's at 0.66W. At the sizes these were,
	-- both edges landed on the same pixel -- and Spin's badge is built to hang
	-- six past its own corner, so the count sat on top of Auto.
	local autoButton = Components.button({
		Text = "Auto",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, WHEEL_SIZE + 58),
		Size = UDim2.new(0.34, -12, 0, 66),
		BackgroundColor3 = Palette.Secondary,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		WheelController.setAutoSpin(not WheelController.isAutoSpinning())
	end)

	local buyButton = Components.button({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WHEEL_SIZE + 132),
		Size = UDim2.new(1, -24, 0, 58),
		BackgroundColor3 = Palette.Secondary,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("BuySpin"):FireServer()
	end)
	buyButton.setIcon(Theme.Icons.Gems or "")

	local hintLabel = Components.label({
		Text = "One free spin every day.",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, WHEEL_SIZE + 198),
		Size = UDim2.new(1, -24, 0, 24),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 18,
		Parent = panel.Content,
	})
	hintLabel.Name = "Hint"

	local latest: { [string]: any }? = nil

	local function render()
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		local spins = snapshot.SpinsAvailable or Economy.spinsAvailable(data, os.time())
		local ready = spins > 0 and not WheelController.isSpinning()
		local auto = WheelController.isAutoSpinning()

		-- While auto is running the Spin button would only race it, so it stands
		-- down; the toggle is how it stops.
		spinButton.setEnabled(ready and not auto)
		local showAuto = spins > 1 or auto
		autoButton.Instance.Visible = showAuto
		spinButton.Instance.Size = if showAuto then UDim2.new(0.66, -24, 0, 66) else UDim2.new(1, -24, 0, 66)
		autoButton.setText(if auto then "Stop" else "Auto")
		autoButton.setColor(if auto then Palette.Negative else Palette.Secondary)
		-- The count rides on the button, so it's read at the moment of pressing.
		spinButton.setBadge(if spins > 0 then `x{spins}` else nil)

		local cost = Economy.spinCost()
		buyButton.setText(`Buy a spin — {cost}`)
		buyButton.setEnabled(data.Gems >= cost)
	end

	WheelController.onAutoChanged(render)

	WheelController.onResult(function(index, description)
		local prize = Prizes[index]
		resultLabel.Text = if description ~= "" then `{prize.Label}!  You won {description}.` else `{prize.Label}!`
		-- The line in the panel is for someone who is still looking at the
		-- wheel; the card is for everyone else, since a spin can be set running
		-- and left to finish while the panel is shut.
		Reveal.prize(prize.Label, description)
		render()
	end)

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			latest = snapshot
			render()
		end,
	}
end

return Wheel
