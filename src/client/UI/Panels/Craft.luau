--!strict
-- The crafting station panel: what's loaded, what it might make, and how long
-- it has left.
--
-- The odds come from Economy.craftOutcomes, the same function the server rolls
-- with, and they're recalculated every time something goes in -- so the player
-- can see a unit's worth to the machine before they commit it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local CraftController = require(script.Parent.Parent.Parent.Controllers.CraftController)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local SLOT_HEIGHT = 112
local SLOT_WIDTH = 96
local ROW_HEIGHT = 46
-- A sparkle plus the consolations. Rows past the outcomes on offer are hidden.
local MAX_ROWS = 3

local Craft = {}

type Row = {
	Instance: Frame,
	Swatch: Frame,
	Name: TextLabel,
	Chance: TextLabel,
}

-- One card per slot: what's in it, or an empty socket.
local function slotCard(order: number, parent: Instance)
	local card = Components.card({
		LayoutOrder = order,
		Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
		Parent = parent,
	})
	local swatch: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0.5, -23, 0, 10),
		Parent = card,
	})
	Components.corner(23).Parent = swatch
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -8, 0, 32),
		Position = UDim2.fromOffset(4, 60),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 14,
		Parent = card,
	})
	local level = Components.label({
		Text = "",
		Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(4, 90),
		TextColor3 = Palette.TextMuted,
		TextScaled = false,
		TextSize = 13,
		Parent = card,
	})
	return { Swatch = swatch, Name = name, Level = level }
end

