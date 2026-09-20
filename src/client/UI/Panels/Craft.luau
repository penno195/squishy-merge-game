--!strict
-- The crafting station panel: what's loaded, what it might make, and how long
-- it has left.
--
-- The odds come from Economy.craftOutcomes, the same function the server rolls
-- with, and they're recalculated every time something goes in -- so the player
-- can see a unit's worth to the machine before they commit it.
--
-- The panel shows one craft at a time. A player with the second-slot pass gets a
-- row of tabs above it and everything below them follows the selected one --
-- rather than two copies of the panel side by side, which at this width would
-- halve a layout that is already tight. How many tabs there are is the server's
-- answer (`CraftSlots`), not a guess made from the pass list here.

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

local INPUT_HEIGHT = 112
local INPUT_WIDTH = 96
local ROW_HEIGHT = 46
-- A sparkle plus the consolations. Rows past the outcomes on offer are hidden.
local MAX_ROWS = 3
-- The tab strip, and the room it takes off the top of everything below it. Zero
-- of it is used by a player with one slot: the strip is hidden and the body sits
-- where it always did, so nobody pays for a pass they don't own in layout.
local TAB_HEIGHT = 44
local TAB_GAP = 8
-- The row the start and second buttons share, and how much of it the start
-- button has while the second is showing.
local ACTION_TOP = 430
local ACTION_HEIGHT = 66
local ACTION_GAP = 8
local START_SHARE = 0.56

local Craft = {}

type Row = {
	Instance: Frame,
	Swatch: Frame,
	Name: TextLabel,
	Chance: TextLabel,
}

