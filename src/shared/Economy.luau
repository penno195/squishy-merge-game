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

-- Sparkles ---------------------------------------------------------------
-- A unit index above the merge ladder is one of the theme's sparkles. Keeping
-- the test in one place is what lets the rest of the game treat them as units.

function Economy.isSparkle(index: number): boolean
	return index > Config.MaxTier
end

function Economy.sparkleAt(index: number): Types.SparkleDef?
	return Config.Sparkles[index - Config.MaxTier]
end

-- The unit index of the sparkle at position `position` in the theme's list.
function Economy.sparkleIndex(position: number): number
	return Config.MaxTier + position
end

-- Everything the player's sparkles add to their cash multiplier. Counted off
-- the collection record rather than what's lying in the garden, so each
-- distinct sparkle pays once however many of it have been made: the bonus
-- belongs to the trophy on the plinth, and a second copy is just another very
-- good unit. Once earned it's permanent, rebirths included.
function Economy.sparkleBonus(data: Types.PlayerData): number
	local bonus = 0
	for _, sparkle in Config.Sparkles do
		if (data.Sparkles[sparkle.Id] or 0) > 0 then
			bonus += sparkle.Bonus
		end
	end
	return bonus
end

function Economy.hasSparkle(data: Types.PlayerData, id: string): boolean
	return (data.Sparkles[id] or 0) > 0
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

-- What survives a rebirth: the sparkles, which are limited editions rather than
-- progress, plus the usual starting pair.
function Economy.itemsAfterRebirth(items: { number }): { number }
	local kept = Economy.startingItems()
	for _, index in items do
		if Economy.isSparkle(index) then
			table.insert(kept, index)
		end
	end
	return kept
end

-- Earning boost & gems ---------------------------------------------------

function Economy.boostCost(): number
	return Balance.Boost.GemCost
end

function Economy.boostSeconds(): number
	return Balance.Boost.Seconds
end

function Economy.boostRemaining(data: Types.PlayerData, now: number?): number
	return math.max(data.BoostEndsAt - (now or os.time()), 0)
end

function Economy.boostActive(data: Types.PlayerData, now: number?): boolean
	return Economy.boostRemaining(data, now) > 0
end

function Economy.boostMultiplier(data: Types.PlayerData, now: number?): number
	return if Economy.boostActive(data, now) then Balance.Boost.Multiplier else 1
end

-- Luck is the boost's twin: bought with gems, runs on a clock, and does
-- nothing once it lapses. What it buys is a tilt on the drop roll rather than
-- a cash multiplier, so it's spent in Economy.dropTierChances.

function Economy.luckCost(): number
	return Balance.Luck.GemCost
end

function Economy.luckSeconds(): number
	return Balance.Luck.Seconds
end

function Economy.luckRemaining(data: Types.PlayerData, now: number?): number
	return math.max(data.LuckEndsAt - (now or os.time()), 0)
end

function Economy.luckActive(data: Types.PlayerData, now: number?): boolean
	return Economy.luckRemaining(data, now) > 0
end

-- Income -----------------------------------------------------------------

-- Takes any unit index. A sparkle earns like an ordinary unit a few tiers above
-- the top of its band, which puts it above anything else a craft can produce.
function Economy.tierIncome(tier: number): number
	local sparkle = Economy.sparkleAt(tier)
	if sparkle then
		tier = sparkle.Band[2] + Balance.Craft.SparkleIncomeTiers
	end
	return Balance.Income.Base * Balance.Income.TierGrowth ^ (tier - 1)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Balance.Rebirth.MultiplierPerRebirth
end

-- `passMultiplier` comes from gamepasses the server has verified. Pass
-- `boostMultiplier` to override the timed boost -- offline earnings pass 1, so
-- a boost bought before logging off can't multiply hours of away time.
function Economy.cashMultiplier(data: Types.PlayerData, passMultiplier: number, boostMultiplier: number?): number
	local upgrade = upgradeById.Income
	local upgradeBonus = 1 + Economy.upgradeLevel(data, "Income") * upgrade.PerLevel
	return upgradeBonus
		* (1 + Economy.sparkleBonus(data))
		* Economy.rebirthMultiplier(data.Rebirths)
		* passMultiplier
		* (boostMultiplier or Economy.boostMultiplier(data))
end

-- Only items lying in the garden earn; whatever the player is carrying doesn't.
function Economy.incomePerSecond(data: Types.PlayerData, passMultiplier: number, boostMultiplier: number?): number
	local base = 0
	for _, tier in data.Items do
		base += Economy.tierIncome(tier)
	end
	return base * Economy.cashMultiplier(data, passMultiplier, boostMultiplier)
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

-- The average wait between drops.
function Economy.dropInterval(data: Types.PlayerData, passMultiplier: number): number
	local drop = Balance.Drop
	local interval = drop.BaseInterval * drop.Factor ^ Economy.upgradeLevel(data, "SpawnSpeed")
	return math.max(interval * passMultiplier, drop.MinInterval)
end

