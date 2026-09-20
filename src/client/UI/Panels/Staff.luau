--!strict
-- The staff panel, for the game's own admins. Four pages:
--
--   Events   start or end an event on every server
--   Gifts    drop any unit, or hand out currency, to yourself, a player or the server
--   Players  go to, bring, kick or ban
--   Message  send a line of text to every player in the game
--
-- Only staff see the button that opens it, and the server re-checks every command
-- whoever sends it (StaffService). Anything that reaches every server or can't be
-- taken back asks first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Confirm = require(script.Parent.Parent.Confirm)
local Format = require(ReplicatedStorage.Shared.Format)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local TAB_HEIGHT = 50
local CHIP_HEIGHT = 44
-- An event card stacks a title, a description and a row of buttons, and is padded
-- on every side. The height was a flat 104, which is ten pixels short of that, so
-- the buttons -- pinned to the bottom of the card -- sat over the bottom half of
-- every description. Adding the pieces up instead means it can't drift again.
local EVENT_TITLE_HEIGHT = 30
local EVENT_DESC_HEIGHT = 22
local EVENT_CARD_PAD = 10
local EVENT_CARD_GAP = 6
local EVENT_CARD_HEIGHT = EVENT_CARD_PAD * 2 + EVENT_TITLE_HEIGHT + EVENT_DESC_HEIGHT + EVENT_CARD_GAP + CHIP_HEIGHT
local UNIT_CELL_HEIGHT = 56
local SPAWN_COUNTS = { 1, 5, 10, 25 }

local Staff = {}

local function send(command: string, args: { [string]: any })
	Sound.play(Theme.Sounds.Purchase)
	Net.event("StaffCommand"):FireServer(command, args)
end

local function durationText(minutes: number): string
	return if minutes >= 60 then `{minutes // 60}h` else `{minutes}m`
end

