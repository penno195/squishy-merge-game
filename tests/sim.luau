-- How long the game actually takes. Not a test -- nothing here passes or fails;
-- it plays a run through against the real Balance and Economy and prints when
-- each tier arrived, which is the only honest way to answer "is this too fast"
-- without sitting through it.
--
-- The simulated player is the greedy one: merges the moment a pair exists, and
-- buys any upgrade the moment it is affordable. Walking over to an item costs
-- nothing here and neither does anything else the real game asks of you, so every
-- number is a best case. The real game is slower by however long the running
-- about takes, which is exactly why the shape matters more than the minutes.
--
-- What it does not model: rebirths (so the long tail reads worse than it plays),
-- the crafting machine, quests, the wheel, daily and playtime rewards, and gems
-- of any kind. Everything it leaves out makes the player richer, so treat it as a
-- floor on the pace rather than a prediction.
--
-- Items are kept as counts per unit index rather than a list, because a list plus
-- a merge pass that restarts from the top is quadratic per simulated second, and
-- a slow run here is two days long.
--
-- Run it with:  python3 tests/build.py <outdir> sim.luau && <outdir>/luau <outdir>/sim-run.luau

local Balance = Config.Balance

-- Two days of play. Anything still unreached by then prints ">48h", which for the
-- top of the ladder is the honest answer rather than a number.
local MAX_SECONDS = 48 * 3600
local MILESTONES = { 5, 10, 15, 20, 25, 30 }

local function newData()
	return {
		Cash = Balance.StartingCash,
		Gems = 0,
		BoostEndsAt = 0,
		LuckEndsAt = 0,
		AutoMergeEndsAt = 0,
		Items = {},
		Carried = 0,
		Upgrades = {},
		UnitsBought = 0,
		Rebirths = 0,
		TotalEarned = 0,
		HighestTier = 1,
		Sparkles = {},
		Discovered = {},
	}
end

local upgradeById = {}
for _, upgrade in Balance.Upgrades do
	upgradeById[upgrade.Id] = upgrade
end

local function human(seconds)
	if seconds >= 3600 then
		return `{string.format("%.1f", seconds / 3600)}h`
	end
	return `{math.max(1, math.floor(seconds / 60))}m`
end