-- One actual wait, scattered around the average.
function Economy.randomDropInterval(data: Types.PlayerData, passMultiplier: number): number
	local jitter = Balance.Drop.Jitter
	local spread = 1 + (math.random() * 2 - 1) * jitter
	return math.max(Economy.dropInterval(data, passMultiplier) * spread, Balance.Drop.MinInterval / 2)
end

-- How hard Luck tilts the pyramid toward its top. 0 -- the base weights -- for
-- as long as no charm is running.
function Economy.luckBias(data: Types.PlayerData, now: number?): number
	return if Economy.luckActive(data, now) then Balance.Luck.Bias else 0
end

-- The tiers a drop can roll: the drop tier and the rungs below it, so an
-- upgraded garden still receives the lower tiers it needs to merge with. A
-- short window (early on, near tier 1) uses the bottom of the weight list.
function Economy.dropTierRange(data: Types.PlayerData): (number, number)
	local top = Economy.dropTier(data)
	return math.max(1, top - (#Balance.Drop.TierWeights - 1)), top
end

-- The chance of each tier in that window, lowest first. Luck multiplies every
-- rung up the pyramid by (1 + bias), so it lifts the rare top tiers steeply
-- without ever making any tier impossible to roll.
--
-- `bias` overrides the player's own: the board passes the charm's bias in to
-- quote what buying one would do, rather than what is happening now.
function Economy.dropTierChances(data: Types.PlayerData, bias: number?): { number }
	local bottom, top = Economy.dropTierRange(data)
	local weights = Balance.Drop.TierWeights
	local tilt = bias or Economy.luckBias(data)
	local chances = {}
	local total = 0
	for rung = 1, top - bottom + 1 do
		local weight = (weights[rung] or weights[#weights]) * (1 + tilt) ^ (rung - 1)
		chances[rung] = weight
		total += weight
	end
	for rung, weight in chances do
		chances[rung] = weight / total
	end
	return chances
end

function Economy.randomDropTier(data: Types.PlayerData): number
	local bottom, top = Economy.dropTierRange(data)
	local roll = math.random()
	for rung, chance in Economy.dropTierChances(data) do
		roll -= chance
		if roll <= 0 then
			return bottom + rung - 1
		end
	end
	-- Only reachable through floating-point drift on the last rung.
	return top
end

-- The chance a drop rolls the very top tier, which is what Luck is really
-- buying, and what the garden board quotes.
function Economy.topTierChance(data: Types.PlayerData, bias: number?): number
	local chances = Economy.dropTierChances(data, bias)
	return chances[#chances]
end

-- Buying and binning -----------------------------------------------------

-- The base price of a tier, before the inflation from units already bought.
-- Both the buy button and the bin are priced off this, so the two can't drift
-- into a loop where binning a bought unit turns a profit.
function Economy.unitValue(tier: number): number
	return Balance.BuyUnit.BaseCost * Balance.Income.TierGrowth ^ (tier - 1)
end

function Economy.binValue(tier: number): number
	return math.floor(Economy.unitValue(tier) * Balance.Bin.Refund)
end

-- True when the carried unit can never be merged again: nothing on the ground
-- matches it, and drops have moved past its tier so no partner is coming. This
-- is the case the bin exists for.
function Economy.carriedIsStranded(data: Types.PlayerData): boolean
	if data.Carried == 0 then
		return false
	end
	local bottom = Economy.dropTierRange(data)
	if data.Carried >= bottom then
		return false
	end
	for _, tier in data.Items do
		if tier == data.Carried then
			return false
		end
	end
	return true
end

function Economy.buyUnitCost(data: Types.PlayerData): number
	local value = Economy.unitValue(Economy.dropTier(data))
	return math.floor(value * Balance.BuyUnit.Growth ^ data.UnitsBought)
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
-- (see below for the wheel, which shares this module's day boundary)
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

-- Prize wheel -------------------------------------------------------------
-- Placed after the daily section because it reuses `currentDay`, so a free
-- spin and a daily reward roll over at the same moment.

function Economy.spinCost(): number
	return Balance.Wheel.GemCost
end

function Economy.freeSpinAvailable(data: Types.PlayerData, now: number): boolean
	return data.LastFreeSpinDay ~= Economy.currentDay(now)
end

-- Free spin included, so the UI can show one number.
function Economy.spinsAvailable(data: Types.PlayerData, now: number): number
	return data.Spins + (if Economy.freeSpinAvailable(data, now) then Balance.Wheel.FreeSpinsPerDay else 0)
end

function Economy.prizeChance(index: number): number
	local total = 0
	for _, prize in Balance.Wheel.Prizes do
		total += prize.Weight
	end
	return Balance.Wheel.Prizes[index].Weight / total
end

-- Picks a prize by weight and returns its index into Balance.Wheel.Prizes.
function Economy.rollPrize(): number
	local prizes = Balance.Wheel.Prizes
	local total = 0
	for _, prize in prizes do
		total += prize.Weight
	end
	local roll = math.random() * total
	for index, prize in prizes do
		roll -= prize.Weight
		if roll <= 0 then
			return index
		end
	end
	-- Only reachable through floating-point drift on the last prize.
	return #prizes
end

-- Crafting station --------------------------------------------------------
-- Pure odds, so the panel can show the player exactly what the server will
-- roll. Every outcome is a unit index, and the chances always add up to 1.

export type CraftOutcome = {
	Index: number,
	Chance: number,
	Sparkle: boolean,
}

function Economy.craftSlots(): number
	return Balance.Craft.Slots
end

function Economy.craftSeconds(): number
	return Balance.Craft.Seconds
end

-- The highest ordinary tier in the machine. Everything about a craft is
-- measured from this: which sparkle is in play, and what comes out instead.
local function highestInput(inputs: { number }): number
	local highest = 0
	for _, tier in inputs do
		highest = math.max(highest, tier)
	end
	return highest
end

-- Which sparkle a load is playing for: the one whose band holds the best unit
-- in the machine. Padding a high band with low-tier fodder still plays for the
-- high sparkle, and the odds below take care of how badly.
function Economy.craftSparkleIndex(inputs: { number }): number?
	local highest = highestInput(inputs)
	if highest == 0 then
		return nil
	end
	for position, sparkle in Config.Sparkles do
		if highest >= sparkle.Band[1] and highest <= sparkle.Band[2] then
			return Economy.sparkleIndex(position)
		end
	end
	return nil
end

-- How close a load is to the best one that band can be given: every slot
-- filled with the band's top tier. A unit below the band still counts, just
-- fractionally, which is what makes topping up with fodder barely move it.
function Economy.craftProgress(inputs: { number }, sparkle: Types.SparkleDef): number
	local craft = Balance.Craft
	local bottom, top = sparkle.Band[1], sparkle.Band[2]
	local best = craft.Slots * craft.TierWeight ^ (top - bottom)
	local total = 0
	for _, tier in inputs do
		total += craft.TierWeight ^ (tier - bottom)
	end
	return math.clamp(total / best, 0, 1)
end

function Economy.craftSparkleChance(inputs: { number }, sparkle: Types.SparkleDef): number
	local craft = Balance.Craft
	local ceiling = sparkle.MaxChance or craft.MaxChance
	local progress = Economy.craftProgress(inputs, sparkle)
	return math.min(craft.MinChance + (ceiling - craft.MinChance) * progress ^ craft.Curve, ceiling)
end

-- The sparkle first, then the ordinary units that share out the rest. An empty
-- machine has no outcomes at all.
function Economy.craftOutcomes(inputs: { number }): { CraftOutcome }
	local outcomes: { CraftOutcome } = {}
	local highest = highestInput(inputs)
	if highest == 0 then
		return outcomes
	end

	local sparkleChance = 0
	local sparkleIndex = Economy.craftSparkleIndex(inputs)
	if sparkleIndex then
		local sparkle = Economy.sparkleAt(sparkleIndex) :: Types.SparkleDef
		sparkleChance = Economy.craftSparkleChance(inputs, sparkle)
		table.insert(outcomes, { Index = sparkleIndex, Chance = sparkleChance, Sparkle = true })
	end

	-- Near the top of the ladder both consolations clamp to the same tier, so
	-- they're accumulated by index rather than listed twice.
	local remaining = 1 - sparkleChance
	local shareTotal = 0
	for _, entry in Balance.Craft.Consolation do
		shareTotal += entry.Share
	end
	local chanceByIndex: { [number]: number } = {}
	local order: { number } = {}
	for _, entry in Balance.Craft.Consolation do
		local index = math.min(highest + entry.Tiers, Config.MaxTier)
		if not chanceByIndex[index] then
			chanceByIndex[index] = 0
			table.insert(order, index)
		end
		chanceByIndex[index] += remaining * entry.Share / shareTotal
	end
	for _, index in order do
		table.insert(outcomes, { Index = index, Chance = chanceByIndex[index], Sparkle = false })
	end
	return outcomes
end

-- Picks one outcome by its chance and returns the unit index, or 0 for a load
-- with nothing in it.
function Economy.rollCraft(inputs: { number }): number
	local outcomes = Economy.craftOutcomes(inputs)
	if #outcomes == 0 then
		return 0
	end
	local roll = math.random()
	for _, outcome in outcomes do
		roll -= outcome.Chance
		if roll <= 0 then
			return outcome.Index
		end
	end
	-- Only reachable through floating-point drift on the last outcome.
	return outcomes[#outcomes].Index
end

function Economy.craftRunning(data: Types.PlayerData): boolean
	return data.Craft.EndsAt > 0
end

function Economy.craftRemaining(data: Types.PlayerData, now: number?): number
	if not Economy.craftRunning(data) then
		return 0
	end
	return math.max(data.Craft.EndsAt - (now or os.time()), 0)
end

function Economy.craftReady(data: Types.PlayerData, now: number?): boolean
	return Economy.craftRunning(data) and Economy.craftRemaining(data, now) <= 0
end

-- Gems to finish a craft now, by the hours still to wait. Always at least one,
-- so the button never reads as free.
function Economy.craftSkipCost(data: Types.PlayerData, now: number?): number
	local hours = math.ceil(Economy.craftRemaining(data, now) / 3600)
	return math.max(hours * Balance.Craft.SkipGemsPerHour, 1)
end

return Economy
