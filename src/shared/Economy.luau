--!strict
-- Pure economy formulas shared by server (authoritative) and client (display).

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Balance = Config.Balance

local Economy = {}

local upgradeById = {}
for _, upgrade in Balance.Upgrades do
	upgradeById[upgrade.Id] = upgrade
end

-- Upgrades ---------------------------------------------------------------

function Economy.getUpgrade(id: string)
	return upgradeById[id]
end

function Economy.upgradeLevel(data: Types.PlayerData, id: string): number
	return data.Upgrades[id] or 0
end

function Economy.upgradeCost(id: string, level: number): number
	local upgrade = upgradeById[id]
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level)
end

-- Some upgrades are capped by the theme/balance (a theme with few tiers can't
-- raise the drop tier as far).
function Economy.upgradeMaxLevel(id: string): number
	local upgrade = upgradeById[id]
	if id == "SpawnTier" then
		return math.min(upgrade.MaxLevel, Config.MaxTier - 2)
	elseif id == "GardenSpace" then
		return math.min(upgrade.MaxLevel, #Balance.GardenCapacities - 1)
	end
	return upgrade.MaxLevel
end

-- Garden -----------------------------------------------------------------

function Economy.gardenCapacity(data: Types.PlayerData): number
	local level = math.clamp(Economy.upgradeLevel(data, "GardenSpace"), 0, #Balance.GardenCapacities - 1)
	return Balance.GardenCapacities[level + 1]
end

-- A carried item still takes up its space in the garden, so putting it back
-- down is always possible.
function Economy.usedSpace(data: Types.PlayerData): number
	return #data.Items + (if data.Carried > 0 then 1 else 0)
end

function Economy.hasRoom(data: Types.PlayerData): boolean
	return Economy.usedSpace(data) < Economy.gardenCapacity(data)
end

-- New players (and rebirths) start with a mergeable pair on the ground.
function Economy.startingItems(): { number }
	return { 1, 1 }
end

-- Income -----------------------------------------------------------------

function Economy.tierIncome(tier: number): number
	return Balance.Income.Base * Balance.Income.TierGrowth ^ (tier - 1)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Balance.Rebirth.MultiplierPerRebirth
end

-- `passMultiplier` comes from gamepasses the server has verified.
function Economy.cashMultiplier(data: Types.PlayerData, passMultiplier: number): number
	local upgrade = upgradeById.Income
	local upgradeBonus = 1 + Economy.upgradeLevel(data, "Income") * upgrade.PerLevel
	return upgradeBonus * Economy.rebirthMultiplier(data.Rebirths) * passMultiplier
end

-- Only items lying in the garden earn; whatever the player is carrying doesn't.
function Economy.incomePerSecond(data: Types.PlayerData, passMultiplier: number): number
	local base = 0
	for _, tier in data.Items do
		base += Economy.tierIncome(tier)
	end
	return base * Economy.cashMultiplier(data, passMultiplier)
end

-- Rewards defined as "minutes of current income" with a floor.
function Economy.incomeReward(incomePerSecond: number, incomeMinutes: number, minCash: number): number
	return math.max(math.floor(incomePerSecond * incomeMinutes * 60), minCash)
end

function Economy.offlineEarnings(incomePerSecond: number, secondsAway: number): number
	local offline = Balance.OfflineEarnings
	if secondsAway < offline.MinSeconds then
		return 0
	end
	local seconds = math.min(secondsAway, offline.MaxHours * 3600)
	return math.floor(incomePerSecond * seconds * offline.Rate)
end

-- Drops & buying ---------------------------------------------------------

-- Capped below the top tier so a dropped item can always still merge.
function Economy.dropTier(data: Types.PlayerData): number
	return math.min(1 + Economy.upgradeLevel(data, "SpawnTier"), Config.MaxTier - 1)
end

function Economy.dropInterval(data: Types.PlayerData, passMultiplier: number): number
	local drop = Balance.Drop
	local interval = drop.BaseInterval * drop.Factor ^ Economy.upgradeLevel(data, "SpawnSpeed")
	return math.max(interval * passMultiplier, drop.MinInterval)
end

function Economy.buyUnitCost(data: Types.PlayerData): number
	local buy = Balance.BuyUnit
	local tierScale = Balance.Income.TierGrowth ^ (Economy.dropTier(data) - 1)
	return math.floor(buy.BaseCost * tierScale * buy.Growth ^ data.UnitsBought)
end

-- Rebirth ----------------------------------------------------------------

function Economy.rebirthCost(rebirths: number): number
	return math.floor(Balance.Rebirth.BaseCost * Balance.Rebirth.Growth ^ rebirths)
end

-- Daily rewards ----------------------------------------------------------

function Economy.currentDay(now: number): number
	return now // 86400
end

-- Returns whether a claim is available and which streak day (1-based) it would be.
function Economy.dailyStatus(data: Types.PlayerData, now: number): (boolean, number)
	local today = Economy.currentDay(now)
	local daily = data.Daily
	if daily.LastClaimDay == today then
		return false, daily.Streak
	end
	local continues = daily.LastClaimDay == today - 1
	local streak = if continues then daily.Streak % #Balance.DailyRewards + 1 else 1
	return true, streak
end

return Economy
