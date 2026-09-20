--!strict
-- The upgrade entries, and the two ways they're drawn: tiles stacked in columns
-- on the garden board, and rows in the Upgrades panel. Both read the same spec and the same
-- update function, so the two can never drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

-- The gem-bought timed effects. None is an upgrade -- no levels, no cash,
-- nothing to max out -- but they sit alongside them on the board and in the
-- panel, so they're described here in the same shape.
local BOOST_ID = "Boost"
local LUCK_ID = "Luck"
local AUTO_MERGE_ID = "AutoMerge"

-- Cap on the price drawn across a board tile, in that surface's own pixels. A
-- stacked tile's button is about 130 of them tall, so this lets the price fill
-- it rather than sit at the size a button on a phone screen would use.
local BOARD_PRICE_TEXT = 96

type Timed = {
	Name: string,
	Icon: string,
	Remote: string,
	cost: () -> number,
	remaining: (Types.PlayerData) -> number,
}

local TIMED: { [string]: Timed } = {
	[BOOST_ID] = {
		Name = "Earning Boost",
		Icon = "Boost",
		Remote = "BuyBoost",
		cost = Economy.boostCost,
		remaining = Economy.boostRemaining,
	},
	[LUCK_ID] = {
		Name = "Lucky Charm",
		Icon = "Luck",
		Remote = "BuyLuck",
		cost = Economy.luckCost,
		remaining = Economy.luckRemaining,
	},
	[AUTO_MERGE_ID] = {
		Name = "Auto Merge",
		Icon = "AutoMerge",
		Remote = "BuyAutoMerge",
		cost = Economy.autoMergeCost,
		remaining = Economy.autoMergeRemaining,
	},
}

-- Timed entries a pass makes permanent, keyed by entry id to the pass. An owner's
-- tile stops selling it: there is no clock to show and nothing left to buy.
local PERMANENT_PASS: { [string]: string } = {
	[LUCK_ID] = "LuckCharm",
	[AUTO_MERGE_ID] = "AutoMerge",
}

local UpgradeList = {}

export type Entry = {
	Id: string,
	Name: string,
	Icon: string,
}

export type List = {
	update: ({ [string]: any }) -> (),
}

local function icon(id: string): string
	return (Theme.Icons :: { [string]: string? })[id] or ""
end

local function entryFor(id: string): Entry
	local timed = TIMED[id]
	if timed then
		return { Id = id, Name = timed.Name, Icon = icon(timed.Icon) }
	end
	return { Id = id, Name = Economy.getUpgrade(id).Name, Icon = icon(id) }
end

-- What the garden board shows: one column per list, top to bottom, left to
-- right. Grouped by what they're for -- the drops, the garden, the gem-bought
-- effects -- so a column reads as one decision. The board adds the rebirth
-- tile after these.
UpgradeList.BoardColumns = {
	{ "SpawnTier", "SpawnSpeed" },
	{ "GardenSpace", "Income" },
	{ BOOST_ID, LUCK_ID, AUTO_MERGE_ID },
}

function UpgradeList.allIds(): { string }
	local ids = {}
	for _, upgrade in Config.Balance.Upgrades do
		table.insert(ids, upgrade.Id)
	end
	table.insert(ids, BOOST_ID)
	table.insert(ids, LUCK_ID)
	table.insert(ids, AUTO_MERGE_ID)
	return ids
end

