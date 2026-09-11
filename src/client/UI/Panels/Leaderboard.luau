--!strict
-- Global leaderboards, refreshed by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local Palette = Components.Palette
local Theme = Config.Theme

local Leaderboard = {}

function Leaderboard.create(parent: Instance)
	local panel = Components.panel("Leaderboards", UDim2.fromOffset(560, 440), parent)

	local boards = {
		{ Stat = "TotalEarned", Title = `Most {Theme.Text.Currency} Earned` },
		{ Stat = "Rebirths", Title = `Most {Theme.Text.Rebirth}s` },
	}
	local columns = {}

	for index, board in boards do
		local column = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -6, 1, 0),
			Position = UDim2.new(0.5 * (index - 1), if index == 1 then 0 else 6, 0, 0),
			Parent = panel.Content,
		})
		Components.label({
			Text = board.Title,
			Size = UDim2.new(1, 0, 0, 28),
			TextColor3 = Palette.Accent,
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
					Size = UDim2.new(0.6, -8, 1, -6),
					Position = UDim2.fromOffset(8, 3),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = card,
				})
				Components.label({
					Text = Format.number(entry.Value),
					Size = UDim2.new(0.4, -8, 1, -6),
					Position = UDim2.new(0.6, 0, 0, 3),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Palette.TextMuted,
					Parent = card,
				})
			end
		end
	end

	Net.event("Leaderboard").OnClientEvent:Connect(render)
	render({})

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(_snapshot: { [string]: any }) end,
	}
end

return Leaderboard
