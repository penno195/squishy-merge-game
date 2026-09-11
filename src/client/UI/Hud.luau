--!strict
-- The heads-up display: currency, income, what you're carrying, the drop
-- timer, the buy button, the menu that opens each panel, and toasts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)

local DailyPanel = require(script.Parent.Panels.Daily)
local IndexPanel = require(script.Parent.Panels.Index)
local LeaderboardPanel = require(script.Parent.Panels.Leaderboard)
local RebirthPanel = require(script.Parent.Panels.Rebirth)
local ShopPanel = require(script.Parent.Panels.Shop)
local UpgradesPanel = require(script.Parent.Panels.Upgrades)

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

local Hud = {}

function Hud.start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screen: ScreenGui = Components.new("ScreenGui", {
		Name = "MergeHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
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

	-- Stats card (top left) ----------------------------------------------
	local statsCard = Components.card({
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(280, 148),
		Parent = screen,
	})
	local function statLine(height: number, y: number, color: Color3): TextLabel
		return Components.label({
			Text = "",
			Size = UDim2.new(1, -20, 0, height),
			Position = UDim2.fromOffset(10, y),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Parent = statsCard,
		})
	end
	local cashLabel = statLine(40, 6, Palette.Text)
	local incomeLabel = statLine(24, 46, Palette.Positive)
	local rebirthLabel = statLine(22, 72, Palette.TextMuted)
	local itemsLabel = statLine(22, 94, Palette.TextMuted)
	local carryLabel = statLine(24, 118, Palette.Accent)

	-- Panels and the menu that opens them --------------------------------
	local panels = {
		{ Name = "Upgrades", Panel = UpgradesPanel.create(screen) },
		{ Name = "Shop", Panel = ShopPanel.create(screen) },
		{ Name = Theme.Text.Rebirth, Panel = RebirthPanel.create(screen) },
		{ Name = "Daily", Panel = DailyPanel.create(screen) },
		{ Name = "Ranks", Panel = LeaderboardPanel.create(screen) },
		{ Name = "Index", Panel = IndexPanel.create(screen) },
	}

	local menu = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(120, 360),
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left }).Parent =
		menu

	for order, entry in panels do
		local button = Components.button({
			Text = entry.Name,
			Size = UDim2.fromOffset(120, 48),
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
		button.Instance.Parent = menu
	end

	-- Buy button and drop timer (bottom centre) --------------------------
	local bottom = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(340, 172),
		Parent = screen,
	})
	local dropLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Palette.TextMuted,
		Parent = bottom,
	})
	local dropBar = Components.bar({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = bottom,
	})
	local buyButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 60),
		Parent = bottom,
	}, function()
		Sound.play(Theme.Sounds.Purchase)
		Net.event("BuyUnit"):FireServer()
	end)

	-- On-screen drop, so touch players (and anyone who'd rather click) have one.
	local dropButton = Components.button({
		Text = "",
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Palette.Secondary,
		Parent = bottom,
	}, function()
		Net.event("DropCarried"):FireServer()
	end)

	-- Toasts (top centre) ------------------------------------------------
	local toasts = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(420, 200),
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = toasts

	local function toast(message: string, kind: string)
		local card = Components.card({
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = TOAST_COLORS[kind] or Palette.Surface,
			Parent = toasts,
		})
		Components.label({
			Text = message,
			Size = UDim2.new(1, -16, 1, -8),
			Position = UDim2.fromOffset(8, 4),
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

		cashLabel.Text = `{Format.number(data.Cash)} {Theme.Text.Currency}`
		incomeLabel.Text = `+{Format.number(snapshot.IncomePerSecond or 0)}/s`
		rebirthLabel.Text = `{Theme.Text.Rebirth}s: {data.Rebirths} (x{Economy.rebirthMultiplier(data.Rebirths)})`
		itemsLabel.Text =
			`{Theme.Text.UnitPlural}: {Economy.usedSpace(data)} / {snapshot.GardenCapacity or Economy.gardenCapacity(
				data
			)}`
		carryLabel.Text = if data.Carried > 0
			then `Carrying: {Theme.Units[data.Carried].Name}  (Q or G to drop)`
			else "Carrying: nothing"

		local cost = Economy.buyUnitCost(data)
		buyButton.setText(`Buy {Theme.Text.Unit} — {Format.number(cost)}`)
		buyButton.setEnabled(data.Cash >= cost and Economy.hasRoom(data))

		dropButton.setText(if data.Carried > 0 then `Drop {Theme.Units[data.Carried].Name}  (Q)` else "Nothing to drop")
		dropButton.setEnabled(data.Carried > 0)

		for _, entry in panels do
			entry.Panel.update(snapshot)
		end
	end)

	-- The drop timer runs between snapshots.
	RunService.RenderStepped:Connect(function()
		local snapshot = latest
		if not snapshot then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		if not Economy.hasRoom(data) then
			dropLabel.Text = "Garden full — merge to make room!"
			dropBar.setProgress(1)
			return
		end
		local interval = snapshot.DropInterval or 1
		local remaining = math.max((snapshot.NextDropAt or 0) - Workspace:GetServerTimeNow(), 0)
		dropLabel.Text = `Next {Theme.Text.Unit} drops in {Format.time(math.ceil(remaining))}`
		dropBar.setProgress(1 - remaining / interval)
	end)

	Net.event("Notify").OnClientEvent:Connect(toast)
end

return Hud