-- What the entry does right now, in the theme's own words.
local function describe(id: string, data: Types.PlayerData, passes: { [string]: boolean }): string
	if id == "SpawnSpeed" then
		local passMultiplier = if passes.FastSpawn then Config.Balance.Monetisation.FastSpawnMultiplier else 1
		local interval = Economy.dropInterval(data, passMultiplier)
		return `A {Theme.Text.Unit} drops about every {string.format("%.1f", interval)}s`
	elseif id == "SpawnTier" then
		return `Drops up to {Config.Units[Economy.dropTier(data)].Name}`
	elseif id == "GardenSpace" then
		local spaces = Economy.gardenPassSpaces(passes.BiggerGarden)
		return `Garden holds {Economy.gardenCapacity(data, spaces)} {Theme.Text.UnitPlural}`
	elseif id == LUCK_ID then
		local _, top = Economy.dropTierRange(data)
		local passBias = Economy.luckPassBias(passes.LuckCharm)
		-- The pass is a charm that never runs out, so the tile stops offering to
		-- sell one: there is no clock to show and nothing left to buy.
		if passBias then
			local chance = math.floor(Economy.topTierChance(data, passBias) * 100 + 0.5)
			return `Always on — {chance}% {Config.Units[top].Name}`
		end
		local remaining = Economy.luckRemaining(data)
		if remaining > 0 then
			local chance = math.floor(Economy.topTierChance(data) * 100 + 0.5)
			return `{Format.time(remaining)} left  ·  {chance}% {Config.Units[top].Name}`
		end
		-- Idle, the tile quotes what buying one would do rather than the odds
		-- the player already has, which are the base weights.
		local lucky = math.floor(Economy.topTierChance(data, Config.Balance.Luck.Bias) * 100 + 0.5)
		return `{lucky}% of drops {Config.Units[top].Name} for {Format.time(Economy.luckSeconds())}`
	elseif id == "Income" then
		local upgrade = Economy.getUpgrade("Income")
		local multiplier = 1 + Economy.upgradeLevel(data, "Income") * upgrade.PerLevel
		return `Earning x{string.format("%.2f", multiplier)} {Theme.Text.Currency}`
	elseif id == BOOST_ID then
		local remaining = Economy.boostRemaining(data)
		if remaining > 0 then
			return `{Format.time(remaining)} left`
		end
		local boost = Config.Balance.Boost
		return `x{boost.Multiplier} {Theme.Text.Currency} for {Format.time(boost.Seconds)}`
	elseif id == AUTO_MERGE_ID then
		if passes.AutoMerge then
			return `Pairs merge themselves, always`
		end
		local remaining = Economy.autoMergeRemaining(data)
		if remaining > 0 then
			return `{Format.time(remaining)} left`
		end
		return `Pairs merge themselves for {Format.time(Economy.autoMergeSeconds())}`
	end
	return ""
end

-- The line above the button: an upgrade's level, or whether the timed thing is
-- running.
local function statusOf(id: string, data: Types.PlayerData, passes: { [string]: boolean }): string
	local timed = TIMED[id]
	if timed then
		local pass = PERMANENT_PASS[id]
		if pass and passes[pass] then
			return "OWNED"
		end
		return if timed.remaining(data) > 0 then "RUNNING" else "Ready"
	end
	return `Level {Economy.upgradeLevel(data, id)} / {Economy.upgradeMaxLevel(id)}`
end

type Row = {
	Status: TextLabel,
	Detail: TextLabel,
	Button: Components.Button,
}

local function buy(id: string)
	Sound.play(Theme.Sounds.Purchase)
	local timed = TIMED[id]
	if timed then
		Net.event(timed.Remote):FireServer()
	else
		Net.event("BuyUpgrade"):FireServer(id)
	end
end

-- Drives both layouts. `rows` maps entry id to the three things that change.
local function makeUpdater(rows: { [string]: Row }): ({ [string]: any }) -> ()
	return function(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local passes = snapshot.Passes or {}
		for id, row in rows do
			row.Status.Text = statusOf(id, data, passes)
			row.Detail.Text = describe(id, data, passes)

			local timed = TIMED[id]
			if timed then
				local cost = timed.cost()
				-- A pass owner's version never runs out, so the tile stops asking
				-- for gems. The server refuses the sale too; this is so the button
				-- doesn't invite one.
				local pass = PERMANENT_PASS[id]
				if pass and passes[pass] then
					row.Button.setText("Permanent")
					row.Button.setEnabled(false)
				else
					row.Button.setText(`{cost} Gems`)
					row.Button.setEnabled(data.Gems >= cost)
				end
			else
				local level = Economy.upgradeLevel(data, id)
				if level >= Economy.upgradeMaxLevel(id) then
					row.Button.setText("MAXED")
					row.Button.setEnabled(false)
				else
					local cost = Economy.upgradeCost(id, level)
					row.Button.setText(Format.number(cost))
					row.Button.setEnabled(data.Cash >= cost)
				end
			end
		end
	end
end

-- The timed effects count down between snapshots, so re-render once a second.
local function keepTimersLive(host: Instance, update: ({ [string]: any }) -> (), latest: () -> { [string]: any }?)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(delta)
		if not host.Parent then
			connection:Disconnect()
			return
		end
		elapsed += delta
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local snapshot = latest()
		if snapshot then
			update(snapshot)
		end
	end)
end

