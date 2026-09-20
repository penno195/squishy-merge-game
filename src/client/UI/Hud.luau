--!strict
-- The heads-up display: currency, income, what you're carrying, the drop
-- timer, the buy button, the menu that opens each panel, and toasts.
--
-- Laid out by importance rather than by convenience. Cash is the biggest thing
-- on screen because it's what every decision is measured against; income,
-- capacity and rebirths sit under it in muted text; and anything that only
-- matters sometimes (the boost, the drop button) appears only when it does.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Confirm = require(script.Parent.Confirm)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Reveal = require(script.Parent.Reveal)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)

local AdminPanel = require(script.Parent.Panels.Admin)
local CraftPanel = require(script.Parent.Panels.Craft)
local DailyPanel = require(script.Parent.Panels.Daily)
local EventStrip = require(script.Parent.EventStrip)
local EggPanel = require(script.Parent.Panels.Egg)
local IndexPanel = require(script.Parent.Panels.Index)
local LeaderboardPanel = require(script.Parent.Panels.Leaderboard)
local PetsPanel = require(script.Parent.Panels.Pets)
local PlaytimePanel = require(script.Parent.Panels.Playtime)
local QuestsPanel = require(script.Parent.Panels.Quests)
local ShopPanel = require(script.Parent.Panels.Shop)
local StaffPanel = require(script.Parent.Panels.Staff)
local UpgradesPanel = require(script.Parent.Panels.Upgrades)
local WheelPanel = require(script.Parent.Panels.Wheel)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local TOAST_SECONDS = 4
-- How many can be on screen at once. See the note where they're built.
local MAX_TOASTS = 3
local TOAST_COLORS: { [string]: Color3 } = {
	Error = Palette.Negative,
	Reward = Palette.Positive,
	Discovery = Palette.Accent,
	Offline = Palette.Secondary,
	Rebirth = Palette.Primary,
}

-- Menu icons. Generic UI symbols rather than theme art, so a reskin that sets
-- no icons of its own still gets a readable menu.
local MENU_ICONS: { [string]: string } = {
	Upgrades = "⬆️",
	Shop = "🛒",
	Rewards = "🎁",
	Collection = "🎒",
	Daily = "📅",
	Quests = "📋",
	Playtime = "⏱️",
	Wheel = "🎡",
	Craft = "⚗️",
	Ranks = "🏆",
	Index = "📖",
	Pets = "🐾",
	Admin = "🛡️",
	Staff = "👑",
}
local WHEEL_PANEL = "Wheel"
local CRAFT_PANEL = "Craft"
local EGG_PANEL = "Egg"
local ADMIN_PANEL = "Admin"
local STAFF_PANEL = "Staff"
-- The prompt on an egg pad, which carries an "Egg" attribute saying which pad it
-- is. Named rather than matched on the panel map because it has to be filled in
-- before it opens, which none of the others do.
local EGG_PROMPT = "EggPrompt"
-- Which panel each of the hub's own ProximityPrompts opens.
local PROMPT_PANELS: { [string]: string } = {
	SpinPrompt = WHEEL_PANEL,
	CraftPrompt = CRAFT_PANEL,
}

local Hud = {}

