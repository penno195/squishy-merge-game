--!strict
-- Upgrade purchases and rebirths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local GameplayService = require(script.Parent.GameplayService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)

local Theme = Config.Theme

local ShopService = {}

local function buyUpgrade(player: Player, id: any)
	if typeof(id) ~= "string" or not Economy.getUpgrade(id) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local level = Economy.upgradeLevel(data, id)
	if level >= Economy.upgradeMaxLevel(id) then
		StateService.notify(player, "That upgrade is maxed out!", "Error")
		return
	end
	local cost = Economy.upgradeCost(id, level)
	if data.Cash < cost then
		StateService.notify(player, `Not enough {Theme.Text.Currency}!`, "Error")
		return
	end
	data.Cash -= cost
	data.Upgrades[id] = level + 1
	StateService.markDirty(player)
end

-- The timed earning boost, paid for in gems. Buying again while one is running
-- extends it rather than throwing the remaining time away.
local function buyBoost(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.boostCost()
	if data.Gems < cost then
		StateService.notify(player, `You need {cost} Gems for that boost!`, "Error")
		return
	end
	data.Gems -= cost
	local now = os.time()
	data.BoostEndsAt = math.max(data.BoostEndsAt, now) + Economy.boostSeconds()
	StateService.markDirty(player)
	StateService.notify(
		player,
		`Earning boost active! x{Config.Balance.Boost.Multiplier} {Theme.Text.Currency} for {Format.time(
			data.BoostEndsAt - now
		)}.`,
		"Reward"
	)
end

local function rebirth(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.rebirthCost(data.Rebirths)
	if data.Cash < cost then
		StateService.notify(
			player,
			`You need {Format.number(cost)} {Theme.Text.Currency} to {Theme.Text.Rebirth}!`,
			"Error"
		)
		return
	end

	data.Rebirths += 1
	-- Gems and any running boost survive a rebirth: they're premium, not progress.
	data.Gems += Config.Balance.Gems.PerRebirth
	data.Cash = Config.Balance.StartingCash
	data.Items = Economy.startingItems()
	data.Carried = 0
	data.Upgrades = {}
	data.UnitsBought = 0

	ItemService.renderFromData(player, data)
	GameplayService.resetDropTimer(player)
	StateService.markDirty(player)
	local multiplier = Economy.rebirthMultiplier(data.Rebirths)
	StateService.notify(
		player,
		`{Theme.Text.Rebirth} complete! You now earn x{multiplier} {Theme.Text.Currency}, plus {Config.Balance.Gems.PerRebirth} Gems.`,
		"Rebirth"
	)
end

function ShopService.init()
	Net.event("BuyUpgrade").OnServerEvent:Connect(buyUpgrade)
	Net.event("BuyBoost").OnServerEvent:Connect(buyBoost)
	Net.event("Rebirth").OnServerEvent:Connect(rebirth)
end

return ShopService
