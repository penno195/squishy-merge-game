--!strict
-- Collection index: every unit in the theme, with undiscovered ones hidden.
-- The sparkles sit on the end of the same list, since they're units too -- but
-- they're only ever found by crafting one, so they're counted separately.

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
	for tier, unit in Config.Units do
		local card = Components.card({ LayoutOrder = tier, Pattern = true, Parent = grid })
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
		local made = 0
		for _, sparkle in Config.Sparkles do
			if (data.Sparkles[sparkle.Id] or 0) > 0 then
				made += 1
			end
		end
		local variantsFound = 0
		local variantsTotal = #Config.Variants * Config.MaxTier
		for index = Config.VariantBase + 1, Config.VariantBase + variantsTotal do
			if data.Discovered[tostring(index)] then
				variantsFound += 1
			end
		end

		local parts = { `Discovered {data.HighestTier} / {Config.MaxTier}` }
		if #Config.Sparkles > 0 then
			table.insert(parts, `{Theme.Text.SparklePlural} {made} / {#Config.Sparkles}`)
		end
		if variantsTotal > 0 then
			table.insert(parts, `Variants {variantsFound} / {variantsTotal}`)
		end
		progress.Text = table.concat(parts, "  ·  ")

		for index, cell in cells do
			local unit = Config.Units[index]
			local sparkle = Economy.sparkleAt(index)
			local count = if sparkle then data.Sparkles[sparkle.Id] or 0 else 0
			-- The ladder is remembered as a high-water mark and the rest one by
			-- one, because everything off the ladder can be found out of order.
			local discovered = if sparkle
				then count > 0
				elseif Economy.variantOf(index) > 0 then data.Discovered[tostring(index)] == true
				else index <= data.HighestTier

			cell.Swatch.BackgroundColor3 = if discovered then unit.Color else Palette.Background
			cell.Name.Text = if discovered then unit.Name else "???"
			if not discovered then
				cell.Income.Text = ""
			elseif sparkle then
				-- What a sparkle is really worth is the permanent cut it adds,
				-- so that's what the card leads with.
				cell.Income.Text = `+{math.floor(sparkle.Bonus * 100)}% forever  ·  x{count}`
			else
				cell.Income.Text = `{Format.number(Economy.tierIncome(index))} {Theme.Text.Currency}/s`
			end
			cell.Income.TextColor3 = if sparkle and discovered then Palette.Accent else Palette.TextMuted
		end
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Index
