--!strict
-- A list of things you make progress on and then claim: a label, how far along
-- it is, and a button that turns on when it's finished.
--
-- Quests use it today, and the playtime ladder and the leaderboard payouts are
-- the same shape, so this is the panel body they share rather than three
-- near-identical ones. The caller supplies rows; this owns how a row looks.

local Components = require(script.Parent.Components)

local Palette = Components.Palette

-- Three lines: what to do, what it pays, and how far along it is. Each gets its
-- own line because run together on one they outgrew the space beside the
-- button and slid under it -- "1h 12m / 1h 30m  ·  1.2K Goo + 20 Gems + a bonus
-- Squishy" is longer than the row is wide.
local ROW_HEIGHT = 86
-- Everything to the left of the button: its width, its right margin and the gap.
local BESIDE_BUTTON = 170

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

type Built = {
	Card: Frame,
	Text: TextLabel,
	Reward: TextLabel,
	Bar: Components.Bar,
	Progress: TextLabel,
	Button: Components.Button,
}

local ClaimList = {}

function ClaimList.create(props: { [string]: any }, onClaim: (index: number) -> ()): ClaimList
	local scroller = Components.scroller(props)
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = scroller

	-- Rows are built once and reused, so claiming one doesn't rebuild the list
	-- underneath the player's finger.
	local built: { Built } = {}

	local function rowAt(index: number)
		local existing = built[index]
		if existing then
			return existing
		end
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
			LayoutOrder = index,
			Pattern = true,
			Parent = scroller,
		})
		-- Scaled with a ceiling rather than a fixed size, so a long quest name
		-- shrinks a little to fit instead of running under the button.
		local text = Components.label({
			Text = "",
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -BESIDE_BUTTON, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			Parent = card,
		})
		local reward = Components.label({
			Text = "",
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -BESIDE_BUTTON, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Accent,
			MaxTextSize = 17,
			Parent = card,
		})
		local bar = Components.bar({
			Position = UDim2.fromOffset(12, 60),
			Size = UDim2.new(1, -BESIDE_BUTTON, 0, 18),
			Parent = card,
		})
		-- Written over the bar rather than beside it, so the numbers never
		-- compete with the reward for the same line.
		local progress = Components.label({
			Text = "",
			Position = UDim2.fromOffset(8, 1),
			Size = UDim2.new(1, -16, 1, -2),
			MaxTextSize = 15,
			Stroke = 2,
			ZIndex = 2,
			Parent = bar.Instance,
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
		local entry = { Card = card, Text = text, Reward = reward, Bar = bar, Progress = progress, Button = button }
		built[index] = entry
		return entry
	end

	local function render(rows: { Row })
		for index, row in rows do
			local entry = rowAt(index)
			entry.Card.Visible = true
			entry.Text.Text = row.Text
			local done = row.Progress >= row.Target

			entry.Reward.Text = row.Reward
			entry.Reward.TextColor3 = if row.Claimed then Palette.TextMuted else Palette.Accent
			-- A row with nothing to count towards has no bar to fill.
			entry.Bar.Instance.Visible = row.Claimed or row.Target > 0
			if row.Claimed then
				entry.Bar.setProgress(1)
				entry.Progress.Text = "Claimed"
			elseif row.Target > 0 then
				entry.Bar.setProgress(row.Progress / row.Target)
				entry.Progress.Text = row.ProgressText or `{row.Progress} / {row.Target}`
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