local function run(label, passes)
	local data = newData()
	local cashMultiplier = if passes.DoubleCash then Balance.Monetisation.DoubleCashMultiplier else 1
	local spawnMultiplier = if passes.FastSpawn then Balance.Monetisation.FastSpawnMultiplier else 1
	local bias = Economy.luckPassBias(passes.LuckCharm)
	local spaces = Economy.gardenPassSpaces(passes.BiggerGarden)

	-- counts[index] = how many of that unit are lying in the garden, and `income`
	-- is their base rate kept up to date as they come and go, so neither has to be
	-- totalled every second.
	local counts = {}
	local total = 0
	local income = 0
	local function add(index, n)
		counts[index] = (counts[index] or 0) + n
		total += n
		income += Economy.tierIncome(index) * n
	end
	add(1, 2)

	local nextDrop = Economy.dropInterval(data, spawnMultiplier)
	local reached = {}
	local nextMilestone = 1
	local firstBuy = nil
	local finished = nil

	for second = 1, MAX_SECONDS do
		local perSecond = income * Economy.cashMultiplier(data, cashMultiplier, 1)
		data.Cash += perSecond
		data.TotalEarned += perSecond

		if second >= nextDrop then
			if total < Economy.gardenCapacity(data, spaces) then
				local index = Economy.randomDropIndex(data, bias)
				add(index, 1)
				data.HighestTier = math.max(data.HighestTier, Economy.ladderTier(index))
			end
			nextDrop = second + Economy.dropInterval(data, spawnMultiplier)
		end

		-- Upward from the bottom, so a pair a merge just made merges again.
		for index = 1, #Config.Units do
			local have = counts[index]
			while have and have >= 2 and Economy.canMerge(index) do
				local made = have // 2
				local result = Economy.mergeResult(index)
				add(index, -2 * made)
				add(result, made)
				data.HighestTier = math.max(data.HighestTier, Economy.ladderTier(result))
				have = counts[index]
			end
		end

		-- Cheapest affordable thing, for as long as anything is affordable. This is
		-- the player who sits in the upgrades panel holding the button, which is
		-- the fastest the game can be played and so the one worth measuring.
		local bought = true
		while bought do
			bought = false
			local bestId, bestCost = nil, math.huge
			for id in upgradeById do
				local level = Economy.upgradeLevel(data, id)
				if level < Economy.upgradeMaxLevel(id) then
					local cost = Economy.upgradeCost(id, level)
					if cost <= data.Cash and cost < bestCost then
						bestId, bestCost = id, cost
					end
				end
			end
			if bestId then
				data.Cash -= bestCost
				data.Upgrades[bestId] = Economy.upgradeLevel(data, bestId) + 1
				firstBuy = firstBuy or second
				bought = true
			end
		end

		while nextMilestone <= #MILESTONES and data.HighestTier >= MILESTONES[nextMilestone] do
			reached[MILESTONES[nextMilestone]] = second
			nextMilestone += 1
		end
		if nextMilestone > #MILESTONES then
			finished = second
			break
		end
	end

	local parts = {}
	for _, tier in MILESTONES do
		table.insert(parts, `t{tier}=` .. (if reached[tier] then human(reached[tier]) else ">48h"))
	end
	local levels = {}
	for _, upgrade in Balance.Upgrades do
		local id = upgrade.Id
		table.insert(levels, `{id}:{Economy.upgradeLevel(data, id)}/{Economy.upgradeMaxLevel(id)}`)
	end
	print(`{label}  1st buy=` .. (if firstBuy then human(firstBuy) else "never") .. "  " .. table.concat(parts, " "))
	print(`          ended: ` .. table.concat(levels, " ") .. (if finished then "" else "  (ran out of time)"))
end

-- The four passes that change the pace. The other four don't touch it: Auto Merge
-- saves running rather than time, Auto Collect pays for being away, the second
-- craft slot is its own loop, and the starter pack is a one-off.
local PACE_PASSES = { DoubleCash = true, FastSpawn = true, LuckCharm = true, BiggerGarden = true }

-- A scenario is a mutation of Balance, which is a plain table read at call time.
-- Adding one is how to ask "what would this number do" without editing the real
-- file and forgetting to put it back.
local function apply(tweaks)
	if tweaks.TierGrowth then
		Balance.Income.TierGrowth = tweaks.TierGrowth
	end
	for id, fields in tweaks.Upgrades or {} do
		for field, value in fields do
			upgradeById[id][field] = value
		end
	end
end

local SHIPPED = { TierGrowth = Balance.Income.TierGrowth, Upgrades = {} }
for id, upgrade in upgradeById do
	SHIPPED.Upgrades[id] = { BaseCost = upgrade.BaseCost, Growth = upgrade.Growth, PerLevel = upgrade.PerLevel }
end

local function scenario(label, tweaks)
	apply(SHIPPED)
	apply(tweaks)
	print(`--- {label}`)
	run("   bought nothing ", {})
	run("   pace passes    ", PACE_PASSES)
	print("")
end

print(`ladder is {Config.MaxTier} tiers; capacity tops out at {Balance.GardenCapacities[#Balance.GardenCapacities]}`)
print(`rebirth wants tier {Balance.Rebirth.BaseTier}, then one more each time`)
print("")
scenario("as shipped", {})

-- Comparisons go here. For example, what the pacing gate was before it was
-- measured -- half an hour for the whole ladder:
--
-- scenario("the old numbers", {
-- 	Upgrades = {
-- 		SpawnTier = { BaseCost = 1000, Growth = 2.8, MaxLevel = 24 },
-- 		SpawnSpeed = { BaseCost = 100, Growth = 1.6 },
-- 		GardenSpace = { BaseCost = 250, Growth = 8 },
-- 		Income = { BaseCost = 200, Growth = 1.45, PerLevel = 0.25 },
-- 	},
-- })