local function sectionTitle(text: string, order: number, parent: Instance)
	Components.label({
		Text = text,
		Size = UDim2.new(1, -12, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		Stroke = 2,
		MaxTextSize = 22,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function textBox(props: { [string]: any }): TextBox
	local merged: { [string]: any } = {
		BackgroundColor3 = Palette.Surface,
		BorderSizePixel = 0,
		FontFace = Theme.Font,
		TextColor3 = Palette.Text,
		PlaceholderColor3 = Palette.TextMuted,
		TextSize = 20,
		ClearTextOnFocus = false,
		Text = "",
	}
	for key, value in props do
		merged[key] = value
	end
	local box: TextBox = Components.new("TextBox", merged)
	Components.corner(8).Parent = box
	Components.padding(8).Parent = box
	return box
end

-- A row of buttons where one is picked at a time, drawn in the accent colour. It
-- wraps onto more lines rather than scrolling sideways, so every player in a full
-- server is on screen at once.
type Choice<T> = {
	Frame: Frame,
	get: () -> T?,
	set: (T?) -> (),
	add: (value: T, text: string) -> Components.Button,
	remove: (value: T) -> (),
}

local function choiceRow<T>(parent: Instance, order: number, width: number, onChange: ((T?) -> ())?): Choice<T>
	local frame: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Components.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(width, CHIP_HEIGHT),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	local buttons: { [any]: Components.Button } = {}
	local selected: T? = nil
	local count = 0

	local function render()
		for value, button in buttons do
			button.setColor(if value == selected then Palette.Accent else Palette.Surface)
		end
	end

	local choice: Choice<T>
	choice = {
		Frame = frame,
		get = function()
			return selected
		end,
		set = function(value: T?)
			selected = value
			render()
			if onChange then
				onChange(value)
			end
		end,
		add = function(value: T, text: string)
			count += 1
			local button = Components.button({
				Text = text,
				BackgroundColor3 = Palette.Surface,
				MaxTextSize = 20,
				LayoutOrder = count,
				Parent = frame,
			}, function()
				Sound.play(Theme.Sounds.Purchase)
				choice.set(value)
			end)
			buttons[value] = button
			render()
			return button
		end,
		remove = function(value: T)
			local button = buttons[value]
			if button then
				button.Instance:Destroy()
				buttons[value] = nil
			end
			if selected == value then
				choice.set(nil)
			end
		end,
	}
	return choice
end

function Staff.create(parent: Instance)
	local panel = Components.panel("Staff Panel", UDim2.fromOffset(600, 640), parent)
	local confirm = Confirm.create(parent)

	-- Tabs ------------------------------------------------------------------------

	local tabBar: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = panel.Content,
	})
	Components.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -6, 1, 0),
		CellPadding = UDim2.fromOffset(8, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabBar,
	})

	type Page = { Name: string, List: ScrollingFrame, Button: Components.Button }
	local pages: { Page } = {}

	local function showPage(name: string)
		for _, page in pages do
			page.List.Visible = page.Name == name
			page.Button.setColor(if page.Name == name then Palette.Accent else Palette.Secondary)
		end
	end

	local function addPage(name: string): ScrollingFrame
		local list = Components.scroller({
			Position = UDim2.fromOffset(0, TAB_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 10)),
			Visible = false,
			Parent = panel.Content,
		})
		Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list
		local button = Components.button({
			Text = name,
			BackgroundColor3 = Palette.Secondary,
			MaxTextSize = 22,
			LayoutOrder = #pages + 1,
			Parent = tabBar,
		}, function()
			Sound.play(Theme.Sounds.Purchase)
			showPage(name)
		end)
		table.insert(pages, { Name = name, List = list, Button = button })
		return list
	end

	local latest: { [string]: any }? = nil

	-- Events ----------------------------------------------------------------------

	local eventsPage = addPage("Events")
	sectionTitle("How long", 1, eventsPage)
	local duration = choiceRow(eventsPage, 2, 96)
	for _, minutes in LiveEvents.Durations do
		duration.add(minutes, durationText(minutes))
	end
	duration.set(LiveEvents.Durations[2])

	sectionTitle("Start one — it runs on every server", 3, eventsPage)

	type EventRow = { Status: TextLabel, End: Components.Button }
	local eventRows: { [string]: EventRow } = {}

	for index, def in LiveEvents.List do
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, EVENT_CARD_HEIGHT),
			LayoutOrder = 3 + index,
			Pattern = true,
			Parent = eventsPage,
		})
		Components.padding(EVENT_CARD_PAD).Parent = card
		Components.label({
			Text = `{def.Icon} {def.Name}`,
			Size = UDim2.new(0.5, 0, 0, EVENT_TITLE_HEIGHT),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Stroke = 2,
			Parent = card,
		})
		local status = Components.label({
			Text = "Off",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, 0, 0, EVENT_TITLE_HEIGHT),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Palette.TextMuted,
			MaxTextSize = 20,
			Parent = card,
		})
		Components.label({
			Text = def.Description,
			Position = UDim2.fromOffset(0, EVENT_TITLE_HEIGHT),
			Size = UDim2.new(1, 0, 0, EVENT_DESC_HEIGHT),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.TextMuted,
			MaxTextSize = 16,
			Parent = card,
		})
		local buttons: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 1, -CHIP_HEIGHT),
			Size = UDim2.new(1, 0, 0, CHIP_HEIGHT),
			Parent = card,
		})
		Components.listLayout({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}).Parent =
			buttons
		for order, strength in def.Strengths do
			Components.button({
				Text = `x{strength}`,
				Size = UDim2.fromOffset(86, CHIP_HEIGHT),
				BackgroundColor3 = Palette.Positive,
				MaxTextSize = 22,
				LayoutOrder = order,
				Parent = buttons,
			}, function()
				local minutes = duration.get() or LiveEvents.Durations[1]
				confirm.ask(`Start {def.Name} on every server?`, `x{strength} for {durationText(minutes)}`, function()
					send("StartEvent", { Id = def.Id, Strength = strength, Minutes = minutes })
				end)
			end)
		end
		local endButton = Components.button({
			Text = "End",
			Size = UDim2.fromOffset(86, CHIP_HEIGHT),
			BackgroundColor3 = Palette.Negative,
			MaxTextSize = 22,
			LayoutOrder = 100,
			Parent = buttons,
		}, function()
			confirm.ask(`End {def.Name} on every server?`, "Players lose it straight away", function()
				send("StopEvent", { Id = def.Id })
			end)
		end)
		eventRows[def.Id] = { Status = status, End = endButton }
	end

	local function renderEvents()
		local running: { [string]: { [string]: any } } = {}
		local snapshot = latest
		for _, entry in (if snapshot then snapshot.Events else nil) or {} do
			running[entry.Id] = entry
		end
		local now = Workspace:GetServerTimeNow()
		for id, row in eventRows do
			local entry = running[id]
			local left = if entry then entry.EndsAt - now else 0
			if entry and left > 0 then
				local by = if entry.StartedBy ~= "" then ` · {entry.StartedBy}` else ""
				row.Status.Text = `x{entry.Strength} · {Format.time(math.ceil(left))} left{by}`
				row.Status.TextColor3 = Palette.Positive
				row.End.setEnabled(true)
			else
				row.Status.Text = "Off"
				row.Status.TextColor3 = Palette.TextMuted
				row.End.setEnabled(false)
			end
		end
	end

	-- Shared player tracking ------------------------------------------------------
	-- Both the gift and player pages pick someone, and both lists follow the server.

	local playerChoices: { Choice<number> } = {}
	local function trackPlayers(choice: Choice<number>)
		table.insert(playerChoices, choice)
		for _, player in Players:GetPlayers() do
			choice.add(player.UserId, player.DisplayName)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		for _, choice in playerChoices do
			choice.add(player.UserId, player.DisplayName)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, choice in playerChoices do
			choice.remove(player.UserId)
		end
	end)

	-- Gifts -----------------------------------------------------------------------

	local giftsPage = addPage("Gifts")
	-- "Me", "Server", or a user id. Two rows feed one answer: picking in either
	-- clears the other.
	local giftTarget: any = "Me"
	local groupRow: Choice<string>
	local peopleRow: Choice<number>

	sectionTitle("Give to", 1, giftsPage)
	groupRow = choiceRow(giftsPage, 2, 150, function(value)
		if value then
			giftTarget = value
			peopleRow.set(nil)
		end
	end)
	peopleRow = choiceRow(giftsPage, 3, 150, function(value)
		if value then
			giftTarget = value
			groupRow.set(nil)
		elseif groupRow.get() == nil then
			groupRow.set("Me")
		end
	end)
	groupRow.add("Me", "Me")
	groupRow.add("Server", "Everyone here")
	groupRow.set("Me")
	trackPlayers(peopleRow)

	sectionTitle(`{Theme.Text.Currency} or Gems`, 4, giftsPage)
	local currencyRow: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, CHIP_HEIGHT),
		LayoutOrder = 5,
		Parent = giftsPage,
	})
	local amountBox = textBox({
		PlaceholderText = "Amount",
		Size = UDim2.new(0.4, -8, 1, 0),
		Parent = currencyRow,
	})
	local function giveCurrency(currency: string)
		local amount = tonumber((amountBox.Text:gsub("[,%s]", "")))
		if not amount or amount < 1 then
			return
		end
		local name = if currency == "Cash" then Theme.Text.Currency else "Gems"
		local who = if giftTarget == "Me"
			then "yourself"
			elseif giftTarget == "Server" then "everyone in this server"
			else "this player"
		confirm.ask(`Give {name} to {who}?`, Format.number(amount), function()
			send("Give", { Currency = currency, Amount = amount, Target = giftTarget })
		end)
	end
	Components.button({
		Text = `Give {Theme.Text.Currency}`,
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.3, -8, 1, 0),
		BackgroundColor3 = Palette.Positive,
		MaxTextSize = 20,
		Parent = currencyRow,
	}, function()
		giveCurrency("Cash")
	end)
	Components.button({
		Text = "Give Gems",
		Position = UDim2.fromScale(0.7, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Palette.Secondary,
		MaxTextSize = 20,
		Parent = currencyRow,
	}, function()
		giveCurrency("Gems")
	end)

	sectionTitle(`Spawn a {Theme.Text.Unit}`, 6, giftsPage)
	local countRow = choiceRow(giftsPage, 7, 80)
	for _, count in SPAWN_COUNTS do
		countRow.add(count, `x{count}`)
	end
	countRow.set(1)
	local search = textBox({
		PlaceholderText = "Search by name",
		Size = UDim2.new(1, -12, 0, CHIP_HEIGHT),
		LayoutOrder = 8,
		Parent = giftsPage,
	})

	local unitGrid: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 9,
		Parent = giftsPage,
	})
	Components.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, UNIT_CELL_HEIGHT),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = unitGrid,
	})
	local unitCells: { { Cell: Frame, Name: string } } = {}
	for index, unit in Config.Units do
		local cell = Components.card({ LayoutOrder = index, Parent = unitGrid })
		Components.new("Frame", {
			BackgroundColor3 = unit.Color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(12, UNIT_CELL_HEIGHT - 16),
			Parent = cell,
		})
		Components.button({
			Text = `#{index} {unit.Name}`,
			Position = UDim2.fromOffset(28, 6),
			Size = UDim2.new(1, -34, 1, -12),
			BackgroundColor3 = Palette.Surface,
			MaxTextSize = 18,
			Parent = cell,
		}, function()
			send("Spawn", { Index = index, Count = countRow.get() or 1, Target = giftTarget })
		end)
		table.insert(unitCells, { Cell = cell, Name = unit.Name:lower() })
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local wanted = search.Text:lower()
		for _, entry in unitCells do
			entry.Cell.Visible = wanted == "" or entry.Name:find(wanted, 1, true) ~= nil
		end
	end)

	-- Players ---------------------------------------------------------------------

	local playersPage = addPage("Players")
	sectionTitle("Pick a player", 1, playersPage)
	local chosen = choiceRow(playersPage, 2, 150)
	trackPlayers(chosen)
	-- You can't moderate yourself; the server refuses too.
	chosen.remove(LocalPlayer.UserId)

	local function chosenPlayer(): Player?
		local userId = chosen.get()
		return if userId then Players:GetPlayerByUserId(userId) else nil
	end

	local function actionRow(order: number): Frame
		local row: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, CHIP_HEIGHT),
			LayoutOrder = order,
			Parent = playersPage,
		})
		Components.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = row,
		})
		return row
	end

	sectionTitle("Move", 3, playersPage)
	local moveRow = actionRow(4)
	for order, command in { "GoTo", "Bring" } do
		Components.button({
			Text = if command == "GoTo" then "Go to" else "Bring",
			BackgroundColor3 = Palette.Secondary,
			MaxTextSize = 20,
			LayoutOrder = order,
			Parent = moveRow,
		}, function()
			local target = chosenPlayer()
			if target then
				send(command, { UserId = target.UserId })
			end
		end)
	end

	sectionTitle("Reason", 5, playersPage)
	local reason = choiceRow(playersPage, 6, 270)
	for _, text in LiveEvents.ModerationReasons do
		reason.add(text, text)
	end
	reason.set(LiveEvents.ModerationReasons[1])

	sectionTitle("Remove", 7, playersPage)
	local removeRow = actionRow(8)
	Components.button({
		Text = "Kick",
		BackgroundColor3 = Palette.Negative,
		MaxTextSize = 20,
		LayoutOrder = 1,
		Parent = removeRow,
	}, function()
		local target = chosenPlayer()
		local why = reason.get()
		if target and why then
			confirm.ask(`Kick {target.DisplayName}?`, why, function()
				send("Kick", { UserId = target.UserId, Reason = why })
			end)
		end
	end)
	local banRow = actionRow(9)
	for order, days in LiveEvents.BanDays do
		local length = if days == 0 then "forever" elseif days == 1 then "1 day" else `{days} days`
		Components.button({
			Text = `Ban {length}`,
			BackgroundColor3 = Palette.Negative,
			MaxTextSize = 20,
			LayoutOrder = order,
			Parent = banRow,
		}, function()
			local target = chosenPlayer()
			local why = reason.get()
			if target and why then
				confirm.ask(`Ban {target.DisplayName} from the whole game {length}?`, why, function()
					send("Ban", { UserId = target.UserId, Days = days, Reason = why })
				end)
			end
		end)
	end
	Components.label({
		Text = "Bans cover every server and alt accounts. Undo one from the Creator Hub, under Moderation.",
		Size = UDim2.new(1, -12, 0, 40),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		MaxTextSize = 16,
		LayoutOrder = 10,
		Parent = playersPage,
	})

	-- Message ---------------------------------------------------------------------

	local messagePage = addPage("Message")
	sectionTitle("Say something to every player in the game", 1, messagePage)
	local messageBox = textBox({
		PlaceholderText = "Event starting at the hub in 5 minutes!",
		Size = UDim2.new(1, -12, 0, 140),
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = messagePage,
	})
	local counter = Components.label({
		Text = `0 / {LiveEvents.AnnouncementLength}`,
		Size = UDim2.new(1, -12, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 16,
		LayoutOrder = 3,
		Parent = messagePage,
	})
	local sendButton = Components.button({
		Text = "Send to every server",
		Size = UDim2.new(1, -12, 0, 58),
		BackgroundColor3 = Palette.Positive,
		MaxTextSize = 24,
		LayoutOrder = 4,
		Parent = messagePage,
	}, function()
		local text = messageBox.Text
		if text:match("^%s*$") then
			return
		end
		-- The dialog's highlight is one line, so a long message is previewed by its start.
		local preview = if (utf8.len(text) or #text) > 60
			then text:sub(1, (utf8.offset(text, 61) or 61) - 1) .. "…"
			else text
		confirm.ask("Send this to every player in the game?", preview, function()
			send("Announce", { Text = text })
			messageBox.Text = ""
		end)
	end)
	Components.label({
		Text = "Roblox's text filter checks it before anyone sees it.",
		Size = UDim2.new(1, -12, 0, 20),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 16,
		LayoutOrder = 5,
		Parent = messagePage,
	})
	messageBox:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(messageBox.Text) or #messageBox.Text
		counter.Text = `{length} / {LiveEvents.AnnouncementLength}`
		counter.TextColor3 = if length > LiveEvents.AnnouncementLength then Palette.Negative else Palette.TextMuted
		sendButton.setEnabled(length > 0 and length <= LiveEvents.AnnouncementLength)
	end)
	sendButton.setEnabled(false)

	showPage("Events")

	-- The event clocks tick down between snapshots.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed >= 1 and panel.isOpen() then
			elapsed = 0
			renderEvents()
		end
	end)

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			latest = snapshot
			renderEvents()
		end,
	}
end

return Staff