local function oddsRow(order: number, parent: Instance): Row
	local row = Components.card({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6),
		Parent = parent,
	})
	local swatch: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(10, 6),
		Parent = row,
	})
	Components.corner(14).Parent = swatch
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -140, 1, -8),
		Position = UDim2.fromOffset(48, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = row,
	})
	local chance = Components.label({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.fromOffset(86, ROW_HEIGHT - 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		Parent = row,
	})
	return { Instance = row, Swatch = swatch, Name = name, Chance = chance }
end

function Craft.create(parent: Instance)
	local panel = Components.panel(Theme.Text.Machine, UDim2.fromOffset(440, 648), parent)

	local slotRow: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, SLOT_HEIGHT),
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, 9), FillDirection = Enum.FillDirection.Horizontal }).Parent = slotRow

	local slots = {}
	for index = 1, Economy.craftSlots() do
		slots[index] = slotCard(index, slotRow)
	end

	local addButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Palette.Secondary,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("CraftAdd"):FireServer()
	end)

	Components.label({
		Text = "Chances",
		Position = UDim2.fromOffset(4, 190),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		Parent = panel.Content,
	})

	local oddsList: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 220),
		Size = UDim2.new(1, 0, 0, MAX_ROWS * ROW_HEIGHT),
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = oddsList

	local rows: { Row } = {}
	for index = 1, MAX_ROWS do
		rows[index] = oddsRow(index, oddsList)
	end

	local resultLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(4, 366),
		Size = UDim2.new(1, -8, 0, 30),
		TextColor3 = Palette.Accent,
		TextWrapped = true,
		MaxTextSize = 20,
		Parent = panel.Content,
	})

	-- Both buttons carry two jobs, so what each one is on right now is kept
	-- here rather than read back off the caption. The server re-checks either
	-- way: these only decide which message to send.
	local collecting = false
	local skipping = false

	local startButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 402),
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Palette.Positive,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event(if collecting then "CraftCollect" else "CraftStart"):FireServer()
	end)

	local secondButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 476),
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Palette.Secondary,
		Parent = panel.Content,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event(if skipping then "CraftSkip" else "CraftTakeBack"):FireServer()
	end)

	local hintLabel = Components.label({
		Text = `Feed it up to {Economy.craftSlots()} {Theme.Text.UnitPlural}. Better ones, and more of them, mean better odds.`,
		Position = UDim2.fromOffset(4, 538),
		Size = UDim2.new(1, -8, 0, 24),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		MaxTextSize = 15,
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
		local inputs = data.Craft.Inputs
		local running = Economy.craftRunning(data)
		local remaining = if running
			then math.max((snapshot.CraftReadyAt or 0) - Workspace:GetServerTimeNow(), 0)
			else 0
		local ready = running and remaining <= 0

		for index, slot in slots do
			local tier = inputs[index]
			local unit = if tier then Config.Units[tier] else nil
			slot.Swatch.BackgroundColor3 = if unit then unit.Color else Palette.Background
			slot.Name.Text = if unit then unit.Name else "Empty"
			slot.Level.Text = if tier then `Lv. {tier}` else ""
		end

		-- What's stopping the player loading it, said on the button itself.
		local carried = data.Carried
		local addText, addEnabled
		if running then
			addText, addEnabled = "Running...", false
		elseif #inputs >= Economy.craftSlots() then
			addText, addEnabled = "Machine is full", false
		elseif carried == 0 then
			addText, addEnabled = `Carry a {Theme.Text.Unit} over`, false
		elseif Economy.isSparkle(carried) then
			addText, addEnabled = `{Theme.Text.SparklePlural} can't go in`, false
		elseif not CraftController.atMachine() then
			addText, addEnabled = `Walk to the {Theme.Text.Machine}`, false
		else
			addText, addEnabled = `Add {Config.Units[carried].Name}`, true
		end
		addButton.setText(addText)
		addButton.setEnabled(addEnabled)

		local outcomes = Economy.craftOutcomes(inputs)
		for index, row in rows do
			local outcome = outcomes[index]
			row.Instance.Visible = outcome ~= nil
			if outcome then
				local unit = Config.Units[outcome.Index]
				row.Swatch.BackgroundColor3 = unit.Color
				row.Name.Text = if outcome.Sparkle then `✨ {unit.Name}` else unit.Name
				row.Name.TextColor3 = if outcome.Sparkle then Palette.Accent else Palette.Text
				row.Chance.Text = `{math.floor(outcome.Chance * 100 + 0.5)}%`
				row.Chance.TextColor3 = if outcome.Sparkle then Palette.Accent else Palette.TextMuted
			end
		end

		-- The last result stands until a new craft is started over the top of it.
		if running then
			resultLabel.Text = ""
		end

		collecting = ready
		if ready then
			startButton.setText("Collect!")
			startButton.setEnabled(true)
		elseif running then
			startButton.setText(Format.time(math.ceil(remaining)))
			startButton.setEnabled(false)
		else
			startButton.setText(`Start — {Format.time(Economy.craftSeconds())}`)
			startButton.setEnabled(#inputs > 0)
		end

		skipping = running and not ready
		-- Nothing can be taken back out once the clock has started, so the
		-- second button is only ever the gem skip while one is running.
		secondButton.Instance.Visible = skipping or (not running and #inputs > 0)
		if skipping then
			local cost = snapshot.CraftSkipCost or Economy.craftSkipCost(data)
			secondButton.setText(`Finish now — {cost}`)
			secondButton.setIcon(Theme.Icons.Gems or "")
			secondButton.setEnabled(data.Gems >= cost)
		else
			secondButton.setText(`Take them back`)
			secondButton.setIcon("")
			secondButton.setEnabled(true)
		end

		if #outcomes == 0 and not running then
			hintLabel.Text =
				`Feed it up to {Economy.craftSlots()} {Theme.Text.UnitPlural}. Better ones, and more of them, mean better odds.`
		else
			hintLabel.Text = `Whatever goes in is used up, however it turns out.`
		end
	end

	CraftController.onResult(function(index, sparkle)
		local unit = Config.Units[index]
		resultLabel.Text = if sparkle then `✨ You made a {unit.Name}!` else `It made you a {unit.Name}.`
		render()
	end)

	-- The clock and the walk-up check both change between snapshots.
	RunService.RenderStepped:Connect(function()
		if panel.isOpen() then
			render()
		end
	end)

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			latest = snapshot
			if panel.isOpen() then
				render()
			end
		end,
	}
end

return Craft