-- Tiles stacked one above another, filling one column of the garden board.
-- Each is wider than it is tall, so the name sits beside its icon rather than
-- under it and the price gets the whole bottom of the tile.
function UpgradeList.stack(parent: Instance, ids: { string }): List
	local column: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	local gap = 12
	Components.listLayout({ Padding = UDim.new(0, gap) }).Parent = column

	local rows: { [string]: Row } = {}

	for order, id in ids do
		local entry = entryFor(id)
		local isTimed = TIMED[id] ~= nil
		local card = Components.card({
			-- Each tile gives up its share of the gaps between them.
			Size = UDim2.new(1, 0, 1 / #ids, -gap * (#ids - 1) / #ids),
			LayoutOrder = order,
			Pattern = true,
			BackgroundColor3 = if isTimed then Palette.Secondary else Palette.Surface,
			Parent = column,
		})
		Components.padding(14).Parent = card

		Components.label({
			Text = entry.Icon,
			Size = UDim2.fromScale(0.16, 0.26),
			Parent = card,
		})
		Components.label({
			Text = entry.Name,
			Size = UDim2.fromScale(0.82, 0.26),
			Position = UDim2.fromScale(0.18, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Text,
			Stroke = 2,
			Parent = card,
		})
		local status = Components.label({
			Text = "",
			Size = UDim2.fromScale(1, 0.12),
			Position = UDim2.fromScale(0, 0.29),
			TextColor3 = Palette.Accent,
			Stroke = 2,
			Parent = card,
		})
		local detail = Components.label({
			Text = "",
			Size = UDim2.fromScale(1, 0.22),
			Position = UDim2.fromScale(0, 0.43),
			TextColor3 = Palette.TextMuted,
			TextWrapped = true,
			Stroke = 2,
			Parent = card,
		})
		local button = Components.button({
			Text = "",
			Size = UDim2.fromScale(1, 0.32),
			Position = UDim2.fromScale(0, 0.68),
			BackgroundColor3 = if isTimed then Palette.Accent else Palette.Positive,
			TextColor3 = if isTimed then Palette.Background else Palette.Text,
			-- The price, and the whole point of the board is that it's read from
			-- across the garden. The default cap is a screen button's, which on
			-- this surface's canvas came out about a fifth of the space it has.
			MaxTextSize = BOARD_PRICE_TEXT,
			Parent = card,
		}, function()
			buy(id)
		end)
		button.setIcon(if isTimed then icon("Gems") else icon("Currency"))

		rows[id] = { Status = status, Detail = detail, Button = button }
	end

	local update = makeUpdater(rows)
	local latest: { [string]: any }? = nil
	local function wrapped(snapshot: { [string]: any })
		latest = snapshot
		update(snapshot)
	end
	keepTimersLive(column, update, function()
		return latest
	end)
	return { update = wrapped }
end

-- The price button on a panel row, and everything left of it that the text gets:
-- the icon's column, the button, and a margin either side of it. The text used to
-- be sized as a share of the row and ran under the button.
local ROW_BUTTON_WIDTH = 150
local ROW_TEXT_LEFT = 60
local ROW_TEXT_WIDTH = -(ROW_TEXT_LEFT + 12 + ROW_BUTTON_WIDTH + 12)

-- Rows: one per entry, stacked in a scrolling panel.
function UpgradeList.rows(parent: Instance, ids: { string }): List
	local list = Components.scroller({ Size = UDim2.fromScale(1, 1), Parent = parent })
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	local rows: { [string]: Row } = {}

	for order, id in ids do
		local entry = entryFor(id)
		local isTimed = TIMED[id] ~= nil
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, 88),
			LayoutOrder = order,
			Pattern = true,
			BackgroundColor3 = if isTimed then Palette.Secondary else Palette.Surface,
			Parent = list,
		})

		Components.label({
			Text = entry.Icon,
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(10, 22),
			Parent = card,
		})
		Components.label({
			Text = entry.Name,
			Size = UDim2.new(1, ROW_TEXT_WIDTH, 0, 26),
			Position = UDim2.fromOffset(ROW_TEXT_LEFT, 10),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = card,
		})
		local status = Components.label({
			Text = "",
			Size = UDim2.new(1, ROW_TEXT_WIDTH, 0, 20),
			Position = UDim2.fromOffset(ROW_TEXT_LEFT, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Accent,
			MaxTextSize = 18,
			Parent = card,
		})
		local detail = Components.label({
			Text = "",
			Size = UDim2.new(1, ROW_TEXT_WIDTH, 0, 22),
			Position = UDim2.fromOffset(ROW_TEXT_LEFT, 58),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.TextMuted,
			MaxTextSize = 18,
			Parent = card,
		})
		local button = Components.button({
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(ROW_BUTTON_WIDTH, 58),
			BackgroundColor3 = if isTimed then Palette.Accent else Palette.Positive,
			TextColor3 = if isTimed then Palette.Background else Palette.Text,
			Parent = card,
		}, function()
			buy(id)
		end)
		button.setIcon(if isTimed then icon("Gems") else icon("Currency"))

		rows[id] = { Status = status, Detail = detail, Button = button }
	end

	local update = makeUpdater(rows)
	local latest: { [string]: any }? = nil
	local function wrapped(snapshot: { [string]: any })
		latest = snapshot
		update(snapshot)
	end
	keepTimersLive(list, update, function()
		return latest
	end)
	return { update = wrapped }
end

return UpgradeList
