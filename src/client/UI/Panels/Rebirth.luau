--!strict
-- Rebirth: trade everything for a permanent multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local Rebirth = {}

function Rebirth.create(parent: Instance)
	local panel = Components.panel(Theme.Text.Rebirth, UDim2.fromOffset(460, 340), parent)

	local blurb = Components.label({
		Text = `Reset your {Theme.Text.Currency}, {Theme.Text.UnitPlural} and upgrades for a permanent boost.`,
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.fromOffset(12, 0),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 20,
		Parent = panel.Content,
	})

	local current = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 64),
		Parent = panel.Content,
	})
	local next_ = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 108),
		TextColor3 = Palette.Accent,
		Parent = panel.Content,
	})

	local button = Components.button({
		Text = Theme.Text.Rebirth,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(260, 64),
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Rebirth)
		Net.event("Rebirth"):FireServer()
	end)

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local cost = Economy.rebirthCost(data.Rebirths)
		current.Text =
			`{Theme.Text.Rebirth}s: {data.Rebirths}  ·  x{Economy.rebirthMultiplier(data.Rebirths)} {Theme.Text.Currency}`
		next_.Text = `Next: x{Economy.rebirthMultiplier(data.Rebirths + 1)} {Theme.Text.Currency}`
		button.setText(`{Theme.Text.Rebirth} — {Format.number(cost)} {Theme.Text.Currency}`)
		button.setEnabled(data.Cash >= cost)
	end

	blurb.TextYAlignment = Enum.TextYAlignment.Top

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Rebirth
