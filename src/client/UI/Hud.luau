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
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Confirm = require(script.Parent.Confirm)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)

local CraftPanel = require(script.Parent.Panels.Craft)
local DailyPanel = require(script.Parent.Panels.Daily)
local IndexPanel = require(script.Parent.Panels.Index)
local LeaderboardPanel = require(script.Parent.Panels.Leaderboard)
local QuestsPanel = require(script.Parent.Panels.Quests)
local RebirthPanel = require(script.Parent.Panels.Rebirth)
local ShopPanel = require(script.Parent.Panels.Shop)
local UpgradesPanel = require(script.Parent.Panels.Upgrades)
local WheelPanel = require(script.Parent.Panels.Wheel)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local TOAST_SECONDS = 4
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
	Daily = "🎁",
	Quests = "📋",
	Wheel = "🎡",
	Craft = "⚗️",
	Ranks = "🏆",
	Index = "📖",
}
local WHEEL_PANEL = "Wheel"
local CRAFT_PANEL = "Craft"
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

	local gemPill = Components.pill({
		Size = UDim2.fromOffset(210, 46),
		LayoutOrder = 2,
	}, Theme.Icons.Gems or "", Palette.Secondary)
	gemPill.Instance.Parent = stats

	-- Only on screen while it's running, so a quiet HUD stays quiet.
	local boostPill = Components.pill({
		Size = UDim2.fromOffset(250, 46),
		LayoutOrder = 3,
		BackgroundColor3 = Palette.Primary,
	}, Theme.Icons.Boost or "", Palette.Text)
	boostPill.Instance.Parent = stats
	boostPill.setVisible(false)

	local luckPill = Components.pill({
		Size = UDim2.fromOffset(250, 46),
		LayoutOrder = 4,
		BackgroundColor3 = Palette.Positive,
	}, Theme.Icons.Luck or "", Palette.Background)
	luckPill.Instance.Parent = stats
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
	local incomeLabel = statLine(5, Palette.Positive)
	local detailLabel = statLine(6, Palette.TextMuted)

	-- Panels and the menu that opens them --------------------------------
	local panels = {
		{ Name = "Upgrades", Icon = MENU_ICONS.Upgrades, Panel = UpgradesPanel.create(screen) },
		{ Name = "Shop", Icon = MENU_ICONS.Shop, Panel = ShopPanel.create(screen) },
		{ Name = Theme.Text.Rebirth, Icon = "🔁", Panel = RebirthPanel.create(screen) },
		{ Name = "Quests", Icon = MENU_ICONS.Quests, Panel = QuestsPanel.create(screen) },
		{ Name = "Daily", Icon = MENU_ICONS.Daily, Panel = DailyPanel.create(screen) },
		{ Name = WHEEL_PANEL, Icon = MENU_ICONS.Wheel, Panel = WheelPanel.create(screen) },
		{ Name = CRAFT_PANEL, Icon = MENU_ICONS.Craft, Panel = CraftPanel.create(screen) },
		{ Name = "Ranks", Icon = MENU_ICONS.Ranks, Panel = LeaderboardPanel.create(screen) },
		{ Name = "Index", Icon = MENU_ICONS.Index, Panel = IndexPanel.create(screen) },
	}

	local menu = Components.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(148, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = column,
	})
	Components.listLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent =
		menu

	for order, entry in panels do
		-- 56 tall: comfortably above the size a thumb can hit reliably.
		local button = Components.button({
			Text = entry.Name,
			Size = UDim2.fromOffset(148, 56),
			LayoutOrder = order,
			BackgroundColor3 = Palette.Secondary,
			Parent = menu,
		}, function()
			local opening = not entry.Panel.isOpen()
			for _, other in panels do
				other.Panel.setOpen(false)
			end
			entry.Panel.setOpen(opening)
			Sound.play(Theme.Sounds.Purchase)
		end)
		button.setIcon(entry.Icon)
		button.Instance.Parent = menu
	end

	-- Walking up to the wheel or the crafting station opens the same panel the
	-- menu does.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local wanted = PROMPT_PANELS[prompt.Name]
		if not wanted then
			return
		end
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
	local toasts = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 200),
		ZIndex = Components.Layer.Toast,
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = toasts

	local function toast(message: string, kind: string)
		local card = Components.card({
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = TOAST_COLORS[kind] or Palette.Surface,
			Parent = toasts,
		})
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
			local fade = TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			card:Destroy()
		end)
	end

	-- Updates ------------------------------------------------------------
	local latest: { [string]: any }? = nil

	State.onChange(function(snapshot)
		latest = snapshot
		local data: Types.PlayerData = snapshot.Data

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
				Economy.binValue(data.Carried)
			)} {Theme.Text.Currency}`
			if Economy.carriedIsStranded(data) then
				line ..= `\nNothing left to merge it with`
			end
			carryLabel.Text = line
		end

		local cost = Economy.buyUnitCost(data)
		buyButton.setText(`Buy {Theme.Text.Unit} — {Format.number(cost)}`)
		buyButton.setEnabled(data.Cash >= cost and Economy.hasRoom(data))

		dropButton.setText(if data.Carried > 0 then "Drop  (Q)" else "Nothing to drop")
		dropButton.setEnabled(data.Carried > 0)

		for _, entry in panels do
			entry.Panel.update(snapshot)
		end
	end)

	-- The drop timer and the boost both count down between snapshots.
	RunService.RenderStepped:Connect(function()
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data

		local boostLeft = Economy.boostRemaining(data)
		boostPill.setVisible(boostLeft > 0)
		if boostLeft > 0 then
			boostPill.setText(`x{Config.Balance.Boost.Multiplier}  {Format.time(boostLeft)}`)
		end

		local luckLeft = Economy.luckRemaining(data)
		luckPill.setVisible(luckLeft > 0)
		if luckLeft > 0 then
			luckPill.setText(`Lucky  {Format.time(luckLeft)}`)
		end

		if not Economy.hasRoom(data) then
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
end

return Hud
