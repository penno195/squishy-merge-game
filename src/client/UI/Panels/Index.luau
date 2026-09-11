--!strict
-- Collection index: every unit in the theme, with undiscovered ones hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local Index = {}

function Index.create(parent: Instance)
	local panel = Components.panel(`{Theme.Text.Unit} Index`, UDim2.fromOffset(560, 440), parent)

	local progress = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 0),
		TextColor3 = Palette.Accent,
		Parent = panel.Content,
	})

	local grid = Components.scroller({
		Size = UDim2.new(1, 0, 1, -36),
		Position = UDim2.fromOffset(0, 36),
		Parent = panel.Content,
	})
	Components.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(124, 116),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cells = {}
	for tier, unit in Theme.Units do
		local card = Components.card({ LayoutOrder = tier, Parent = grid })
		local swatch = Components.new("Frame", {
			BackgroundColor3 = unit.Color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(48, 48),
			Position = UDim2.new(0.5, -24, 0, 8),
			Parent = card,
		})
		Components.corner(24).Parent = swatch
		local name = Components.label({
			Text = unit.Name,
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.fromOffset(4, 60),
			TextScaled = false,
			TextSize = 16,
			Parent = card,
		})
		local income = Components.label({
			Text = "",
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 86),
			TextColor3 = Palette.TextMuted,
			TextScaled = false,
			TextSize = 14,
			Parent = card,
		})
		cells[tier] = { Swatch = swatch, Name = name, Income = income }
	end

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		progress.Text = `Discovered {data.HighestTier} / {Config.MaxTier}`
		for tier, cell in cells do
			local discovered = tier <= data.HighestTier
			cell.Swatch.BackgroundColor3 = if discovered then Theme.Units[tier].Color else Palette.Background
			cell.Name.Text = if discovered then Theme.Units[tier].Name else "???"
			cell.Income.Text = if discovered
				then `{Format.number(Economy.tierIncome(tier))} {Theme.Text.Currency}/s`
				else ""
		end
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Index