-- One card per unit a craft can take: what's in it, or an empty socket. Not a
-- "slot" -- that word now means a whole craft, and these are the four places
-- inside one.
local function inputCard(order: number, parent: Instance)
	local card = Components.card({
		LayoutOrder = order,
		Size = UDim2.fromOffset(INPUT_WIDTH, INPUT_HEIGHT),
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
	-- Scaled down from a ceiling rather than fixed: a variant's name is three
	-- words, and at a fixed size the third line ran down over the level under it.
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -4, 0, 34),
		Position = UDim2.fromOffset(2, 57),
		TextWrapped = true,
		MaxTextSize = 15,
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
	local panel = Components.panel(Theme.Text.Machine, UDim2.fromOffset(440, 684), parent)

	-- Which craft everything below the tabs is about. Set from the server's first
	-- snapshot to whatever is worth looking at, and the player's own after that:
	-- re-picking it on every snapshot would drag the panel off the slot they were
	-- reading whenever the other one finished.
	local selected = 1
	local chosen = false

	local tabStrip: Frame = Components.new("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Visible = false,
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, TAB_GAP), FillDirection = Enum.FillDirection.Horizontal }).Parent =
		tabStrip

	-- Everything the panel had before, moved into a frame of its own so the tab
	-- strip can push it down when there is one. Its children keep the absolute
	-- positions they always had.
	local body: Frame = Components.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = panel.Content,
	})

	local inputRow: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
		Parent = body,
	})
	Components.listLayout({ Padding = UDim.new(0, 9), FillDirection = Enum.FillDirection.Horizontal }).Parent = inputRow

	local inputCards = {}
	for index = 1, Economy.craftInputs() do
		inputCards[index] = inputCard(index, inputRow)
	end

	local addButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundColor3 = Palette.Secondary,
		Parent = body,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("CraftAdd"):FireServer(selected)
	end)

	Components.label({
		Text = "Chances",
		Position = UDim2.fromOffset(4, 190),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		Parent = body,
	})

	local oddsList: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 220),
		Size = UDim2.new(1, 0, 0, MAX_ROWS * ROW_HEIGHT),
		Parent = body,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = oddsList

	local rows: { Row } = {}
	for index = 1, MAX_ROWS do
		rows[index] = oddsRow(index, oddsList)
	end

	-- Hidden until a variant is actually in the machine, so an ordinary load
	-- doesn't carry a line explaining something that isn't happening.
	local boostLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(4, 366),
		Size = UDim2.new(1, -8, 0, 26),
		TextColor3 = Palette.Positive,
		TextWrapped = true,
		MaxTextSize = 17,
		Visible = false,
		Parent = body,
	})

	local resultLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(4, 394),
		Size = UDim2.new(1, -8, 0, 30),
		TextColor3 = Palette.Accent,
		TextWrapped = true,
		MaxTextSize = 20,
		Parent = body,
	})

	-- Both buttons carry two jobs, so what each one is on right now is kept
	-- here rather than read back off the caption. The server re-checks either
	-- way: these only decide which message to send.
	local collecting = false
	local skipping = false

	-- The two share a row, the main one wider, and the main one takes the whole
	-- row back when the other has nothing to offer. Stacked, they left no room
	-- for the tab strip a second slot adds, and the hint ran out of the bottom
	-- of the panel.
	local startButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, ACTION_TOP),
		Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
		BackgroundColor3 = Palette.Positive,
		Parent = body,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event(if collecting then "CraftCollect" else "CraftStart"):FireServer(selected)
	end)

	local secondButton = Components.button({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, ACTION_TOP),
		Size = UDim2.new(1 - START_SHARE, -ACTION_GAP / 2, 0, ACTION_HEIGHT),
		BackgroundColor3 = Palette.Secondary,
		Parent = body,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event(if skipping then "CraftSkip" else "CraftTakeBack"):FireServer(selected)
	end)

	local hintLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(4, ACTION_TOP + ACTION_HEIGHT + 8),
		Size = UDim2.new(1, -8, 0, 36),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		MaxTextSize = 15,
		Parent = body,
	})
	hintLabel.Name = "Hint"

	local latest: { [string]: any }? = nil

	-- Forward-declared: the tabs are built before it and call it, and it reads the
	-- tabs it draws.
	local render: () -> ()

	-- Built for the most any player could ever have, and shown down to the number
	-- the server says this one has. Building them up front keeps the panel from
	-- having to create instances in the middle of a purchase.
	local tabs = {}
	for slot = 1, Economy.maxCraftSlots() do
		local width = 1 / Economy.maxCraftSlots()
		tabs[slot] = Components.button({
			Text = `Slot {slot}`,
			-- Each tab gives up its share of the gaps between them.
			Size = UDim2.new(width, -TAB_GAP, 1, 0),
			LayoutOrder = slot,
			BackgroundColor3 = Palette.Surface,
			Parent = tabStrip,
		}, function()
			selected = slot
			Sound.play(Theme.Sounds.Purchase)
			render()
		end)
	end

	render = function()
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		local slots: number = snapshot.CraftSlots or 1
		local readyAt: { number } = snapshot.CraftReadyAt or {}
		local skipCosts: { number } = snapshot.CraftSkipCost or {}
		local gameNow = Workspace:GetServerTimeNow()

		-- Opens on whatever is worth seeing: something to collect, else something
		-- to load. Once only -- after that the tabs are the player's business.
		if not chosen then
			chosen = true
			selected = Economy.readyCraftSlot(data, os.time(), slots) or Economy.openCraftSlot(data, slots) or 1
		end
		-- A pass can go away mid-session, and the panel must not be left pointing
		-- at a slot the server will refuse every message about.
		selected = math.clamp(selected, 1, slots)

		local craft = data.Craft[selected]
		if not craft then
			return
		end

		-- The strip earns its space only when there is a choice to make.
		tabStrip.Visible = slots > 1
		body.Position = UDim2.fromOffset(0, if slots > 1 then TAB_HEIGHT + TAB_GAP else 0)
		body.Size = UDim2.new(1, 0, 1, if slots > 1 then -(TAB_HEIGHT + TAB_GAP) else 0)
		for slot, tab in tabs do
			tab.Instance.Visible = slot <= slots
			local other = data.Craft[slot]
			if other and slot <= slots then
				-- Each tab says what its own slot is doing, so the choice can be
				-- made without visiting both.
				local otherRemaining = math.max((readyAt[slot] or 0) - gameNow, 0)
				local caption
				if Economy.craftRunning(other) then
					caption = if otherRemaining <= 0 then "Ready!" else Format.time(math.ceil(otherRemaining))
				else
					caption = `{#other.Inputs} / {Economy.craftInputs()}`
				end
				tab.setText(`{slot} — {caption}`)
				-- The selected one is lit; a slot with something waiting in it is
				-- lit differently again, since that is the one worth a look. All
				-- of them stay pressable -- a disabled tab would grey out exactly
				-- the one the player is looking at, and re-picking it costs
				-- nothing anyway.
				local tone = if slot == selected
					then Palette.Secondary
					elseif Economy.craftReady(other, os.time()) then Palette.Positive
					else Palette.Surface
				tab.setColor(tone)
			end
		end

		local inputs = craft.Inputs
		local running = Economy.craftRunning(craft)
		local remaining = if running then math.max((readyAt[selected] or 0) - gameNow, 0) else 0
		local ready = running and remaining <= 0

		for index, card in inputCards do
			local tier = inputs[index]
			local unit = if tier then Config.Units[tier] else nil
			card.Swatch.BackgroundColor3 = if unit then unit.Color else Palette.Background
			card.Name.Text = if unit then unit.Name else "Empty"
			card.Level.Text = if tier then `Lv. {Economy.ladderTier(tier)}` else ""
		end

		-- What's stopping the player loading it, said on the button itself.
		local carried = data.Carried
		local addText, addEnabled
		if running then
			addText, addEnabled = "Running...", false
		elseif #inputs >= Economy.craftInputs() then
			addText, addEnabled = "This slot is full", false
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

		-- Said out loud, because a variant raising the ceiling is invisible
		-- otherwise: the odds move, but nothing says why they moved.
		-- The pet counts toward the odds, so it has to count here too: this panel's
		-- promise is that what's on screen is what the server rolls.
		local petBoost = Economy.petPerkValue(data, "CraftLuck")
		local boost = Economy.craftBoost(inputs, petBoost)
		boostLabel.Visible = boost > 1
		boostLabel.Text = `Variant boost: better odds, up to x{string.format("%.2g", boost)} the usual ceiling`

		local outcomes = Economy.craftOutcomes(inputs, petBoost)
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
		local showSecond = skipping or (not running and #inputs > 0)
		secondButton.Instance.Visible = showSecond
		startButton.Instance.Size = if showSecond
			then UDim2.new(START_SHARE, -ACTION_GAP / 2, 0, ACTION_HEIGHT)
			else UDim2.new(1, 0, 0, ACTION_HEIGHT)
		if skipping then
			local cost = skipCosts[selected] or Economy.craftSkipCost(craft)
			secondButton.setText(`Finish — {cost}`)
			secondButton.setIcon(Theme.Icons.Gems or "")
			secondButton.setEnabled(data.Gems >= cost)
		else
			secondButton.setText(`Take back`)
			secondButton.setIcon("")
			secondButton.setEnabled(true)
		end

		if #outcomes == 0 and not running then
			hintLabel.Text =
				`Up to {Economy.craftInputs()} {Theme.Text.UnitPlural}. Better ones, and more of them, give better odds.`
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
