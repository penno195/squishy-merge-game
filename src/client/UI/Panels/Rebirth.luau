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
	local panel = Components.panel(Theme.Text.Rebirth, UDim2.fromOffset(460, 390), parent)

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

	-- The rung half of the gate. Cash is on the button, where the price always
	-- was; this is the requirement people won't otherwise see coming.
	local requirement = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 40),
		Position = UDim2.fromOffset(12, 152),
		TextColor3 = Palette.TextMuted,
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
		local requiredTier = Economy.rebirthTier(data.Rebirths)
		local bestTier = Economy.bestOwnedTier(data)
		local tierMet = Economy.rebirthTierMet(data)
		requirement.Text = if tierMet
			then `Needs a {Config.Units[requiredTier].Name} — you have one ✓`
			else `Needs a {Config.Units[requiredTier].Name} — best so far: {if bestTier > 0
				then Config.Units[bestTier].Name
				else "nothing"}`
		requirement.TextColor3 = if tierMet then Palette.Positive else Palette.Negative

		button.setText(`{Theme.Text.Rebirth} — {Format.number(cost)} {Theme.Text.Currency}`)
		button.setEnabled(Economy.canRebirth(data))
	end

	blurb.TextYAlignment = Enum.TextYAlignment.Top

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Rebirth