function Hud.start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screen: ScreenGui = Components.new("ScreenGui", {
		Name = "MergeHud",
		ResetOnSpawn = false,
		-- Left false so Roblox keeps the HUD clear of its own top bar.
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	-- Prize and egg cards are drawn over everything, so they hang off the screen
	-- rather than off any panel.
	Reveal.mount(screen)

	-- One scale factor keeps the layout usable from phone to desktop.
	local scale: UIScale = Components.new("UIScale", { Parent = screen })
	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / 800, 0.6, 1.25)
		end
	end
	updateScale()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	-- Left column: stats, then the menu (top left) ------------------------
	-- Both live in one auto-sizing column so the buttons always start below
	-- the last stat line. Floating the menu at half screen height overlapped
	-- the stats on anything shorter than about 1000px, and the stack changes
	-- height anyway as the boost pill comes and goes.
	-- Roblox's own chrome can sit above the inset on some devices, so start
	-- below whatever it reserves rather than at a fixed margin.
	local topInset = GuiService:GetGuiInset().Y
	local column = Components.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16 + topInset),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent =
		column

	local stats = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = column,
	})
	Components.listLayout({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent =
		stats

	-- The hero stat: biggest element on screen, in the brightest colour.
	local cashPill = Components.pill({
		Size = UDim2.fromOffset(300, 68),
		LayoutOrder = 1,
	}, Theme.Icons.Currency or "", Palette.Accent)
	cashPill.Instance.Parent = stats

	-- Gems, with the two timed effects beside them as chips while they run.
	-- Beside rather than under: they come and go, and stacked as full rows they
	-- pushed the menu off the bottom of a short screen.
	local gemRow = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = stats,
	})
	Components.listLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent =
		gemRow

	local gemPill = Components.pill({
		Size = UDim2.fromOffset(170, 46),
		LayoutOrder = 1,
	}, Theme.Icons.Gems or "", Palette.Secondary)
	gemPill.Instance.Parent = gemRow

	-- Only on screen while it's running, so a quiet HUD stays quiet.
	local boostPill = Components.pill({
		Size = UDim2.fromOffset(150, 46),
		LayoutOrder = 2,
		BackgroundColor3 = Palette.Primary,
	}, Theme.Icons.Boost or "", Palette.Text)
	boostPill.Instance.Parent = gemRow
	boostPill.setVisible(false)

	local luckPill = Components.pill({
		Size = UDim2.fromOffset(130, 46),
		LayoutOrder = 3,
		BackgroundColor3 = Palette.Positive,
	}, Theme.Icons.Luck or "", Palette.Background)
	luckPill.Instance.Parent = gemRow
	luckPill.setVisible(false)

	local function statLine(order: number, color: Color3): TextLabel
		return Components.label({
			Text = "",
			Size = UDim2.fromOffset(300, 22),
			LayoutOrder = order,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			MaxTextSize = 20,
			Stroke = 2,
			Parent = stats,
		})
	end
	local incomeLabel = statLine(3, Palette.Positive)
	local detailLabel = statLine(4, Palette.TextMuted)

	-- Panels and the menu that opens them --------------------------------
	--
	-- Annotated because the entries differ in shape -- one is hidden from the menu
	-- and one has a setter the others don't -- and Luau would otherwise infer the
	-- whole list from the first one.
	type MenuEntry = {
		Name: string,
		Icon: string,
		-- The three things the menu and the snapshot loop need. A panel with more
		-- than these -- the egg panel has a setter of its own -- goes in narrowed to
		-- this shape and is kept in a local as well, because Luau will not assign a
		-- table with extra fields to a sealed type.
		Panel: {
			setOpen: (boolean) -> (),
			isOpen: () -> boolean,
			update: ({ [string]: any }) -> (),
		},
	}

	-- Kept out here because the prompt handler has to fill it in before opening it,
	-- which is more than the list's shape allows.
	local eggPanel = EggPanel.create(screen)

	-- The shop opens the admin panel from its own card, but the function that opens
	-- panels is built from this list, so the shop is handed a way to reach it later.
	local openByName: ((string) -> ())? = nil

	local panels: { MenuEntry } = {
		{ Name = "Upgrades", Icon = MENU_ICONS.Upgrades, Panel = UpgradesPanel.create(screen) },
		{
			Name = "Shop",
			Icon = MENU_ICONS.Shop,
			Panel = ShopPanel.create(screen, function()
				if openByName then
					openByName(ADMIN_PANEL)
				end
			end),
		},
		{ Name = "Quests", Icon = MENU_ICONS.Quests, Panel = QuestsPanel.create(screen) },
		{ Name = "Playtime", Icon = MENU_ICONS.Playtime, Panel = PlaytimePanel.create(screen) },
		{ Name = "Daily", Icon = MENU_ICONS.Daily, Panel = DailyPanel.create(screen) },
		{ Name = WHEEL_PANEL, Icon = MENU_ICONS.Wheel, Panel = WheelPanel.create(screen) },
		{ Name = CRAFT_PANEL, Icon = MENU_ICONS.Craft, Panel = CraftPanel.create(screen) },
		{ Name = "Pets", Icon = MENU_ICONS.Pets, Panel = PetsPanel.create(screen) },
		-- No menu button: it's about one egg pad, so the only way in is standing at
		-- one. It rides in this list anyway so it gets every snapshot like the rest.
		{
			Name = EGG_PANEL,
			Icon = "",
			Panel = { setOpen = eggPanel.setOpen, isOpen = eggPanel.isOpen, update = eggPanel.update },
		},
		-- Its menu button is in MENU below, and the shop's Admin card opens it too.
		{ Name = ADMIN_PANEL, Icon = "", Panel = AdminPanel.create(screen) },
		{ Name = STAFF_PANEL, Icon = "", Panel = StaffPanel.create(screen) },
		{ Name = "Ranks", Icon = MENU_ICONS.Ranks, Panel = LeaderboardPanel.create(screen) },
		{ Name = "Index", Icon = MENU_ICONS.Index, Panel = IndexPanel.create(screen) },
	}

	local panelByName: { [string]: MenuEntry } = {}
	for _, entry in panels do
		panelByName[entry.Name] = entry
	end

	-- The menu. Six buttons in a grid rather than a button per panel: a column of
	-- eleven ran off the bottom of a short screen, and a wall of them is slow to
	-- find anything in. Upgrades, the Shop and the ranks are one press. The rest
	-- are grouped by what a player is after -- free things to collect, and the
	-- things they own -- and pressing a group opens a tray of its panels beside
	-- it, over the world, without moving anything else on screen.
	--
	-- Rebirth isn't here. It's on the garden board, where the upgrades it resets
	-- are.
	type MenuSlot = {
		Name: string,
		Icon: string,
		-- One panel opens directly; more than one opens a tray of them.
		Opens: { string },
	}
	local MENU: { MenuSlot } = {
		{ Name = "Upgrades", Icon = MENU_ICONS.Upgrades, Opens = { "Upgrades" } },
		{ Name = "Shop", Icon = MENU_ICONS.Shop, Opens = { "Shop" } },
		{ Name = "Rewards", Icon = MENU_ICONS.Rewards, Opens = { "Daily", "Playtime", "Quests", WHEEL_PANEL } },
		{ Name = "Collection", Icon = MENU_ICONS.Collection, Opens = { "Pets", CRAFT_PANEL, "Index" } },
		{ Name = "Ranks", Icon = MENU_ICONS.Ranks, Opens = { "Ranks" } },
		-- Shown to everyone, not just admins. Anyone without the pass gets the panel
		-- with its commands greyed out and a pointer to the shop, which is the pitch.
		{ Name = "Admin", Icon = MENU_ICONS.Admin, Opens = { ADMIN_PANEL } },
		-- Staff only: hidden until the server says this player is one. Last, so
		-- hiding it never moves a tray's row.
		{ Name = "Staff", Icon = MENU_ICONS.Staff, Opens = { STAFF_PANEL } },
	}
	-- 76 square: comfortably above the size a thumb can hit reliably, with the
	-- name under it rather than beside it so two fit across.
	local CELL = 76
	local CELL_LABEL = 20
	local CELL_HEIGHT = CELL + 4 + CELL_LABEL
	local CELL_GAP = 10
	local COLUMNS = 2
	local TRAY_PADDING = 10

	-- How many things a panel has waiting to be collected. A group can only hide
	-- its panels if it says when one of them wants the player, so these roll up
	-- into the badge on the group's own button.
	local READY: { [string]: ({ [string]: any }) -> number } = {
		Daily = function(snapshot)
			local available = Economy.dailyStatus(snapshot.Data, snapshot.Now or os.time())
			return if available then 1 else 0
		end,
		Playtime = function(snapshot)
			local startedAt = snapshot.SessionStartedAt
			if not startedAt then
				return 0
			end
			local elapsed = math.max(Workspace:GetServerTimeNow() - startedAt, 0) * (snapshot.PlaytimeSpeed or 1)
			return Economy.playtimeReadyCount(elapsed, snapshot.PlaytimeClaimed or {})
		end,
		Quests = function(snapshot)
			local data: Types.PlayerData = snapshot.Data
			local count = 0
			for _, slot in data.Quests.Active do
				if Economy.questClaimable(data, slot) then
					count += 1
				end
			end
			return count
		end,
		[WHEEL_PANEL] = function(snapshot)
			return snapshot.SpinsAvailable or Economy.spinsAvailable(snapshot.Data, os.time())
		end,
		[CRAFT_PANEL] = function(snapshot)
			local data: Types.PlayerData = snapshot.Data
			local count = 0
			for slot = 1, math.min(snapshot.CraftSlots or 1, #data.Craft) do
				if Economy.craftReady(data.Craft[slot], os.time()) then
					count += 1
				end
			end
			return count
		end,
	}

	local function openPanel(name: string)
		local entry = panelByName[name]
		if not entry then
			return
		end
		local opening = not entry.Panel.isOpen()
		for _, other in panels do
			other.Panel.setOpen(false)
		end
		entry.Panel.setOpen(opening)
		Sound.play(Theme.Sounds.Purchase)
	end
	openByName = openPanel

	-- A square button with its name under it.
	local function menuCell(
		parent: Instance,
		name: string,
		icon: string,
		order: number,
		onClick: () -> ()
	): Components.Button
		local cell = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CELL, CELL_HEIGHT),
			LayoutOrder = order,
			Parent = parent,
		})
		local button = Components.button({
			Text = "",
			Size = UDim2.fromOffset(CELL, CELL),
			BackgroundColor3 = Palette.Secondary,
			MaxTextSize = 40,
			Parent = cell,
		}, onClick)
		button.setIcon(icon)
		button.Instance.Parent = cell
		Components.label({
			Text = name,
			-- A little wider than the button, so "Collection" isn't squeezed.
			Size = UDim2.new(1, 16, 0, CELL_LABEL),
			Position = UDim2.fromOffset(-8, CELL + 4),
			MaxTextSize = 18,
			Stroke = 2,
			Parent = cell,
		})
		return button
	end

	local menuArea = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(COLUMNS * CELL + (COLUMNS - 1) * CELL_GAP, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = column,
	})
	local grid = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = menuArea,
	})
	Components.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CELL, CELL_HEIGHT),
		CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
		FillDirectionMaxCells = COLUMNS,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	-- Every button that can carry a badge, by panel name for trays and by slot
	-- for the grid, so one pass can light them all.
	local panelButtons: { [string]: Components.Button } = {}
	local slotButtons: { [number]: Components.Button } = {}
	local trays: { Frame } = {}

	local function showTray(tray: Frame?)
		for _, other in trays do
			other.Visible = other == tray
		end
	end

	for order, slot in MENU do
		if #slot.Opens == 1 then
			local name = slot.Opens[1]
			local button = menuCell(grid, slot.Name, slot.Icon, order, function()
				showTray(nil)
				openPanel(name)
			end)
			slotButtons[order] = button
			panelButtons[name] = button
			continue
		end

		-- Beside the grid, level with the row its button is on.
		local row = (order - 1) // COLUMNS
		local tray: Frame = Components.card({
			Position = UDim2.fromOffset(
				COLUMNS * CELL + (COLUMNS - 1) * CELL_GAP + CELL_GAP,
				row * (CELL_HEIGHT + CELL_GAP) - TRAY_PADDING
			),
			Size = UDim2.fromOffset(0, CELL_HEIGHT + TRAY_PADDING * 2),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Palette.Background,
			Visible = false,
			Parent = menuArea,
		})
		Components.padding(TRAY_PADDING).Parent = tray
		Components.listLayout({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, CELL_GAP),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}).Parent =
			tray
		table.insert(trays, tray)

		for itemOrder, name in slot.Opens do
			local entry = panelByName[name]
			if entry then
				panelButtons[name] = menuCell(tray, entry.Name, entry.Icon, itemOrder, function()
					showTray(nil)
					openPanel(name)
				end)
			end
		end

		slotButtons[order] = menuCell(grid, slot.Name, slot.Icon, order, function()
			local opening = not tray.Visible
			showTray(if opening then tray else nil)
			Sound.play(Theme.Sounds.Purchase)
		end)
	end

	-- Hidden until a snapshot says otherwise, so it never flashes up for a frame.
	local staffCell = slotButtons[#MENU].Instance.Parent
	if staffCell and staffCell:IsA("GuiObject") then
		staffCell.Visible = false
	end

	-- A press out in the world closes an open tray, the way tapping away from any
	-- popover does. Presses on the HUD itself arrive as processed and are left to
	-- the buttons.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			showTray(nil)
		end
	end)

	local function refreshBadges(snapshot: { [string]: any })
		for order, slot in MENU do
			local total = 0
			for _, name in slot.Opens do
				local ready = READY[name]
				local count = if ready then ready(snapshot) else 0
				total += count
				local button = panelButtons[name]
				if button and #slot.Opens > 1 then
					button.setBadge(if count > 0 then tostring(count) else nil)
				end
			end
			slotButtons[order].setBadge(if total > 0 then tostring(total) else nil)
		end
	end

	-- Walking up to the wheel or the crafting station opens the same panel the
	-- menu does.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local wanted = PROMPT_PANELS[prompt.Name]
		if prompt.Name == EGG_PROMPT then
			local eggId = prompt:GetAttribute("Egg")
			if typeof(eggId) ~= "string" then
				return
			end
			-- Filled in before it's shown, so the first frame is already this egg's
			-- rather than the last one's.
			eggPanel.setEgg(eggId)
			wanted = EGG_PANEL
		end
		if not wanted then
			return
		end
		showTray(nil)
		for _, entry in panels do
			entry.Panel.setOpen(entry.Name == wanted)
		end
	end)

	-- Buy button and drop timer (bottom centre) --------------------------
	local bottom = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(360, 216),
		Parent = screen,
	})
	local carryLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 42),
		TextColor3 = Palette.Accent,
		TextWrapped = true,
		MaxTextSize = 22,
		Stroke = 2,
		Parent = bottom,
	})
	local dropLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 44),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 20,
		Stroke = 2,
		Parent = bottom,
	})
	local dropBar = Components.bar({
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = bottom,
	})
	local buyButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 62),
		Parent = bottom,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("BuyUnit"):FireServer()
	end)
	buyButton.setIcon(Theme.Icons.Currency or "")

	-- On-screen drop, so touch players (and anyone who'd rather click) have one.
	local dropButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 158),
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Palette.Secondary,
		Parent = bottom,
	}, function()
		Net.event("DropCarried"):FireServer()
	end)

	-- Selling at the bin (centre) ----------------------------------------
	local confirm = Confirm.create(screen)
	Net.event("SellPrompt").OnClientEvent:Connect(function(tier: number?, amount: number?)
		if not (tier and amount) then
			confirm.close()
			return
		end
		confirm.ask(`Sell your {Config.Units[tier].Name}?`, `+{Format.number(amount)} {Theme.Text.Currency}`, function()
			Sound.play(Theme.Sounds.Purchase)
			Net.event("SellCarried"):FireServer()
		end)
	end)

	-- Toasts (top centre) ------------------------------------------------
	-- Staff events running, and staff messages to the whole game.
	local eventStrip = EventStrip.create(screen)

	local toasts = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 200),
		ZIndex = Components.Layer.Toast,
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = toasts

	-- Three at a time. They arrive in bursts -- a merge, a quest claimed and a
	-- level all at once -- and a stack tall enough to reach the buy button is
	-- both unreadable and in the way. The oldest goes to make room, because the
	-- newest is the one that just happened.
	local live: { Frame } = {}
	local order = 0

	local function dismiss(card: Frame)
		local index = table.find(live, card)
		if index then
			table.remove(live, index)
		end
		card:Destroy()
	end

	local function toast(message: string, kind: string)
		while #live >= MAX_TOASTS do
			dismiss(live[1])
		end
		order += 1
		local card = Components.card({
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = TOAST_COLORS[kind] or Palette.Surface,
			-- Explicit, so the newest is always at the bottom of the stack
			-- rather than wherever the layout happened to put it.
			LayoutOrder = order,
			Parent = toasts,
		})
		table.insert(live, card)
		Components.label({
			Text = message,
			Size = UDim2.new(1, -20, 1, -8),
			Position = UDim2.fromOffset(10, 4),
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			Parent = card,
		})
		task.delay(TOAST_SECONDS, function()
			-- It may already have been pushed out by three newer ones.
			if not card.Parent then
				return
			end
			local fade = TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			dismiss(card)
		end)
	end

	-- Updates ------------------------------------------------------------
	local latest: { [string]: any }? = nil
	-- What the Bigger Garden pass adds, kept from the last snapshot: the drop
	-- timer runs every frame and reads the same capacity the buy button does.
	local spaces = 0

	State.onChange(function(snapshot)
		latest = snapshot
		local data: Types.PlayerData = snapshot.Data
		eventStrip.update(snapshot)
		if staffCell and staffCell:IsA("GuiObject") then
			staffCell.Visible = snapshot.IsStaff == true
		end

		cashPill.setText(Format.number(data.Cash))
		gemPill.setText(Format.number(data.Gems))
		incomeLabel.Text = `+{Format.number(snapshot.IncomePerSecond or 0)} {Theme.Text.Currency}/s`

		local capacity = snapshot.GardenCapacity or Economy.gardenCapacity(data)
		detailLabel.Text =
			`{Economy.usedSpace(data)}/{capacity} {Theme.Text.UnitPlural}  ·  {Theme.Text.Rebirth} x{Economy.rebirthMultiplier(
				data.Rebirths
			)}`

		-- What you're holding, what it would sell for, and -- when it's a tier
		-- that can no longer find a partner -- that the bin is now its only use.
		if data.Carried == 0 then
			carryLabel.Text = "Carrying nothing"
		elseif Economy.isSparkle(data.Carried) then
			carryLabel.Text = `Carrying {Config.Units[data.Carried].Name} ✨`
		else
			local line = `Carrying {Config.Units[data.Carried].Name}  ·  sells for {Format.number(
				Economy.binValue(data.Carried, Economy.petPerkValue(data, "SellBonus"))
			)} {Theme.Text.Currency}`
			if Economy.carriedIsStranded(data) then
				line ..= `\nNothing left to merge it with`
			end
			carryLabel.Text = line
		end

		local cost = Economy.buyUnitCost(data)
		-- The pass and a Gardener pet both add room, and both are readable from what
		-- the client already has: the pass from the snapshot, the pet from the save.
		spaces = Economy.gardenPassSpaces((snapshot.Passes or {}).BiggerGarden)
			+ math.floor(Economy.petPerkValue(data, "Space"))
		buyButton.setText(`Buy {Theme.Text.Unit} — {Format.number(cost)}`)
		buyButton.setEnabled(data.Cash >= cost and Economy.hasRoom(data, spaces))

		dropButton.setText(if data.Carried > 0 then "Drop  (Q)" else "Nothing to drop")
		dropButton.setEnabled(data.Carried > 0)

		for _, entry in panels do
			entry.Panel.update(snapshot)
		end
		refreshBadges(snapshot)
	end)

	-- The drop timer and the boost both count down between snapshots, and a
	-- playtime rung or a craft can come ready between them too.
	local sinceBadges = 0
	RunService.RenderStepped:Connect(function(delta)
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data

		sinceBadges += delta
		if sinceBadges >= 1 then
			sinceBadges = 0
			refreshBadges(snapshot)
		end

		local boostLeft = Economy.boostRemaining(data)
		boostPill.setVisible(boostLeft > 0)
		if boostLeft > 0 then
			boostPill.setText(`x{Config.Balance.Boost.Multiplier} {Format.time(boostLeft)}`)
		end

		local luckLeft = Economy.luckRemaining(data)
		luckPill.setVisible(luckLeft > 0)
		if luckLeft > 0 then
			luckPill.setText(Format.time(luckLeft))
		end

		if not Economy.hasRoom(data, spaces) then
			dropLabel.Text = "Garden full — merge to make room!"
			dropBar.setProgress(1)
			return
		end
		local interval = snapshot.DropInterval or 1
		local remaining = math.max((snapshot.NextDropAt or 0) - Workspace:GetServerTimeNow(), 0)
		dropLabel.Text = `Next {Theme.Text.Unit} in {Format.time(math.ceil(remaining))}`
		dropBar.setProgress(1 - remaining / interval)
	end)

	Net.event("Notify").OnClientEvent:Connect(toast)
	-- The server has already picked the pet and banked it; this is the ceremony.
	Net.event("PetHatched").OnClientEvent:Connect(Reveal.egg)
	Net.event("Announcement").OnClientEvent:Connect(eventStrip.announce)
end

return Hud
