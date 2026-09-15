--!strict
-- Daily reward streak: seven days, reset if a day is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Rewards = Config.Balance.DailyRewards
local Theme = Config.Theme

local Daily = {}

function Daily.create(parent: Instance)
	-- Tall enough for the row of cards, the status line and the claim button with
	-- air between them: 150 of cards, 32 of status and 56 of button don't fit in
	-- the 238 of content a 320-tall panel leaves.
	local panel = Components.panel("Daily Rewards", UDim2.fromOffset(560, 360), parent)

	local row = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 150),
		Parent = panel.Content,
	})
	Components.listLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent =
		row

	local cards = {}
	for day = 1, #Rewards do
		local card =
			Components.card({ Size = UDim2.fromOffset(72, 130), LayoutOrder = day, Pattern = true, Parent = row })
		Components.label({
			Text = `Day {day}`,
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.fromOffset(4, 6),
			Parent = card,
		})
		local reward = Components.label({
			Text = "",
			Size = UDim2.new(1, -8, 0, 80),
			Position = UDim2.fromOffset(4, 34),
			TextColor3 = Palette.TextMuted,
			TextWrapped = true,
			TextScaled = false,
			TextSize = 16,
			Parent = card,
		})
		cards[day] = { Card = card, Reward = reward }
	end

	local status = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 32),
		Position = UDim2.fromOffset(12, 156),
		TextColor3 = Palette.TextMuted,
		Parent = panel.Content,
	})

	local button = Components.button({
		Text = "Claim",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(240, 56),
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("ClaimDaily"):FireServer()
	end)

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local income = snapshot.IncomePerSecond or 0
		local available, streak = Economy.dailyStatus(data, snapshot.Now)

		for day, entry in cards do
			local reward = Rewards[day]
			local parts = {}
			if reward.IncomeMinutes or reward.MinCash then
				local amount = Economy.incomeReward(income, reward.IncomeMinutes or 0, reward.MinCash or 0)
				table.insert(parts, `{Format.number(amount)} {Theme.Text.Currency}`)
			end
			if reward.UnitTierBonus then
				table.insert(parts, `+{Theme.Text.Unit}`)
			end
			entry.Reward.Text = table.concat(parts, "\n")

			local isNext = available and day == streak
			local claimed = day <= data.Daily.Streak and not isNext
			entry.Card.BackgroundColor3 = if isNext
				then Palette.Primary
				elseif claimed then Palette.Background
				else Palette.Surface
		end

		status.Text = if available
			then `Day {streak} is ready to claim!`
			else `Streak: {data.Daily.Streak} days — come back tomorrow.`
		button.setEnabled(available)
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Daily
