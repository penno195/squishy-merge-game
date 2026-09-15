--!strict
-- Upgrade purchases and rebirths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local GameplayService = require(script.Parent.GameplayService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
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
	ActionService.fire(player, "Upgraded", { Value = level + 1, CashSpent = cost, Fields = { Upgrade = id } })
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
	ActionService.fire(player, "BoostBought", { Value = Economy.boostSeconds(), GemsSpent = cost })
end

-- Luck, on the same terms as the boost: gems, timed, and buying again while
-- one is running extends it rather than throwing the rest away.
local function buyLuck(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Refused rather than sold. The pass is the same tilt, permanently, so gems
	-- spent on a charm on top of it buy precisely nothing -- and a shop that
	-- takes them anyway is a shop that cheated them.
	if PassService.luckBias(player) then
		StateService.notify(player, "Your lucky charm is permanent -- no need to buy another!", "Info")
		return
	end
	local cost = Economy.luckCost()
	if data.Gems < cost then
		StateService.notify(player, `You need {cost} Gems for a lucky charm!`, "Error")
		return
	end
	data.Gems -= cost
	local now = os.time()
	data.LuckEndsAt = math.max(data.LuckEndsAt, now) + Economy.luckSeconds()
	StateService.markDirty(player)
	local chance = math.floor(Economy.topTierChance(data, PassService.luckBias(player)) * 100 + 0.5)
	StateService.notify(
		player,
		`Lucky charm active! {chance}% of drops are top tier for {Format.time(data.LuckEndsAt - now)}.`,
		"Reward"
	)
	ActionService.fire(player, "LuckBought", { Value = Economy.luckSeconds(), GemsSpent = cost })
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
	-- The other half of the gate: the garden has to have climbed, not just
	-- banked. Checked after cash so the message names the thing still missing.
	local requiredTier = Economy.rebirthTier(data.Rebirths)
	if not Economy.rebirthTierMet(data) then
		StateService.notify(
			player,
			`You also need a {Config.Units[requiredTier].Name} to {Theme.Text.Rebirth}. Keep merging!`,
			"Error"
		)
		return
	end

	data.Rebirths += 1
	-- Gems, anything still running on a gem clock and the sparkles survive a
	-- rebirth: they're premium or limited edition, not progress. So does
	-- whatever is in the crafting station, which is a clock rather than
	-- something owned.
	data.Gems += Config.Balance.Gems.PerRebirth
	data.Cash = Config.Balance.StartingCash
	data.Items = Economy.itemsAfterRebirth(data.Items)
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
	ActionService.fire(player, "Rebirthed", {
		Value = data.Rebirths,
		CashSpent = cost,
		Gems = Config.Balance.Gems.PerRebirth,
	})
end

function ShopService.init()
	Net.event("BuyUpgrade").OnServerEvent:Connect(buyUpgrade)
	Net.event("BuyBoost").OnServerEvent:Connect(buyBoost)
	Net.event("BuyLuck").OnServerEvent:Connect(buyLuck)
	Net.event("Rebirth").OnServerEvent:Connect(rebirth)
end

return ShopService
