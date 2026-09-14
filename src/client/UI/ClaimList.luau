--!strict
-- A list of things you make progress on and then claim: a label, how far along
-- it is, and a button that turns on when it's finished.
--
-- Quests use it today, and the playtime ladder and the leaderboard payouts are
-- the same shape, so this is the panel body they share rather than three
-- near-identical ones. The caller supplies rows; this owns how a row looks.

local Components = require(script.Parent.Components)

local Palette = Components.Palette

local ROW_HEIGHT = 74

export type Row = {
	-- What the player is being asked to do.
	Text: string,
	-- How far along, and out of what. A row with Target 0 shows no progress.
	-- These decide whether the claim button turns on, whatever is displayed.
	Progress: number,
	Target: number,
	-- Overrides the "3 / 10" the numbers would otherwise read as, for a row
	-- whose progress isn't a count: a clock wants "1m 23s / 5m", not "83 / 300".
	ProgressText: string?,
	-- What claiming it pays, written out.
	Reward: string,
	Claimed: boolean,
}

export type ClaimList = {
	Instance: ScrollingFrame,
	-- Renders the rows, calling `onClaim` with the index of whichever is pressed.
	render: (rows: { Row }) -> (),
}

local ClaimList = {}

function ClaimList.create(props: { [string]: any }, onClaim: (index: number) -> ()): ClaimList
	local scroller = Components.scroller(props)
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = scroller

	-- Rows are built once and reused, so claiming one doesn't rebuild the list
	-- underneath the player's finger.
	local built: { { Card: Frame, Text: TextLabel, Progress: TextLabel, Button: any } } = {}

	local function rowAt(index: number)
		local existing = built[index]
		if existing then
			return existing
		end
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Parent = scroller,
		})
		local text = Components.label({
			Text = "",
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -170, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = false,
			TextSize = 19,
			Parent = card,
		})
		local progress = Components.label({
			Text = "",
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -170, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.TextMuted,
			TextScaled = false,
			TextSize = 16,
			Parent = card,
		})
		local button = Components.button({
			Text = "Claim",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(132, 50),
			BackgroundColor3 = Palette.Positive,
			Parent = card,
		}, function()
			onClaim(index)
		end)
		local entry = { Card = card, Text = text, Progress = progress, Button = button }
		built[index] = entry
		return entry
	end

	local function render(rows: { Row })
		for index, row in rows do
			local entry = rowAt(index)
			entry.Card.Visible = true
			entry.Text.Text = row.Text
			local done = row.Progress >= row.Target

			if row.Claimed then
				entry.Progress.Text = `Claimed — {row.Reward}`
				entry.Progress.TextColor3 = Palette.TextMuted
			elseif row.Target > 0 then
				local along = row.ProgressText or `{row.Progress} / {row.Target}`
				entry.Progress.Text = `{along}  ·  {row.Reward}`
				entry.Progress.TextColor3 = if done then Palette.Positive else Palette.TextMuted
			else
				entry.Progress.Text = row.Reward
				entry.Progress.TextColor3 = Palette.TextMuted
			end

			entry.Button.setText(if row.Claimed then "Claimed" else "Claim")
			entry.Button.setEnabled(done and not row.Claimed)
		end
		-- Rows built for a longer list last time are hidden rather than
		-- destroyed, since the list length changes as quests roll over.
		for index = #rows + 1, #built do
			built[index].Card.Visible = false
		end
	end

	return { Instance = scroller, render = render }
end

return ClaimList
