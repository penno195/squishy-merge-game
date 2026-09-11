--!strict
-- The upgrade rows, shared by the Upgrades panel and the garden's upgrade
-- board so the two can never drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local UpgradeList = {}

export type List = {
	update: ({ [string]: any }) -> (),
}

-- What the upgrade does right now, in the theme's own words.
local function describe(id: string, data: Types.PlayerData, passes: { [string]: boolean }): string
	if id == "SpawnSpeed" then
		local passMultiplier = if passes.FastSpawn then Config.Balance.Monetisation.FastSpawnMultiplier else 1
		local interval = Economy.dropInterval(data, passMultiplier)
		return `A {Theme.Text.Unit} drops every {string.format("%.1f", interval)}s`
	elseif id == "SpawnTier" then
		return `Drops arrive as {Theme.Units[Economy.dropTier(data)].Name}`
	elseif id == "GardenSpace" then
		return `Garden holds {Economy.gardenCapacity(data)} {Theme.Text.UnitPlural}`
	elseif id == "Income" then
		local upgrade = Economy.getUpgrade("Income")
		local multiplier = 1 + Economy.upgradeLevel(data, "Income") * upgrade.PerLevel
		return `Earning x{string.format("%.2f", multiplier)} {Theme.Text.Currency}`
	end
	return ""
end

function UpgradeList.create(parent: Instance): List
	local list = Components.scroller({ Size = UDim2.fromScale(1, 1), Parent = parent })
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	local rows = {}
	for order, upgrade in Config.Balance.Upgrades do
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, 80),
			LayoutOrder = order,
			Parent = list,
		})
		local title = Components.label({
			Text = upgrade.Name,
			Size = UDim2.new(0.55, 0, 0, 28),
			Position = UDim2.fromOffset(12, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local detail = Components.label({
			Text = "",
			Size = UDim2.new(0.55, 0, 0, 24),
			Position = UDim2.fromOffset(12, 42),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.TextMuted,
			Parent = card,
		})
		local button = Components.button({
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 56),
			Parent = card,
		}, function()
			Sound.play(Theme.Sounds.Purchase)
			Net.event("BuyUpgrade"):FireServer(upgrade.Id)
		end)
		rows[upgrade.Id] = { Title = title, Detail = detail, Button = button }
	end

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local passes = snapshot.Passes or {}
		for id, row in rows do
			local level = Economy.upgradeLevel(data, id)
			local maxLevel = Economy.upgradeMaxLevel(id)
			row.Title.Text = `{Economy.getUpgrade(id).Name}  ·  Lv {level}`
			row.Detail.Text = describe(id, data, passes)
			if level >= maxLevel then
				row.Button.setText("MAXED")
				row.Button.setEnabled(false)
			else
				local cost = Economy.upgradeCost(id, level)
				row.Button.setText(`{Format.number(cost)} {Theme.Text.Currency}`)
				row.Button.setEnabled(data.Cash >= cost)
			end
		end
	end

	return { update = update }
end

return UpgradeList
