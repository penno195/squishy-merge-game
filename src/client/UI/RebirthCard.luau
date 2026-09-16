--!strict
-- Rebirth, as a tile on the garden board: what you have, what the next one
-- gives, what it still needs, and the button. It lives on the board rather than
-- behind a menu button because it's the one thing the whole garden is working
-- towards, and the board is what a player is looking at while they work.
--
-- A rebirth throws away the garden, so the button takes two presses: the first
-- arms it and says so, the second fires. A board is clicked at from across the
-- garden by people also clicking on the units in front of it, which is exactly
-- where a single stray press would cost someone an hour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

-- How long the armed button waits for its second press.
local ARM_SECONDS = 3
-- The price on the button, in the board surface's own pixels. Matches the
-- upgrade tiles beside it, so the two read at the same distance.
local BOARD_PRICE_TEXT = 96

local RebirthCard = {}

export type Card = {
	update: ({ [string]: any }) -> (),
}

function RebirthCard.create(parent: Instance): Card
	local card = Components.card({
		Size = UDim2.fromScale(1, 1),
		Pattern = true,
		BackgroundColor3 = Palette.Surface,
		Parent = parent,
	})
	Components.padding(14).Parent = card

	Components.label({
		Text = "🔁",
		Size = UDim2.fromScale(0.2, 0.13),
		Parent = card,
	})
	Components.label({
		Text = Theme.Text.Rebirth,
		Size = UDim2.fromScale(0.78, 0.13),
		Position = UDim2.fromScale(0.22, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Primary,
		Stroke = 2,
		Parent = card,
	})
	Components.label({
		Text = `Reset your {Theme.Text.Currency}, {Theme.Text.UnitPlural} and upgrades for a permanent boost`,
		Size = UDim2.fromScale(1, 0.13),
		Position = UDim2.fromScale(0, 0.15),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		Stroke = 2,
		Parent = card,
	})
	local current = Components.label({
		Text = "",
		Size = UDim2.fromScale(1, 0.09),
		Position = UDim2.fromScale(0, 0.31),
		TextColor3 = Palette.Text,
		Stroke = 2,
		Parent = card,
	})
	local nextLabel = Components.label({
		Text = "",
		Size = UDim2.fromScale(1, 0.09),
		Position = UDim2.fromScale(0, 0.41),
		TextColor3 = Palette.Accent,
		Stroke = 2,
		Parent = card,
	})
	-- The rung half of the gate. Cash is on the button, where every price on
	-- the board is; this is the requirement people won't otherwise see coming.
	local requirement = Components.label({
		Text = "",
		Size = UDim2.fromScale(1, 0.14),
		Position = UDim2.fromScale(0, 0.52),
		TextWrapped = true,
		Stroke = 2,
		Parent = card,
	})

	local latest: { [string]: any }? = nil
	local armedUntil = 0

	local button: Components.Button
	local function render()
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		current.Text =
			`{Theme.Text.Rebirth}s: {data.Rebirths}  ·  x{Economy.rebirthMultiplier(data.Rebirths)} {Theme.Text.Currency}`
		nextLabel.Text = `Next: x{Economy.rebirthMultiplier(data.Rebirths + 1)} {Theme.Text.Currency}`

		local requiredTier = Economy.rebirthTier(data.Rebirths)
		local bestTier = Economy.bestOwnedTier(data)
		local tierMet = Economy.rebirthTierMet(data)
		requirement.Text = if tierMet
			then `Needs a {Config.Units[requiredTier].Name} — you have one ✓`
			else `Needs a {Config.Units[requiredTier].Name} — best so far: {if bestTier > 0
				then Config.Units[bestTier].Name
				else "nothing"}`
		requirement.TextColor3 = if tierMet then Palette.Positive else Palette.Negative

		local canRebirth = Economy.canRebirth(data)
		if canRebirth and os.clock() < armedUntil then
			button.setIcon("")
			button.setText("Press again")
			button.setColor(Palette.Negative)
		else
			button.setIcon(Theme.Icons.Currency or "")
			button.setText(Format.number(Economy.rebirthCost(data.Rebirths)))
			button.setColor(Palette.Primary)
		end
		button.setEnabled(canRebirth)
	end

	button = Components.button({
		Text = "",
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.7),
		BackgroundColor3 = Palette.Primary,
		MaxTextSize = BOARD_PRICE_TEXT,
		Parent = card,
	}, function()
		if os.clock() < armedUntil then
			armedUntil = 0
			Sound.play(Theme.Sounds.Rebirth)
			Net.event("Rebirth"):FireServer()
		else
			armedUntil = os.clock() + ARM_SECONDS
			Sound.play(Theme.Sounds.Purchase)
			task.delay(ARM_SECONDS, render)
		end
		render()
	end)

	return {
		update = function(snapshot: { [string]: any })
			latest = snapshot
			render()
		end,
	}
end

return RebirthCard
