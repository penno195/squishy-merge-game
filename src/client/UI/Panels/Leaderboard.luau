--!strict
-- Global leaderboards, refreshed by the server, and last week's prize.
--
-- Three boards: two lifetime halls of fame and the weekly race. The race is the
-- one that pays, so it leads, and the prize strip above them all is what makes
-- the difference between the three visible -- a board with a prize on it and a
-- board without look identical otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClaimList = require(script.Parent.Parent.ClaimList)
local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

-- The prize strip, and the gap under it before the columns start.
local STRIP_HEIGHT = 86

local Leaderboard = {}

-- 1st, 2nd, 3rd. Teens are all "th", which a lookup on the last digit alone
-- gets wrong -- the same rule the server uses for its toast.
local SUFFIXES = { "st", "nd", "rd" }

local function ordinal(rank: number): string
	local suffix = if rank % 100 >= 11 and rank % 100 <= 13 then "th" else SUFFIXES[rank % 10] or "th"
	return `{rank}{suffix}`
end

function Leaderboard.create(parent: Instance)
	local panel = Components.panel("Leaderboards", UDim2.fromOffset(700, 470), parent)

	-- Two strips in the same place, one shown at a time. A prize that's actually
	-- waiting gets the claim row; everything else gets a line of text, because a
	-- Claim button over "no prize this time" is a button that does nothing and
	-- asks to be pressed anyway.
	local prize = ClaimList.create({
		Size = UDim2.new(1, 0, 0, STRIP_HEIGHT - 8),
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("ClaimPrize"):FireServer()
	end)

	local infoCard = Components.card({
		Size = UDim2.new(1, -12, 0, STRIP_HEIGHT - 16),
		Parent = panel.Content,
	})
	local infoTitle = Components.label({
		Text = "",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 19,
		Parent = infoCard,
	})
	local infoDetail = Components.label({
		Text = "",
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.TextMuted,
		TextScaled = false,
		TextSize = 16,
		Parent = infoCard,
	})

	local function showInfo(title: string, detail: string)
		infoCard.Visible = true
		prize.Instance.Visible = false
		infoTitle.Text = title
		infoDetail.Text = detail
	end

	local boards = {
		{ Stat = "Weekly", Title = "This Week's Race" },
		{ Stat = "TotalEarned", Title = `Most {Theme.Text.Currency} Earned` },
		{ Stat = "Rebirths", Title = `Most {Theme.Text.Rebirth}s` },
	}
	local columns = {}

	for index, board in boards do
		local column = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / #boards, -6, 1, -STRIP_HEIGHT),
			Position = UDim2.new((index - 1) / #boards, if index == 1 then 0 else 6, 0, STRIP_HEIGHT),
			Parent = panel.Content,
		})
		Components.label({
			Text = board.Title,
			Size = UDim2.new(1, 0, 0, 28),
			-- The race is the one worth climbing, so it's the one in the bright
			-- colour; the halls of fame are a shade back from it.
			TextColor3 = if index == 1 then Palette.Positive else Palette.Accent,
			TextScaled = false,
			TextSize = 18,
			Parent = column,
		})
		local list = Components.scroller({
			Size = UDim2.new(1, 0, 1, -34),
			Position = UDim2.fromOffset(0, 34),
			Parent = column,
		})
		Components.listLayout({ Padding = UDim.new(0, 4) }).Parent = list
		columns[board.Stat] = list
	end

	local function render(data: { [string]: { { Name: string, Value: number } } })
		for stat, list in columns do
			list:ClearAllChildren()
			Components.listLayout({ Padding = UDim.new(0, 4) }).Parent = list
			local entries: { { Name: string, Value: number } } = data[stat] or {}
			if #entries == 0 then
				Components.label({
					Text = "No scores yet",
					Size = UDim2.new(1, -8, 0, 28),
					TextColor3 = Palette.TextMuted,
					Parent = list,
				})
			end
			for rank, entry in entries do
				local card = Components.card({ Size = UDim2.new(1, -8, 0, 30), LayoutOrder = rank, Parent = list })
				Components.label({
					Text = `{rank}. {entry.Name}`,
					Size = UDim2.new(0.62, -8, 1, -6),
					Position = UDim2.fromOffset(8, 3),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = false,
					TextSize = 15,
					Parent = card,
				})
				Components.label({
					Text = Format.number(entry.Value),
					Size = UDim2.new(0.38, -8, 1, -6),
					Position = UDim2.new(0.62, 0, 0, 3),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Palette.TextMuted,
					TextScaled = false,
					TextSize = 15,
					Parent = card,
				})
			end
		end
	end

	-- The prize row says one of four things, and which one it says is the whole
	-- point of the strip: the results aren't in, you won this much, you placed
	-- but not high enough, or you've already taken it.
	local places = Economy.prizePlaces()

	local function renderPrize(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local week = snapshot.PrizeWeek
		if not week then
			showInfo("Weekly prize", `Last week's results aren't in yet — top {places} win Gems.`)
			return
		end

		local rank = snapshot.PrizeRank or 0
		local gems = snapshot.PrizeGems or 0
		if gems > 0 and Economy.prizeUnclaimed(data, week) then
			infoCard.Visible = false
			prize.Instance.Visible = true
			prize.render({
				{
					Text = `🏆 {ordinal(rank)} place last week!`,
					Progress = 1,
					Target = 1,
					ProgressText = "Ready to claim",
					Reward = `{gems} Gems`,
					Claimed = false,
				},
			})
		elseif gems > 0 then
			showInfo(`🏆 {ordinal(rank)} place last week`, `{gems} Gems claimed. The race has already started again.`)
		elseif rank > 0 then
			showInfo(`You finished {ordinal(rank)} last week`, `Only the top {places} win Gems — keep climbing.`)
		else
			showInfo("Weekly prize", `Finish in the top {places} of the race to win Gems.`)
		end
	end

	Net.event("Leaderboard").OnClientEvent:Connect(render)
	render({})

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = renderPrize,
	}
end

return Leaderboard
